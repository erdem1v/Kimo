// AI Gateway — soru fotoğrafını değerlendirir ve çoktan seçmeli şıkları çıkarır.
// Geçerli sayılması için fotoğrafta: (1) net OKUNABİLİR olmalı, (2) bir SORU/
// problem ifadesi olmalı, (3) ŞIKLAR olmalı. Değilse ilgili bayrak false olur
// ve reason'a kısa Türkçe sebep yazılır.
//
// Ayrıca soruyu YKS taksonomisine göre sınıflandırır: sinav (TYT/AYT), ders,
// konu. Müfredat (eski/maarif) istekten gelir; konu, verilen listeden seçilir.
//
// ------------------------------------------------- ANALİZ HAKKI (Task 02 → 10)
// Bu fonksiyonun kişi başı sınırı YOKTU ve OpenAI maliyeti doğrudan bize
// yazılıyordu (Task 01 raporu, açık bulgu #7). Her çağrı OpenAI'ya GİTMEDEN
// ÖNCE `consume_ai_use()` RPC'sinden geçiyor.
//
// TASK 10'DA REJİM DEĞİŞTİ: günde sabit 5 yerine katmanlı KAYAN pencere +
// aylık cap (anonim 3 ömür boyu · ücretsiz 10/8sa + 300/ay · premium 50/8sa +
// 1.000/ay, sayılar `app_config`'te). Yanıt artık `resets_at` değil `ai_state`
// (`ok|low|window_full|month_full|lifetime_full|suspended`), `ai_next_at_hm`
// ve `ai_month_resets_on` taşıyor — istemci "neden bitti"yi ve ne
// göstereceğini hesaplamak zorunda kalmıyor.
//
// Hak bitince HATA DÖNMÜYOR — 200 ile `{ allowed: false, ai_state, … }`
// dönüyor. Hak bitmesi bir hata değil, beklenen bir ürün durumu: istemci o
// noktada hak duvarını açıyor ve KAYDETME YOLU ASLA KAPANMIYOR.
//
// Sayaç çağıranın KENDİ JWT'siyle tüketiliyor (servis rolüyle değil): RPC
// `auth.uid()` okuyor ve hiçbir yerde `user_id` parametresi geçmiyor — Task
// 01'in "hiçbir RPC user_id almaz" değişmezi burada da geçerli.
//
// OpenAI anahtarı SADECE burada (Supabase secret: OPENAI_API_KEY).
// Deploy: supabase functions deploy analyze-question

import {
  type Curriculum,
  isValidPair,
  loadTaxonomy,
  type Taxonomy,
  taxonomyText,
} from "./taxonomy.ts";

// CORS BİLİNÇLİ OLARAK YOK (Task 03). Bu fonksiyonu yalnızca mobil istemci
// çağırıyor; native HTTP Origin göndermez ve preflight yapmaz. Eski `*`
// başlığı ölü yapılandırmaydı ve ileride gevşetilmeye davetiye çıkarıyordu.
// Bir web yönetim paneli gelirse CORS o panelin origin'ine SABİTLENEREK geri
// eklenmeli — asla `*` ile değil.

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
    headers: { "Content-Type": "application/json" },
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
 * Bir RPC'yi ÇAĞIRANIN kimliğiyle koşturur.
 *
 * Authorization başlığı olduğu gibi iletiliyor; böylece RPC o kullanıcı olarak
 * çalışıyor ve `auth.uid()` doğru kişiyi gösteriyor. Supabase istemci
 * kütüphanesi yerine düz REST: birkaç RPC için bağımlılık ve istemci kurulumu
 * gereksiz.
 */
async function rpc(
  authHeader: string,
  name: string,
  body: Record<string, unknown>,
): Promise<unknown> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    throw new Error("SUPABASE_URL / SUPABASE_ANON_KEY tanımlı değil");
  }

  const resp = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      "Authorization": authHeader,
      "apikey": anon,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    throw new Error(`${name} ${resp.status}: ${await resp.text()}`);
  }
  return await resp.json();
}

