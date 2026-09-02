// Veli onayı doğrulama sayfası.
//
// Veliye giden e-postadaki bağlantı buraya geliyor:
//   https://<proje>.functions.supabase.co/guardian-confirm?token=<32 bayt hex>
//
// KİMLİKSİZ (verify_jwt = false) ve bu ZORUNLU: velinin hesabı yok, olması da
// beklenmiyor. Task 01'in kapattığı "kimliksiz uç nokta" sınıfına komşu bir
// yüzey olduğu için sıkılaştırmalar açıkça yazılıyor:
//
//   • Token 32 bayt rastgele; veritabanında yalnızca SHA-256 HASH'i duruyor
//     (`guardian_requests.token_hash`). Veritabanı sızsa bile token üretilemez.
//   • Tek kullanımlık ve 7 gün geçerli — ikisi de `confirm_guardian_consent`
//     içinde uygulanıyor, burada değil.
//   • Doğrulama SUNUCUDA: bu fonksiyon token'ı yalnızca TAŞIYOR.
//   • `confirm_guardian_consent` **`user_id` parametresi ALMIYOR**; kullanıcıyı
//     token'ın kendisinden çözüyor. Task 01'in "hiçbir RPC user_id almaz"
//     değişmezi burada da geçerli.
//   • Yanıt HTML; başarı ile başarısızlık AYNI hızda dönüyor ve gövde iç durum
//     sızdırmıyor ("geçersiz ya da süresi dolmuş" tek mesaj — token'ın var olup
//     olmadığı ayırt edilmiyor).
//
// Deploy: supabase functions deploy guardian-confirm --no-verify-jwt

const HTML_HEADERS = {
  "Content-Type": "text/html; charset=utf-8",
  "Cache-Control": "no-store",
  // Sayfa tek başına duruyor; hiçbir dış kaynağa ihtiyacı yok.
  "Content-Security-Policy":
    "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

function page(title: string, body: string, status = 200): Response {
  return new Response(
    `<!doctype html><html lang="tr"><head><meta charset="utf-8">` +
      `<meta name="viewport" content="width=device-width,initial-scale=1">` +
      `<title>${title}</title><style>` +
      `body{margin:0;min-height:100vh;display:flex;align-items:center;` +
      `justify-content:center;background:#FDFAF6;color:#191713;` +
      `font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}` +
      `main{max-width:34rem;padding:2rem;text-align:center}` +
      `h1{font-size:1.5rem;margin:0 0 .75rem}` +
      `p{margin:0;color:#5C564C;line-height:1.55}` +
      `</style></head><body><main><h1>${title}</h1><p>${body}</p></main>` +
      `</body></html>`,
    { status, headers: HTML_HEADERS },
  );
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") {
    return page("Sayfa bulunamadı", "Bu bağlantı geçerli değil.", 405);
  }

  try {
    const url = new URL(req.url);
    const token = url.searchParams.get("token") ?? "";

    // Biçim kontrolü ÖNCE: 64 hex karakter dışındaki her şey veritabanına hiç
    // gitmiyor. Rastgele istekler için sorgu maliyeti üretmenin anlamı yok.
    if (!/^[0-9a-f]{64}$/.test(token)) {
      return page(
        "Bağlantı geçersiz",
        "Bu onay bağlantısı geçersiz ya da süresi dolmuş. " +
          "Öğrencinin uygulamadan yeni bir onay e-postası göndermesini isteyin.",
        400,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      console.error("[guardian-confirm] SUPABASE_URL / SERVICE_ROLE_KEY yok");
      return page("Bir sorun oluştu", "Lütfen daha sonra tekrar deneyin.", 500);
    }

    // `confirm_guardian_consent` kimseye açık değil (0049 beyaz listesinde de
    // yok); yalnızca servis rolüyle çağrılıyor.
    const resp = await fetch(
      `${supabaseUrl}/rest/v1/rpc/confirm_guardian_consent`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${serviceKey}`,
          "apikey": serviceKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ p_token: token }),
      },
    );

    if (!resp.ok) {
      console.error(`[guardian-confirm] rpc ${resp.status}: ${await resp.text()}`);
      return page("Bir sorun oluştu", "Lütfen daha sonra tekrar deneyin.", 500);
    }

    const rows = await resp.json();
    const row = Array.isArray(rows) ? rows[0] : rows;

    if (row?.ok === true) {
      return page(
        "Onayınız alındı",
        "Teşekkürler. Öğrencinin arkadaş ekleme özelliği açıldı. " +
          "Bu sayfayı kapatabilirsiniz.",
      );
    }

    // TEK MESAJ: token yok / süresi dolmuş / zaten kullanılmış ayrımı
    // yapılmıyor. Ayırmak, geçerli bir token'ı yoklamayı kolaylaştırırdı.
    return page(
      "Bağlantı geçersiz",
      "Bu onay bağlantısı geçersiz ya da süresi dolmuş. " +
        "Öğrencinin uygulamadan yeni bir onay e-postası göndermesini isteyin.",
      400,
    );
  } catch (e) {
    console.error(`[guardian-confirm] ${e}`);
    return page("Bir sorun oluştu", "Lütfen daha sonra tekrar deneyin.", 500);
  }
});
