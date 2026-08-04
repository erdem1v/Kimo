// AI Gateway — soru fotoğrafından çoktan seçmeli şıkları çıkarır.
// OpenAI anahtarı SADECE burada (Supabase secret: OPENAI_API_KEY). Uygulamaya
// asla girmez. Yalnızca giriş yapmış kullanıcılar çağırabilir (verify_jwt).
//
// Deploy: supabase functions deploy analyze-question
// Secret: supabase secrets set OPENAI_API_KEY=sk-...

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
            "Sen bir YKS sorusu analiz aracısın. Verilen fotoğraftaki çoktan " +
            "seçmeli sorunun ŞIKLARINI aynen çıkar. Doğru cevabı SEN belirleme; " +
            "sadece şıkları listele. Şık yoksa has_options=false döndür.",
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Bu fotoğraftaki sorunun şıklarını çıkar. Her şıkkın harfini " +
                "(A, B, C, D, E) ve metnini ver.",
            },
            { type: "image_url", image_url: { url: dataUrl } },
          ],
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "question_options",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              has_options: { type: "boolean" },
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
            required: ["has_options", "options"],
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