/** Kota durumu — görünümle AYNI sözlük (`public.ai_state()`). */
interface Credit {
  allowed: boolean;
  /** BAĞLAYICI kalan: pencere ile ay kalanının küçüğü. Sunucu hesaplıyor. */
  remaining: number;
  state: string | null;
  tier: string | null;
  windowLeft: number;
  windowLimit: number;
  monthLeft: number;
  monthLimit: number;
  /** Sonraki hakkın Istanbul duvar saati, `HH:MM`. Ay doluysa null. */
  nextAtHm: string | null;
  /** Ayın yenilendiği Istanbul takvim günü, `YYYY-MM-DD`. */
  monthResetsOn: string | null;
  adRewardsLeft: number;
  adOffer: boolean;
  /**
   * Çağrı defteri satırının kimliği — iade için (0083).
   *
   * `null` yalnızca hak verilmediğinde: o durumda zaten satır yazılmadı,
   * yani iade edilecek bir şey de yok.
   */
  callId: number | null;
}

/**
 * Bir analiz hakkı harcar.
 *
 * `p_sha_hex` çağrı defterine yinelenen-fotoğraf sinyalini taşıyor. Hash ZATEN
 * önbellek için hesaplanmış durumda, yani bedava; maliyet kalibrasyonunda
 * "aynı fotoğraf kaç kez ücretlendi" sorusunu yanıtlıyor.
 */
async function consumeCredit(
  authHeader: string,
  shaHex: string,
): Promise<Credit> {
  const rows = await rpc(authHeader, "consume_ai_use", { p_sha_hex: shaHex });
  const row = (Array.isArray(rows) ? rows[0] : rows) as Record<string, unknown>;
  return {
    allowed: row?.allowed === true,
    remaining: Number(row?.remaining ?? 0),
    state: (row?.ai_state as string | null) ?? null,
    tier: (row?.ai_tier as string | null) ?? null,
    windowLeft: Number(row?.ai_window_left ?? 0),
    windowLimit: Number(row?.ai_window_limit ?? 0),
    monthLeft: Number(row?.ai_month_left ?? 0),
    monthLimit: Number(row?.ai_month_limit ?? 0),
    nextAtHm: (row?.ai_next_at_hm as string | null) ?? null,
    monthResetsOn: (row?.ai_month_resets_on as string | null) ?? null,
    adRewardsLeft: Number(row?.ad_rewards_left ?? 0),
    adOffer: row?.ad_offer === true,
    callId: row?.call_id == null ? null : Number(row.call_id),
  };
}

/**
 * Harcanan hakkı geri verir (0083).
 *
 * ÜRÜN KURALI (Tur 7 · n4): "Hak sayımı YALNIZCA OKUNABİLEN fotoğraflar için
 * düşer." `consume_ai_use` OpenAI'ya gitmeden ÖNCE koştuğu için okunamayan
 * fotoğrafın hakkı ancak İADEYLE geri gelebiliyor.
 *
 * `capped = false` ALTYAPI hataları için: 5xx ya da ayrıştırma hatası
 * kullanıcının hatası değil, bu yüzden günlük iade sınırına yazılmıyor.
 *
 * İKİ AYRI RPC, BİLEREK. Tavansız iade `authenticated`'a AÇILAMAZ: ilk
 * yazımda `refund_ai_use(p_call_id, p_capped)` istemciye açıktı ve `p_capped`
 * tamamen istemcinin elindeydi — PostgREST'e `{"p_capped": false}` gönderen
 * bir istemci günlük tavanı atlayıp kendi bütün çağrılarını iade edebiliyor,
 * yani aylık cap'i (sert maliyet tavanı) geçersiz kılıyordu.
 *   * tavanlı  → `refund_ai_use(bigint)`, KULLANICININ JWT'siyle.
 *   * tavansız → `refund_ai_use_infra(text, bigint)`, `anon` + paylaşılan sır.
 * "Bu bizim hatamızdı" diyebilecek tek taraf sunucu; sır onu kanıtlıyor.
 *
 * DÖNÜŞ DEĞERİ YUTULMUYOR: RPC `false` dönebilir (tavan dolu, satır zaten
 * iade edilmiş, sır yok) ve o durumda kullanıcıya "iade edildi" demek yalan
 * olurdu. `false` dönüyoruz, çağıran `refunded` bayrağını ona göre kuruyor.
 *
 * SESSİZ BAŞARISIZLIK BİLİNÇLİ: iade edilemezse kullanıcı hakkını kaybediyor
 * ama analizi de almış olmuyor — yanıtı bir iade hatası yüzünden 500'e
 * çevirmek daha kötü olurdu. Günlüğe yazılıyor.
 */
