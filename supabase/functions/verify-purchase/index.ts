// Satın alma doğrulaması — istemcinin premium olduğu TEK yol.
//
// AKIŞ: istemci `in_app_purchase` ile satın alıyor, mağazadan bir jeton/JWS
// alıyor ve onu BURAYA gönderiyor. Bu fonksiyon jetonu MAĞAZANIN KENDİ
// sunucusuna soruyor; istemcinin söylediğine hiçbir noktada güvenilmiyor.
//
// NEDEN `verify_jwt = true`: hangi kullanıcıya yazılacağı GÖVDEDEN DEĞİL
// JWT'DEN okunuyor. `delete-account` / `delete-question` ile aynı gerekçe —
// kapatılsaydı bu fonksiyon "herkese premium yaz" primitifine dönerdi.
//
// NEDEN SENKRON: kullanıcı parayı ödedi ve premium'un ne zaman görüneceğini
// bilmek zorunda. `ad-reward`da "geri çağrı gelmedi mi, reddedildi mi" ayrımı
// yapılamıyordu; burada yanıt anında dönüyor. Mağaza sunucu bildirimleri
// (`store-notify`) YEDEK yol, birincil değil.
//
// Gizliler: IAP_SECRET · APPLE_IAP_KEY / APPLE_IAP_KEY_ID / APPLE_IAP_ISSUER_ID
//           / APPLE_BUNDLE_ID · GOOGLE_PLAY_SERVICE_ACCOUNT / ANDROID_PACKAGE_NAME
// Deploy: supabase functions deploy verify-purchase
// config.toml: [functions.verify-purchase] verify_jwt = true

import {
  appleConfig,
  appleSubscription,
  googleAcknowledge,
  googleConfig,
  googleSubscription,
} from "../_shared/stores.ts";
import { applySubscription, deny } from "../_shared/iap.ts";

const TAG = "verify-purchase";

/** JWT'den kullanıcı kimliği. Ağ geçidi imzayı zaten doğruladı. */
function uidFromJwt(authHeader: string | null): string | null {
  if (!authHeader?.startsWith("Bearer ")) return null;
  const parts = authHeader.slice(7).trim().split(".");
  if (parts.length !== 3) return null;
  try {
    const pad = "=".repeat((4 - (parts[1].length % 4)) % 4);
    const json = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/") + pad);
    const claims = JSON.parse(json);
    // ANONİM KULLANICI SATIN ALAMAZ. `user_tier()` `is_anonymous`ı premium'dan
    // ÖNCE değerlendiriyor: anonim biri abone olsa bile katmanı `anonymous`
    // kalır ve 3 ömürlük hakka takılı olurdu — yani para alınıp hak
    // verilmezdi. Akış burada ve paywall'da kapatılıyor.
    if (claims?.is_anonymous === true) return null;
    return typeof claims?.sub === "string" ? claims.sub : null;
  } catch {
    return null;
  }
}

function json(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return deny(TAG, 405, `yontem: ${req.method}`);

  const uid = uidFromJwt(req.headers.get("Authorization"));
  if (!uid) return deny(TAG, 401, "oturum yok ya da anonim");

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return deny(TAG, 400, "govde JSON degil");
  }

  const platform = body.platform;
  const token = body.token;
  if (platform !== "ios" && platform !== "android") {
    return deny(TAG, 400, `platform: ${String(platform).slice(0, 20)}`);
  }
  if (typeof token !== "string" || token.length === 0 || token.length > 8192) {
    return deny(TAG, 400, "jeton yok ya da makul olmayan uzunlukta");
  }

  const nowSec = Math.floor(Date.now() / 1000);

  try {
    if (platform === "ios") {
      const cfg = appleConfig();
      if (!cfg) return deny(TAG, 503, "Apple gizlileri tanimli degil");
      const state = await appleSubscription(cfg, token, nowSec);
      if (!state) return deny(TAG, 404, "Apple makbuzu bulunamadi");
      const ok = await applySubscription({
        platform: "ios",
        originalTxnId: state.originalTxnId,
        status: state.status,
        expiresAt: state.expiresAt,
        autoRenewing: state.autoRenewing,
        productId: state.productId,
        userId: uid,
      });
      if (!ok) return deny(TAG, 409, "defter yazilamadi (sir? cakisma?)");
      return json({ status: state.status, expires_at: state.expiresAt });
    }

    const cfg = googleConfig();
    if (!cfg) return deny(TAG, 503, "Google gizlileri tanimli degil");
    const state = await googleSubscription(cfg, token, nowSec);
    if (!state) return deny(TAG, 404, "Play satin almasi bulunamadi");
    const ok = await applySubscription({
      platform: "android",
      originalTxnId: state.originalTxnId,
      status: state.status,
      expiresAt: state.expiresAt,
      autoRenewing: state.autoRenewing,
      productId: state.productId,
      userId: uid,
    });
    if (!ok) return deny(TAG, 409, "defter yazilamadi (sir? cakisma?)");

    // ONAY EN SONA: Play, üç gün içinde onaylanmayan satın almayı İADE EDİYOR.
    // Defter yazılmadan onaylasaydık "para alındı, hak yok" durumunu kalıcı
    // hâle getirirdik. Onay düşerse kullanıcı zaten premium; günlüğe yazıp
    // geçiyoruz ve gecelik mutabakat ikinci şansı veriyor.
    try {
      await googleAcknowledge(cfg, token, nowSec);
    } catch (e) {
      console.error(`[${TAG}] Play onayi basarisiz: ${e}`);
    }
    return json({ status: state.status, expires_at: state.expiresAt });
  } catch (e) {
    return deny(TAG, 503, `magaza dogrulamasi basarisiz: ${e}`);
  }
});
