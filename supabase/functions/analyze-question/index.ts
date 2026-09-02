// AI Gateway — soru fotoğrafını değerlendirir ve çoktan seçmeli şıkları çıkarır.
// Geçerli sayılması için fotoğrafta: (1) net OKUNABİLİR olmalı, (2) bir SORU/
// problem ifadesi olmalı, (3) ŞIKLAR olmalı. Değilse ilgili bayrak false olur
// ve reason'a kısa Türkçe sebep yazılır.
//
// Ayrıca soruyu YKS taksonomisine göre sınıflandırır: sinav (TYT/AYT), ders,
// konu. Müfredat (eski/maarif) istekten gelir; konu, verilen listeden seçilir.
//
// ---------------------------------------------------------------- CAN (Task 02)
// Bu fonksiyonun kişi başı sınırı YOKTU ve OpenAI maliyeti doğrudan bize
// yazılıyordu (Task 01 raporu, açık bulgu #7). Artık her çağrı OpenAI'ya
// GİTMEDEN ÖNCE `consume_ai_use()` RPC'sinden geçiyor: günde 5 hak, Europe/
// Istanbul gün dönümünde tazeleniyor.
//
// Hak bitince HATA DÖNMÜYOR — 200 ile `{ allowed: false, resets_at }` dönüyor.
// Hak bitmesi bir hata değil, beklenen bir ürün durumu: istemci o noktada elle
// giriş formunu açıyor ve KAYDETME YOLU ASLA KAPANMIYOR.
//
// Sayaç çağıranın KENDİ JWT'siyle tüketiliyor (servis rolüyle değil): RPC
// `auth.uid()` okuyor ve hiçbir yerde `user_id` parametresi geçmiyor — Task
// 01'in "hiçbir RPC user_id almaz" değişmezi burada da geçerli.
//
// OpenAI anahtarı SADECE burada (Supabase secret: OPENAI_API_KEY).
// Deploy: supabase functions deploy analyze-question

import { type Curriculum, isValidPair, taxonomyText } from "./taxonomy.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Kabul edilen görsel türleri. Eskiden `mimeType` doğrudan data URL'ine
 * yazılıyordu; istemcinin gönderdiği herhangi bir metin oraya giriyordu.
 */
const ALLOWED_MIME = new Set(["image/jpeg", "image/png", "image/webp"]);

/** Kabaca 8 MB'lık base64 üst sınırı (~6 MB görsel). */
const MAX_BASE64 = 11_000_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Tek tip, ayrıntısız hata — `send-push`'taki desenin aynısı. Dışarıya iç
 * durum sızdırmaz; teşhis sunucu günlüğüne yazılır.
 *
 * Eskiden OpenAI'nın hata gövdesi olduğu gibi istemciye yansıtılıyordu
 * (`{error:"openai_error", detail}`); o gövde model adı, kota durumu ve bazen
 * istek kimliği taşıyor.
 */
function deny(status: number, logDetail: string): Response {
  console.error(`[analyze-question] ${status}: ${logDetail}`);
  return json({ error: "gecersiz_istek" }, status);
}

/**
 * Bir yapay zekâ okutma hakkı harcar.
 *
 * Çağıranın Authorization başlığı olduğu gibi iletiliyor; böylece RPC o
 * kullanıcı olarak çalışıyor. Supabase istemci kütüphanesi yerine düz REST
 * kullanılıyor: tek bir RPC için bağımlılık ve istemci kurulumu gereksiz.
 */