async function refundCredit(
  authHeader: string,
  callId: number | null,
  capped: boolean,
): Promise<boolean> {
  if (callId == null) return false;
  try {
    let out: unknown;
    if (capped) {
      out = await rpc(authHeader, "refund_ai_use", { p_call_id: callId });
    } else {
      const secret = Deno.env.get("AI_REFUND_SECRET");
      if (!secret) {
        // Sır girilmemişse tavansız yol YOK. Tavanlıya düşmek, altyapı
        // hatasını kullanıcının bütçesine yazmak olurdu; iade etmemek daha
        // dürüst ve günlüğe yazılıyor.
        console.error("[analyze-question] AI_REFUND_SECRET yok — altyapı iadesi atlandı");
        return false;
      }
      const anon = Deno.env.get("SUPABASE_ANON_KEY");
      if (!anon) throw new Error("SUPABASE_ANON_KEY tanımlı değil");
      out = await rpc(`Bearer ${anon}`, "refund_ai_use_infra", {
        p_secret: secret,
        p_call_id: callId,
      });
    }
    return out === true;
  } catch (e) {
    console.error(`[analyze-question] hak iade edilemedi (${callId}): ${e}`);
    return false;
  }
}

/** Kota alanlarını yanıt gövdesine yazar — iki dal aynı sözlüğü kullanıyor. */
function creditFields(c: Credit): Record<string, unknown> {
  return {
    ai_state: c.state,
    ai_tier: c.tier,
    ai_window_left: c.windowLeft,
    ai_window_limit: c.windowLimit,
    ai_month_left: c.monthLeft,
    ai_month_limit: c.monthLimit,
    ai_next_at_hm: c.nextAtHm,
    ai_month_resets_on: c.monthResetsOn,
    ad_rewards_left: c.adRewardsLeft,
    ad_offer: c.adOffer,
  };
}

/**
 * Fotoğrafın SHA-256 özeti (hex).
 *
 * Base64 METNİ üzerinden hesaplanıyor, çözülmüş baytlar üzerinden değil:
 * aynı fotoğraf aynı metni üretiyor ve 8 MB'lık bir base64'ü çözmek boşuna
 * bellek. Farklı kodlanmış aynı görsel önbelleği ıskalar — ıskalamak zararsız,
 * normal yola düşer.
 *
 * SUNUCUDA hesaplanıyor: istemcinin bildirdiği bir hash'e güvenmek, başkasının
 * sonucunu çekmeye çalışmak için yüzey açardı (kayıtlar kullanıcıya kilitli
 * olsa bile tasarımı zayıflatırdı).
 */
