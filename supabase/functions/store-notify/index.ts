// Mağaza sunucu bildirimleri — yenileme, iptal, İADE.
//
// BU DEPODAKİ İKİNCİ `verify_jwt = false` FONKSİYONU ve gerekçe `ad-reward`ın
// aynısı: bildirim MAĞAZANIN sunucusundan geliyor ve kullanıcı JWT'si
// TAŞIMIYOR. Doğrulama JWT ile değil, gönderenin kendi imzasıyla yapılıyor.
//
// KORUNAN DEĞİŞMEZ: HİÇBİR DOĞRULAMASIZ FONKSİYON SERVİS ROLÜ İSTEMCİSİ
// KURMAZ. Burada bir hata servis rolü anahtarıyla TÜM veritabanına dönüşürdü.
// Yazma yolu `anon`-çağrılabilir tek bir RPC ve paylaşılan bir sır
// (`apply_subscription`, göç 0092).
//
// NEDEN BU FONKSİYON VAR (uçtan uca senkron doğrulama varken): abonelik
// durumu ZAMAN İÇİNDE DEĞİŞİYOR ve bu değişiklikler uygulama açılmadan
// oluyor. Kurulmasaydı:
//   * iptal eden kullanıcı süre sonuna kadar premium kalırdı — KABUL EDİLEBİLİR
//     (zaten ödediği dönem).
//   * İADE ALAN KULLANICI PREMIUM KALMAYA DEVAM EDERDİ — KABUL EDİLEMEZ.
//
// İKİ KATMAN: bu webhook ANINDA yakalıyor; `reconcile-subscriptions` gecelik
// mutabakatı, konsolda geri çağrı adresi yanlış kurulsa ya da bir bildirim
// kaybolsa bile en geç 24 saatte kapatıyor. Webhook'un sessizce çalışmaması
// tam olarak fark edilmeyecek türden bir arıza.
//
// YANIT POLİTİKASI (`ad-reward`dan birebir):
//   * KARARA BAĞLANMIŞ sonuçlar → 200 + log. Apple 2xx almazsa üç gün boyunca
//     artan aralıklarla tekrar dener; Pub/Sub ack almazsa mesajı sonsuza kadar
//     yeniden teslim eder.
//   * KARARA BAĞLANMAMIŞ (RPC ağ hatası / 5xx) → 503, ki mağazanın yeniden
//     denemesi veritabanı kısa süre düştüğünde gerçek bir emniyet ağı olsun.
//
// Gizliler: IAP_SECRET · APPLE_BUNDLE_ID · GOOGLE_PUBSUB_AUDIENCE
// Deploy: supabase functions deploy store-notify
// config.toml: [functions.store-notify] verify_jwt = false

import { decodeJwsPayload } from "../_shared/stores.ts";
import { applySubscription } from "../_shared/iap.ts";

const TAG = "store-notify";

/** Karara bağlanmış: mağaza yeniden DENEMESİN. */
function settled(reason: string): Response {
  console.log(`[${TAG}] karara baglandi: ${reason}`);
  return new Response("ok", { status: 200 });
}

/** Karara bağlanmadı: mağaza yeniden DENESİN. */
function retryable(reason: string): Response {
  console.error(`[${TAG}] gecici hata: ${reason}`);
  return new Response("retry", { status: 503 });
}

// ------------------------------------------------------------------ Apple
//
// İMZA DOĞRULAMASI: `signedPayload` bir JWS ve başlığındaki `x5c` zinciri
// Apple Root CA G3'e kadar doğrulanmalı. BU DOĞRULAMA HENÜZ YAZILMADI ve
// fonksiyon o yüzden İMZAYA GÜVENMİYOR: yükten yalnızca
// `originalTransactionId` okunuyor ve durum MAĞAZANIN KENDİ API'sinden
// yeniden soruluyor (`reconcile` ile aynı yol). Yani sahte bir bildirim en
// fazla gereksiz bir API çağrısı ürettirir; abonelik durumunu DEĞİŞTİREMEZ.
//
// Bu bilinçli bir takas: x5c zincir doğrulaması yazılıp SINANMADAN
// güvenilmemeli (`ad-reward/ssv.ts` 200 gerçek imzayla sınanmıştı; burada
// sınayacak imza yok, çünkü Apple hesabı yok).
async function handleApple(body: Record<string, unknown>): Promise<Response> {
  const signed = body.signedPayload;
  if (typeof signed !== "string") return settled("apple: signedPayload yok");

  let payload: Record<string, unknown>;
  try {
    payload = decodeJwsPayload(signed);
  } catch {
    return settled("apple: JWS cozulemedi");
  }

  const data = payload.data as Record<string, unknown> | undefined;
  const txnJws = data?.signedTransactionInfo;
  if (typeof txnJws !== "string") return settled("apple: islem bilgisi yok");

  let txn: Record<string, unknown>;
  try {
    txn = decodeJwsPayload(txnJws);
  } catch {
    return settled("apple: islem JWS'i cozulemedi");
  }

  const bundleId = Deno.env.get("APPLE_BUNDLE_ID");
  if (bundleId && txn.bundleId && txn.bundleId !== bundleId) {
    return settled(`apple: baska uygulamanin bildirimi (${txn.bundleId})`);
  }

  const originalTxnId = String(txn.originalTransactionId ?? "");
  if (!originalTxnId) return settled("apple: originalTransactionId yok");

  // Durum MAĞAZANIN API'sinden yeniden soruluyor; bildirimin kendisine
  // güvenilmiyor (yukarıdaki imza notu).
  return await reapply("ios", originalTxnId, payload);
}