async function consumeCredit(
  authHeader: string,
): Promise<{ allowed: boolean; remaining: number; resetsAt: string | null }> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    throw new Error("SUPABASE_URL / SUPABASE_ANON_KEY tanımlı değil");
  }

  const resp = await fetch(`${url}/rest/v1/rpc/consume_ai_use`, {
    method: "POST",
    headers: {
      "Authorization": authHeader,
      "apikey": anon,
      "Content-Type": "application/json",
    },
    body: "{}",
  });

  if (!resp.ok) {
    throw new Error(`consume_ai_use ${resp.status}: ${await resp.text()}`);
  }

  const rows = await resp.json();
  const row = Array.isArray(rows) ? rows[0] : rows;
  return {
    allowed: row?.allowed === true,
    remaining: Number(row?.remaining ?? 0),
    resetsAt: row?.resets_at ?? null,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return deny(500, "OPENAI_API_KEY tanımlı değil");

    // Ağ geçidi JWT'yi zaten doğruladı (verify_jwt = true); başlık burada
    // yalnızca kullanıcıyı RPC'ye taşımak için okunuyor.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return deny(401, "Authorization başlığı yok");

    const body = await req.json().catch(() => ({}));
    const imageBase64 = body.imageBase64;
    const mimeType = typeof body.mimeType === "string"
      ? body.mimeType
      : "image/jpeg";
    const curriculum: Curriculum = body.curriculum === "maarif"
      ? "maarif"
      : "eski";

    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      return deny(400, "imageBase64 gerekli");
    }
    if (imageBase64.length > MAX_BASE64) {
      return deny(400, `görsel çok büyük: ${imageBase64.length}`);
    }
    if (!ALLOWED_MIME.has(mimeType)) {
      return deny(400, `desteklenmeyen mimeType: ${mimeType}`);
    }

    // ------------------------------------------------------------------ CAN
    // OpenAI'ya GİTMEDEN ÖNCE. Sıra tersine çevrilirse hak bitmiş kullanıcı
    // yine de maliyet üretirdi.
    let credit: { allowed: boolean; remaining: number; resetsAt: string | null };
    try {
      credit = await consumeCredit(authHeader);
    } catch (e) {
      return deny(500, `hak tüketilemedi: ${e}`);
    }

    if (!credit.allowed) {
      // 200 ve açık bir gövde: bu bir hata değil, ürün durumu. İstemci elle
      // giriş formunu açıyor.
      return json({
        allowed: false,
        remaining: 0,
        resets_at: credit.resetsAt,
      }, 200);
    }

    const dataUrl = `data:${mimeType};base64,${imageBase64}`;

    const payload = {
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content:
            "Sen bir YKS sorusu doğrulama, şık çıkarma ve konu sınıflandırma " +
            "aracısın. Verilen fotoğrafı değerlendir. GEÇERLİ bir çoktan " +
            "seçmeli soru fotoğrafı için üç şart: (1) metin net OKUNABİLİR, " +
            "(2) bir SORU/problem ifadesi var, (3) ŞIKLAR var. is_readable, " +
            "has_question, has_options bayraklarını buna göre doldur. Şıkları " +
            "aynen çıkar (doğru cevabı SEN belirleme). Geçerliyse soruyu " +
            "sınıflandır: 'sinav' TYT veya AYT; 'ders' ve 'konu' ise AŞAĞIDAKİ " +
            "LİSTEDEN seçilmeli. 'konu' listedeki bir konu adıyla BİREBİR aynı " +
            "yazılmalı (kendi adını uydurma). MÜMKÜN OLAN EN SPESİFİK (EN DAR) " +
            "konuyu seç; genel/şemsiye başlık yerine tam eşleşen alt konuyu " +
            "tercih et (ör. genel 'İnsan Fizyolojisi' yerine 'Destek ve Hareket " +
            "Sistemi'). Emin değilsen en yakın konuyu seç. Geçersizse ders/" +
            "konu/sinav boş kalsın ve 'reason' alanına " +
            "kısa Türkçe sebep yaz (ör. 'Sadece şıklar var, soru görünmüyor').\n\n" +
            "KONU LİSTESİ (" + curriculum + " müfredat):\n" +
            taxonomyText(curriculum),
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Bu fotoğrafı değerlendir; şıkları (harf + metin) çıkar ve " +
                "soruyu sinav/ders/konu olarak sınıflandır.",
            },
            { type: "image_url", image_url: { url: dataUrl } },
          ],
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "question_analysis",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              is_readable: { type: "boolean" },
              has_question: { type: "boolean" },
              has_options: { type: "boolean" },
              reason: { type: "string" },
              sinav: { type: "string", enum: ["TYT", "AYT", ""] },
              ders: { type: "string" },
              konu: { type: "string" },
              options: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    label: { type: "string" },
                    text: { type: "string" },
                  },
                  required: ["label", "text"],
                },
              },
            },
            required: [
              "is_readable",
              "has_question",
              "has_options",
              "reason",
              "sinav",
              "ders",
              "konu",
              "options",
            ],
          },
        },
      },
    };

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!resp.ok) {
      // Gövde İSTEMCİYE YANSITILMIYOR: model adı, kota durumu ve istek kimliği
      // taşıyabiliyor. Ayrıntı yalnızca sunucu günlüğüne.
      return deny(502, `openai ${resp.status}: ${await resp.text()}`);
    }

    const data = await resp.json();
    const content = data.choices?.[0]?.message?.content ?? "{}";
    const parsed = JSON.parse(content);

    // Ders/konu'yu taksonomiye göre doğrula (AI listeden sapmışsa işaretle).
    parsed.konu_valid = Boolean(
      parsed.ders &&
        parsed.konu &&
        isValidPair(curriculum, parsed.sinav ?? "", parsed.ders, parsed.konu),
    );
    parsed.curriculum = curriculum;
    // Hak harcandı; istemci kalan sayıyı HUD'da gösteriyor.
    parsed.allowed = true;
    parsed.remaining = credit.remaining;
    parsed.resets_at = credit.resetsAt;
    return json(parsed, 200);
  } catch (e) {
    return deny(500, String(e));
  }
});
