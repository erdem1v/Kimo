// AI Gateway — soru fotoğrafını değerlendirir ve çoktan seçmeli şıkları çıkarır.
// Geçerli sayılması için fotoğrafta: (1) net OKUNABİLİR olmalı, (2) bir SORU/
// problem ifadesi olmalı, (3) ŞIKLAR olmalı. Değilse ilgili bayrak false olur
// ve reason'a kısa Türkçe sebep yazılır.
//
// Ayrıca soruyu YKS taksonomisine göre sınıflandırır: sinav (TYT/AYT), ders,
// konu. Müfredat (eski/maarif) istekten gelir; konu, verilen listeden seçilir.
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

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return json({ error: "OPENAI_API_KEY tanımlı değil" }, 500);

    const body = await req.json().catch(() => ({}));
    const imageBase64 = body.imageBase64;
    const mimeType = body.mimeType;
    const curriculum: Curriculum = body.curriculum === "maarif"
      ? "maarif"
      : "eski";
    if (!imageBase64) return json({ error: "imageBase64 gerekli" }, 400);

    const dataUrl = `data:${mimeType ?? "image/jpeg"};base64,${imageBase64}`;

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
      const detail = await resp.text();
      return json({ error: "openai_error", detail }, 502);
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
    return json(parsed, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