async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  // DIŞ KAPSAMDA, bilinçli: beklenmedik bir hatada hakkı iade edebilmek için
  // `catch` bloğunun bunlara erişmesi gerekiyor. `try` içinde tanımlanırsa
  // kapsam dışında kalır ve iade yolu sessizce ölür.
  let refundAuth: string | null = null;
  let refundCallId: number | null = null;
  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return deny(500, "OPENAI_API_KEY tanımlı değil");

    // Ağ geçidi JWT'yi zaten doğruladı (verify_jwt = true); başlık burada
    // yalnızca kullanıcıyı RPC'ye taşımak için okunuyor.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return deny(401, "Authorization başlığı yok");
    refundAuth = authHeader;

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

    // ----------------------------------------------------------- YAŞ KAPISI
    // ÖNBELLEKTEN DE, KOTADAN DA, OpenAI'dan da ÖNCE (A-2).
    //
    // Onboarding sırası `firstCapture → age → …`: öğrencinin ilk fotoğrafı
    // yaşı bilinmeden çekiliyor. 0063'ten beri 13 yaş sınırını zorluyoruz ve
    // hukuki metinler "13 altını kabul etmiyoruz" diyor — reddedeceğimiz bir
    // kullanıcının verisini reddetmeden önce yurt dışına aktarmak bu beyanla
    // çelişirdi.
    //
    // İstemci de analizi erteliyor (fotoğraf yaş adımına kadar YEREL kuyrukta
    // bekliyor) ama bu kapı ondan bağımsız: uç noktaya doğrudan istek atan
    // biri arayüzü hiç görmez.
    //
    // KAPI KAPALIYSA HATA DEĞİL, ÜRÜN DURUMU: 403 + açık bir sebep. İstemci
    // kuyruk kaydını düşürmüyor, yaş adımını bekliyor.
    try {
      const ageOk = await rpc(authHeader, "ai_age_ok", {});
      if (ageOk !== true) {
        return json({ allowed: false, reason: "age_required" }, 403);
      }
    } catch (e) {
      // Kapı SORULAMADIYSA analiz YAPILMAZ. Açık taraf (fail-open) burada
      // yanlış olurdu: ağ hatası, kapının hiç olmadığı duruma eşitlenirdi.
      return deny(503, `yaş kapısı sorulamadı: ${e}`);
    }

    // ------------------------------------------------------------ KONU AĞACI
    // Önbellekten de önce: önbellek anahtarı taksonomi SÜRÜMÜNÜ içeriyor
    // (0071). Ağaç değiştiğinde eski yanıtlar artık var olmayan bir konu adı
    // döndürüp yeni doğrulamaya takılırdı — kullanıcı hiçbir şey yapmadan.
    //
    // Ağaç okunamazsa analiz YAPILMIYOR. Açık taraf (fail-open) burada yanlış
    // olurdu: sınıflandırma doğrulamasız kalır ve arşive uydurma konu girer.
    let taxonomy: Taxonomy;
    try {
      taxonomy = await loadTaxonomy(
        (name, body) => rpc(authHeader, name, body),
        curriculum,
      );
    } catch (e) {
      return deny(503, `konu ağacı okunamadı: ${e}`);
    }

    // ------------------------------------------------------------ ÖNBELLEK
    // KOTADAN DA ÖNCE. Aynı fotoğraf ikinci kez gönderildiğinde amaç ücretin
    // ÇIKMAMASI; sonradan iade etmek değil. En sık tetikleyici ürünün kendi
    // akışı: "Vazgeç" isteği iptal etmiyor, hak harcanıyor, kullanıcı aynı
    // fotoğrafla devam ediyor.
    //
    // Önbellek HATASI analizi durdurmuyor: isabet edemezsek normal yola
    // düşüyoruz. Sessiz de değil — teşhis sunucu günlüğünde.
    const shaHex = await sha256Hex(imageBase64);
    try {
      const hit = await rpc(authHeader, "ai_cache_get", {
        p_sha_hex: shaHex,
        p_curriculum: curriculum,
        p_taxonomy_version: taxonomy.version,
      });
      if (hit && typeof hit === "object") {
        return json({
          ...(hit as Record<string, unknown>),
          allowed: true,
          taxonomy_version: taxonomy.version,
          // Kota alanları BİLEREK yok: bu çağrıda hiçbir hak harcanmadı ve
          // istemci eldeki sayıyı koruyor. `cached: true` görünce HUD'ı
          // yenilemiyor — yenilerse de aynı sayıyı okur.
          cached: true,
        }, 200);
      }
    } catch (e) {
      console.error(`[analyze-question] önbellek okunamadı: ${e}`);
    }

    // ---------------------------------------------------------- ANALİZ HAKKI
    // OpenAI'ya GİTMEDEN ÖNCE. Sıra tersine çevrilirse hak bitmiş kullanıcı
    // yine de maliyet üretirdi.
    //
    // ÖNBELLEK İSABETİ BURAYA HİÇ GELMİYOR (yukarıda dönüyor): isabette hak
    // harcanmıyor VE çağrı defterine satır yazılmıyor, yani aylık cap de
    // tüketilmiyor. Doğru olan bu — ve aylık cap üzerindeki en iyi kaldıraç
    // da önbellek isabet oranı.
    let credit: Credit;
    try {
      credit = await consumeCredit(authHeader, shaHex);
    } catch (e) {
      return deny(500, `hak tüketilemedi: ${e}`);
    }
    refundCallId = credit.callId;

    if (!credit.allowed) {
      // 200 ve açık bir gövde: bu bir hata değil, ürün durumu. İstemci hak
      // duvarını açıyor ve kaydetme yolu orada birincil eylem.
      //
      // `ai_state` ve saat/tarih alanları duvarın METNİNİ besliyor: hangi
      // başlığın çıkacağına ve reklam satırının çizilip çizilmeyeceğine
      // sunucu karar veriyor, istemci değil.
      return json({
        allowed: false,
        remaining: 0,
        ...creditFields(credit),
      }, 200);
    }

    const dataUrl = `data:${mimeType};base64,${imageBase64}`;

    const payload = {
      // Task 11 olcumu sonrasi gpt-4o-mini'den gecildi. Iki sebep:
      //
      //   MALIYET. Ayni fotograf, onbelleksiz, gercekci 4:3 dikey, 1600px:
      //   gpt-4o-mini $0.00452/cagri, bu yapilandirma $0.00146. Yillik planin
      //   neti $1.35; gpt-4o-mini'de basabas cap 236 analiz/ay cikiyordu, oysa
      //   sevk edilen premium cap 1000. Yani eski model cap tablosunu
      //   cozmuyordu. (docs/task-11-kurulum-raporu.md)
      //
      //   UYDURMA. Kasten bulaniklastirilmis, gozle okunamayan bir soru
      //   fotografinda gpt-4o-mini `is_readable: true` dondu, bes sikki da
      //   doldurdu ve sik metinleri kaynakla SIFIR ortusuyordu. Yani
      //   `unreadable` dali pratikte hic tetiklenmiyor, kullanici hata
      //   gormuyor ve arsivine uydurma icerik giriyor; tekrar motoru da onu
      //   o icerikle calistiriyor. Bu model ayni fotografta `unreadable`
      //   donuyor.
      //
      // Istek sekli tools/ab_model_bench.mjs:164-181 ile BIREBIR ayni olmali;
      // olcum o sekille yapildi ve `effortSupported: true` dondu.
      model: "gpt-5.6-luna",
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
            "konu/sinav boş kalsın ve 'reason_code' alanına nedenlerden birini " +
            "yaz: unreadable (metin okunmuyor), no_question (soru ifadesi yok), " +
            "no_options (şıklar yok). Geçerliyse 'ok' yaz. SERBEST METİN YAZMA.\n\n" +
            "KONU LİSTESİ (" + curriculum + " müfredat):\n" +
            taxonomyText(taxonomy),
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
            // `detail` GORSEL NESNESININ ICINE konur, payload kokune DEGIL.
            //
            // Bu model ailesinde `high`, `auto`'dan UCUZ: olcumde detail:high
            // 6.658 istem token'i, detail:auto 7.737 uretti (ayni fotograf).
            // Sezgiye ters ama iki kez olculdu.
            { type: "image_url", image_url: { url: dataUrl, detail: "high" } },
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
              // SERBEST METİN DEĞİL (Task 03): modelin yazdığı hiçbir metin
              // kullanıcıya kontrolsüz gösterilmez. Hazırlanmış bir görsel,
              // eski `reason` alanı üzerinden 15 yaşındaki bir kullanıcıya
              // istediği Türkçe cümleyi gösterebilirdi ("Hesabın askıya
              // alındı, şu adresten doğrula…"). Enum bu yüzeyi kapatıyor;
              // istemci kodu kendi yerelleştirilmiş metnine çevirir.
              reason_code: {
                type: "string",
                enum: ["ok", "unreadable", "no_question", "no_options"],
              },
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
              "reason_code",
              "sinav",
              "ders",
              "konu",
              "options",
            ],
          },
        },
      },

      // DUZ ALAN, ic ice `reasoning: { effort }` DEGIL. Olcumde bu sekil
      // kabul edildi (`effortSupported: true`) ve reasoning token'i 0 dondu —
      // yani cikti, semanin kendisinden ibaret kaliyor. Reasoning token'lari
      // CIKTI fiyatindan faturalandigi icin bu dogrudan maliyet kalemi.
      reasoning_effort: "none",

      // Bugune kadar hic token tavani yoktu. Olculen cikti ~103 token; 800
      // sekiz kat pay birakiyor ve kacak bir cevabin faturasini sinirliyor.
      // Ust sinira carpilirsa `finish_reason` "length" olur ve asagidaki
      // JSON.parse patlar — o yuzden pay genis tutuldu.
      max_completion_tokens: 800,
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
      // ALTYAPI HATASI → HAK İADE EDİLİYOR ve sınıra yazılmıyor: OpenAI'ın
      // 5xx'i kullanıcının hatası değil. İade olmadan 10'luk bir parti
      // "10 hak verip 6 sonuç almak" anlamına gelirdi.
      await refundCredit(authHeader, credit.callId, false);
      // Gövde İSTEMCİYE YANSITILMIYOR: model adı, kota durumu ve istek kimliği
      // taşıyabiliyor. Ayrıntı yalnızca sunucu günlüğüne.
      return deny(502, `openai ${resp.status}: ${await resp.text()}`);
    }

    const data = await resp.json();
    const content = data.choices?.[0]?.message?.content ?? "{}";
    const parsed = JSON.parse(content);

    // Kemer-askı: model bayraklarla çelişen bir kod seçtiyse kodu SUNUCU
    // türetir; istemciye giden değer her zaman bayraklarla tutarlı bir enum.
    // Serbest metin hiçbir koşulda iletilmez (eski `reason` alanı dahil).
    const validCodes = new Set(["ok", "unreadable", "no_question", "no_options"]);
    const flagsOk = parsed.is_readable && parsed.has_question &&
      parsed.has_options;
    if (!validCodes.has(parsed.reason_code) || flagsOk !== (parsed.reason_code === "ok")) {
      parsed.reason_code = !parsed.is_readable
        ? "unreadable"
        : !parsed.has_question
        ? "no_question"
        : !parsed.has_options
        ? "no_options"
        : "ok";
    }
    delete parsed.reason;

    // Ders/konu'yu taksonomiye göre doğrula (AI listeden sapmışsa işaretle).
    parsed.konu_valid = Boolean(
      parsed.ders &&
        parsed.konu &&
        isValidPair(taxonomy, parsed.sinav ?? "", parsed.ders, parsed.konu),
    );
    parsed.curriculum = curriculum;

    // Önbelleğe YALNIZCA modelin ürettiği kısım giriyor; `allowed`/`remaining`
    // o çağrıya özel ve bir sonraki isabette yanlış sayı göstermelerine yol
    // açardı. Okunamayan fotoğraflar da önbelleğe giriyor: aynı bulanık kare
    // ikinci kez de ücretlenmesin.
    try {
      await rpc(authHeader, "ai_cache_put", {
        p_sha_hex: shaHex,
        p_curriculum: curriculum,
        p_result: parsed,
        p_taxonomy_version: taxonomy.version,
      });
    } catch (e) {
      console.error(`[analyze-question] önbelleğe yazılamadı: ${e}`);
    }

    // OKUNAMAYAN FOTOĞRAF → HAK İADE EDİLİYOR (Tur 7 · n4 kuralı).
    //
    // `reason_code` yukarıda SUNUCUDA türetildi, yani modelin çelişkili bir
    // kod seçmesi bu dalı yanıltamıyor. İade `capped = true`: dürüst kullanım
    // (birkaç bulanık kare) hiç cezalanmıyor ama okunamayan fotoğraf
    // göndermek BEDAVA da olmuyor — çağrı yapıldı, para harcandı.
    //
    // ÖNBELLEK YAZIMI YUKARIDA VE KALIYOR: aynı bulanık kare ikinci kez
    // OpenAI'a hiç gitmiyor. İade + önbellek birlikte "aynı hatayı iki kez
    // ödemiyorsun" sözünü tutuyor.
    // `refunded` ARTIK RPC'NİN CEVABI. Koşulsuz `true` yazmak, günlük iade
    // tavanı dolan bir kullanıcıda "hakkın harcanmadı" demek olurdu — sunucu
    // `false` dönerken istemciye yalan.
    let refunded = false;
    if (parsed.reason_code !== "ok") {
      refunded = await refundCredit(authHeader, credit.callId, true);
    }

    // Hak harcandı; istemci kalan sayıyı HUD'da gösteriyor.
    //
    // İADE EDİLDİYSE SAYILAR TAZELENİYOR: `credit` iade ÖNCESİNİN anlık
    // görüntüsü ve onu göndermek kullanıcıya bir eksik hak gösterirdi. Bu
    // yanlış, HUD'un tamamının önermesi "sunucu hesaplıyor, sayı güvenilir".
    if (refunded) {
      try {
        const fresh = await rpc(authHeader, "ai_state", {});
        const row = (Array.isArray(fresh) ? fresh[0] : fresh) as
          | Record<string, unknown>
          | undefined;
        if (row) {
          credit = {
            ...credit,
            remaining: Number(row.ai_left ?? credit.remaining),
            state: (row.ai_state as string | null) ?? credit.state,
            windowLeft: Number(row.ai_window_left ?? credit.windowLeft),
            monthLeft: Number(row.ai_month_left ?? credit.monthLeft),
            nextAtHm: (row.ai_next_at_hm as string | null) ?? null,
            adRewardsLeft: Number(row.ad_rewards_left ?? credit.adRewardsLeft),
            adOffer: row.ad_offer === true,
          };
        }
      } catch (e) {
        console.error(`[analyze-question] iade sonrası durum okunamadı: ${e}`);
      }
    }
    parsed.allowed = true;
    parsed.remaining = credit.remaining;
    parsed.refunded = refunded;
    Object.assign(parsed, creditFields(credit));
    // Taksonomi sürümü HER yanıtta: istemci elindeki ağacın bayatladığını
    // böyle anlıyor ve onay ekranı açılmadan ÖNCE tazeliyor. Olmasaydı
    // kullanıcı listede olmayan bir konu seçip sebebini anlamadığı bir hata
    // alırdı — bu paketin kapatmak için var olduğu senaryo.
    parsed.taxonomy_version = taxonomy.version;
    return json(parsed, 200);
  } catch (e) {
    // AYRIŞTIRMA / BEKLENMEDİK HATA → HAK İADE EDİLİYOR, sınıra yazılmadan.
    // `credit` burada tanımlı olmayabilir (hata tüketimden önce oluştuysa);
    // `callId` null ise `refundCredit` hiçbir şey yapmıyor.
    if (refundAuth != null) {
      await refundCredit(refundAuth, refundCallId, false);
    }
    return deny(500, String(e));
  }
});