// ----------------------------------------------------------------- Google
//
// Pub/Sub push'u `Authorization: Bearer <OIDC>` taşıyor ve jetonun `aud`u
// bizim fonksiyon adresimiz olmalı. Apple'daki aynı takas: jeton Google'ın
// JWKS'iyle doğrulanmadığı sürece ona GÜVENİLMİYOR — yükten yalnızca
// `purchaseToken` okunuyor ve durum Play API'sinden yeniden soruluyor.
async function handleGoogle(body: Record<string, unknown>): Promise<Response> {
  const message = body.message as Record<string, unknown> | undefined;
  const dataB64 = message?.data;
  if (typeof dataB64 !== "string") return settled("google: message.data yok");

  let notice: Record<string, unknown>;
  try {
    notice = JSON.parse(atob(dataB64));
  } catch {
    return settled("google: bildirim cozulemedi");
  }

  const sub = notice.subscriptionNotification as
    | Record<string, unknown>
    | undefined;
  // Test bildirimi ve tek seferlik ürün bildirimleri: karara bağlanmış.
  if (!sub) return settled("google: abonelik bildirimi degil");

  const purchaseToken = String(sub.purchaseToken ?? "");
  if (!purchaseToken) return settled("google: purchaseToken yok");

  return await reapply("android", purchaseToken, notice);
}

/**
 * Durumu mağazadan YENİDEN OKUYUP deftere yazar. Bildirimin içindeki duruma
 * güvenmemenin bedeli bir API çağrısı; karşılığı, imza doğrulaması olmadan da
 * sahte bildirimin abonelik DEĞİŞTİREMEMESİ.
 */
async function reapply(
  platform: "ios" | "android",
  originalTxnId: string,
  raw: unknown,
): Promise<Response> {
  const nowSec = Math.floor(Date.now() / 1000);
  try {
    const stores = await import("../_shared/stores.ts");
    let state = null;
    if (platform === "ios") {
      const cfg = stores.appleConfig();
      if (!cfg) return retryable("apple gizlileri tanimli degil");
      state = await stores.appleSubscription(cfg, originalTxnId, nowSec);
    } else {
      const cfg = stores.googleConfig();
      if (!cfg) return retryable("google gizlileri tanimli degil");
      state = await stores.googleSubscription(cfg, originalTxnId, nowSec);
    }

    if (!state) {
      // Mağaza artık bu makbuzu tanımıyor: iade/iptal sonrası temizlik.
      // Defteri süresi dolmuş işaretliyoruz — premium ANINDA düşüyor.
      const ok = await applySubscription({
        platform,
        originalTxnId,
        status: "expired",
        expiresAt: new Date().toISOString(),
        raw,
      });
      return settled(`makbuz magazada yok, defter kapatildi (yazildi=${ok})`);
    }

    const ok = await applySubscription({
      platform,
      originalTxnId: state.originalTxnId,
      status: state.status,
      expiresAt: state.expiresAt,
      autoRenewing: state.autoRenewing,
      productId: state.productId,
      raw,
    });
    return settled(`durum=${state.status} yazildi=${ok}`);
  } catch (e) {
    return retryable(`magaza ya da RPC hatasi: ${e}`);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return settled(`yontem: ${req.method}`);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return settled("govde JSON degil");
  }

  if (typeof body.signedPayload === "string") return await handleApple(body);
  if (body.message) return await handleGoogle(body);
  return settled("taninmayan bildirim bicimi");
});
