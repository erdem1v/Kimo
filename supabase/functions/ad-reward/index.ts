// AdMob ödüllü reklam geri çağrısı — ödülün verildiği TEK yol.
//
// ÜRÜN: hak bittiğinde kullanıcı isteyerek bir ödüllü reklam izliyor ve 1
// analiz hakkı kazanıyor (günde en fazla 3). Ödül PENCEREYİ açıyor, aylık
// cap'i AÇMIYOR — aylık cap sert maliyet tavanı.
//
// ========================= NEDEN SERVİS ROLÜ KULLANMIYOR ====================
//
// Bu depoda `verify_jwt = false` olan İLK fonksiyon bu. Geri çağrı Google'ın
// sunucusundan, kullanıcı JWT'si olmadan, GET ile geliyor.
//
// Korunan değişmez: HİÇBİR DOĞRULAMASIZ FONKSİYON SERVİS ROLÜ İSTEMCİSİ
// KURMAZ. Burada bir hata (loglanan bir yapılandırma, kopyalanmış bir
// yardımcı, başlık ileten bir SSRF) servis rolü anahtarıyla TÜM veritabanına
// dönüşürdü. Ödül verme yolu bu yüzden `anon`-çağrılabilir TEK bir RPC ve
// paylaşılan bir sır (`grant_ad_reward`, göç 0076):
//
//   sır sızarsa hasar : bedava reklam hakkı.
//   anahtar sızarsa   : her satır + auth.admin.deleteUser.
//
// DÜRÜST KAYIT: Supabase servis rolü anahtarını HER edge fonksiyonunun
// ortamına enjekte ediyor ve bu kapatılamıyor. "Anahtarı taşımıyor" ifadesi
// yalnızca "hiçbir kod yolu onu okumuyor" anlamında doğru — isolate içinde
// rastgele kod yürütmeye karşı yalıtım DEĞİL. Bu yüzden dosya minik ve
// BAĞIMLILIKSIZ: `createClient` import edilmiyor, çıplak `fetch`
// (`analyze-question` ile aynı desen).
//
// ============================== YANIT POLİTİKASI ============================
//
// "Her zaman 200" YANLIŞ olurdu:
//   * KARARA BAĞLANMIŞ sonuçlar (bozuk imza, bilinmeyen nonce, eski damga,
//     tekrar, tavan aşımı) → 200 + log. 2xx olmayan yanıt AdMob'u asla
//     başarılı olmayacak bir istekte sonsuza kadar denemeye iter.
//   * KARARA BAĞLANMAMIŞ (RPC'nin kendisi ağ hatası / 5xx) → 503, ki AdMob'un
//     yeniden denemesi veritabanı kısa süre düştüğünde gerçek bir emniyet ağı
//     olsun. Hepsine 200 demek o ağı sessizce çöpe atardı.
//
// Deploy: supabase functions deploy ad-reward
// config.toml: [functions.ad-reward] verify_jwt = false

import {
  KeyStore,
  MAX_AGE_MS,
  signedPortion,
  verifySignature,
} from "./ssv.ts";

// Isolate ömrü boyunca paylaşılan anahtar önbelleği.
const keys = new KeyStore();

/** Karara bağlanmış sonuç: AdMob yeniden DENEMESİN. */
function settled(reason: string): Response {
  console.log(`[ad-reward] karara baglandi: ${reason}`);
  return new Response("ok", { status: 200 });
}

/** Karara bağlanmadı: AdMob yeniden DENESİN. */
function retryable(reason: string): Response {
  console.error(`[ad-reward] gecici hata: ${reason}`);
  return new Response("retry", { status: 503 });
}

/**
 * Ödülü verir. Dönüş: `true` verildi/zaten verilmiş, `false` reddedildi.
 * RPC'ye ULAŞILAMAZSA fırlatıyor — çağıran onu 503'e çeviriyor.
 */
async function grant(
  nonce: string,
  transactionId: string,
  adUnit: string,
): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const secret = Deno.env.get("AD_REWARD_SECRET");
  if (!url || !anon) {
    throw new Error("SUPABASE_URL / SUPABASE_ANON_KEY tanımlı değil");
  }
  // Sır yoksa RPC zaten reddeder (fail-closed); buradan da gitmiyoruz ki
  // boş bir sırla gereksiz bir tur atılmasın.
  if (!secret) throw new Error("AD_REWARD_SECRET tanımlı değil");

  const resp = await fetch(`${url}/rest/v1/rpc/grant_ad_reward`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${anon}`,
      "apikey": anon,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      p_nonce: nonce,
      p_transaction_id: transactionId,
      p_secret: secret,
    }),
  });
  if (!resp.ok) {
    throw new Error(`grant_ad_reward ${resp.status}: ${await resp.text()}`);
  }
  // `ad_unit` yalnızca teşhis için loglanıyor: hangi birimden geldiğini
  // bilmek doluluk sorunlarını ayırt etmeye yarıyor, karara girmiyor.
  const ok = await resp.json();
  console.log(`[ad-reward] birim=${adUnit} sonuc=${ok}`);
  return ok === true;
}

Deno.serve(async (req: Request) => {
  // AdMob GET ile geliyor. Başka bir yöntem bu uç noktaya ait değil.
  if (req.method !== "GET") return settled(`beklenmeyen yontem ${req.method}`);

  const url = new URL(req.url);
  const p = url.searchParams;

  // İMZALANAN METİN: ham sorgu dizesinin `&signature=` öncesi. Yeniden
  // kodlanmış bir sürüm doğrulamayı kesin bozar (bkz. ssv.ts).
  const signed = signedPortion(url.search);
  const signature = p.get("signature");
  const keyId = p.get("key_id");
  if (!signed || !signature || !keyId) return settled("imza ya da key_id yok");

  // TAZELİK: saatler önce yakalanmış bir geri çağrının tekrar oynatılması,
  // imza geçerli olsa bile kabul edilmemeli.
  const ts = Number(p.get("timestamp") ?? "");
  if (!Number.isFinite(ts) || Math.abs(Date.now() - ts) > MAX_AGE_MS) {
    return settled("damga eski ya da okunamadi");
  }

  const nonce = p.get("custom_data") ?? "";
  const transactionId = p.get("transaction_id") ?? "";
  if (!nonce || !transactionId) return settled("custom_data ya da txid yok");

  // `user_id` BİLEREK KULLANILMIYOR. İstemci onu kendisi set ediyor, yani bir
  // kimlik bilgisi değil; ödülün kime gideceğini `custom_data`'daki nonce
  // belirliyor ve o nonce'u sunucu üretti. Ayrıca istemci oraya Supabase
  // kimliğini HİÇ yazmıyor — ham bir uid reklam ağının sorgu dizesinde,
  // hukuki metinlerde sayılması gereken bir veri paylaşımı olurdu.

  let verified = false;
  try {
    const key = await keys.get(keyId);
    if (key === null) return settled(`bilinmeyen key_id ${keyId}`);
    verified = await verifySignature(signed, signature, key);
  } catch (e) {
    // Anahtar listesi çekilemedi: bu bizim tarafımızdaki geçici bir sorun,
    // geri çağrının suçu değil. AdMob yeniden denesin.
    return retryable(`anahtar dogrulamasi yapilamadi: ${e}`);
  }
  if (!verified) return settled("imza gecersiz");

  try {
    const ok = await grant(nonce, transactionId, p.get("ad_unit") ?? "");
    return settled(ok ? "odul verildi" : "odul reddedildi");
  } catch (e) {
    return retryable(`grant_ad_reward cagrilamadi: ${e}`);
  }
});
