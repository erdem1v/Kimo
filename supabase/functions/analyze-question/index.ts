// AI Gateway — soru fotoğrafını değerlendirir ve çoktan seçmeli şıkları çıkarır.
// Geçerli sayılması için fotoğrafta: (1) net OKUNABİLİR olmalı, (2) bir SORU/
// problem ifadesi olmalı, (3) ŞIKLAR olmalı. Değilse ilgili bayrak false olur
// ve reason'a kısa Türkçe sebep yazılır.
//
// OpenAI anahtarı SADECE burada (Supabase secret: OPENAI_API_KEY).
// Deploy: supabase functions deploy analyze-question

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

    const { imageBase64, mimeType } = await req.json().catch(() => ({}));
    if (!imageBase64) return json({ error: "imageBase64 gerekli" }, 400);

    const dataUrl = `data:${mimeType ?? "image/jpeg"};base64,${imageBase64}`;

    const payload = {
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content:
            "Sen bir YKS sorusu doğrulama ve şık çıkarma aracısın. Verilen " +
            "fotoğrafı değerlendir. GEÇERLİ bir çoktan seçmeli soru fotoğrafı " +
            "için üç şart: (1) metin net OKUNABİLİR, (2) bir SORU/problem " +
            "ifadesi var, (3) ŞIKLAR var. is_readable, has_question, " +
            "has_options bayraklarını buna göre doldur. Şıkları aynen çıkar " +
            "(doğru cevabı SEN belirleme). Geçerli değilse 'reason' alanına " +
            "kısa Türkçe sebep yaz (ör. 'Sadece şıklar var, soru görünmüyor' " +
            "veya 'Fotoğraf bulanık/okunmuyor'); geçerliyse reason boş kalsın.",
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Bu fotoğrafı değerlendir ve varsa şıkları (harf + metin) çıkar.",
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
    return json(JSON.parse(content), 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
