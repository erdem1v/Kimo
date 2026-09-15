// Mağaza sunucu API'leri — Apple App Store Server API ve Google Play
// Developer API. İKİSİ DE YALNIZCA SUNUCUDA: `.p8` ES256 anahtarı ve servis
// hesabı JSON'ı istemciye HİÇ gitmiyor, edge gizlisi olarak duruyorlar
// (`send-push`in `FIREBASE_SERVICE_ACCOUNT` deseniyle aynı).
//
// NEDEN AYRI DOSYA: kırılgan kriptografi/ayrıştırma mantığı ayrı bir `.ts`ye
// alınır ve sınanır — `ad-reward/ssv.ts` + `ssv_test.ts` deseni.
//
// DÜRÜST KAYIT: bu dosya HİÇ ÇALIŞTIRILMADI. Ücretli Apple Developer ve Play
// Console hesapları yok; ne sandbox satın alma ne de gerçek bir API yanıtı
// görüldü. Alan adları Apple ve Google'ın belgelerinden yazıldı.

/** Defterin anladığı tek biçim. İki mağaza da buna indirgeniyor. */
export interface SubState {
  status: "trial" | "active" | "grace" | "expired" | "refunded" | "revoked";
  productId: string;
  originalTxnId: string;
  expiresAt: string | null;
  autoRenewing: boolean;
}

function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToBinary(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out.buffer;
}

/** JWS gövdesini İMZA DOĞRULAMADAN okur. Yalnızca imzası ayrıca doğrulanmış
 *  ya da kaynağı zaten güvenilen (bizim ürettiğimiz API yanıtı) veriler için. */
export function decodeJwsPayload(jws: string): Record<string, unknown> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("JWS bicimi gecersiz");
  const pad = "=".repeat((4 - (parts[1].length % 4)) % 4);
  const json = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/") + pad);
  return JSON.parse(json);
}

// ============================================================ APPLE
//
// App Store Server API, ES256 imzalı bir JWT ile yetkilendiriliyor. Anahtar
// App Store Connect'te üretilen `.p8`; `iss` ekip kimliği, `kid` anahtar
// kimliği, `bid` paket kimliği.
interface AppleCfg {
  keyId: string;
  issuerId: string;
  bundleId: string;
  privateKeyPem: string;
  sandbox: boolean;
}

export function appleConfig(): AppleCfg | null {
  const keyId = Deno.env.get("APPLE_IAP_KEY_ID");
  const issuerId = Deno.env.get("APPLE_IAP_ISSUER_ID");
  const bundleId = Deno.env.get("APPLE_BUNDLE_ID");
  const privateKeyPem = Deno.env.get("APPLE_IAP_KEY");
  if (!keyId || !issuerId || !bundleId || !privateKeyPem) return null;
  return {
    keyId,
    issuerId,
    bundleId,
    privateKeyPem: privateKeyPem.replace(/\\n/g, "\n"),
    // SANDBOX AYRI BİR TABAN ADRES. Yanlış taban 404 döner ve "abonelik yok"
    // gibi görünür — bu yüzden açık bir bayrak, tahmin değil.
    sandbox: (Deno.env.get("APPLE_IAP_SANDBOX") ?? "") === "true",
  };
}

async function appleToken(cfg: AppleCfg, nowSec: number): Promise<string> {
  const header = b64url(JSON.stringify({
    alg: "ES256",
    kid: cfg.keyId,
    typ: "JWT",
  }));
  const claims = b64url(JSON.stringify({
    iss: cfg.issuerId,
    iat: nowSec,
    exp: nowSec + 1800,
    aud: "appstoreconnect-v1",
    bid: cfg.bundleId,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(cfg.privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${b64url(new Uint8Array(sig))}`;
}

/** Apple'ın abonelik durumunu defterin biçimine indirger. */
export function appleToState(
  txn: Record<string, unknown>,
  renewal: Record<string, unknown>,
  statusCode: number,
): SubState {
  const expiresMs = Number(txn.expiresDate ?? 0);
  // Apple `status`: 1 aktif, 2 süresi doldu, 3 ödeme yeniden deneniyor
  // (grace), 4 ödeme onayı bekliyor, 5 iptal edildi/geri alındı.
  let status: SubState["status"];
  if (txn.revocationDate) status = "refunded";
  else if (statusCode === 1) {
    status = txn.offerType === 1 ? "trial" : "active";
  } else if (statusCode === 3 || statusCode === 4) status = "grace";
  else if (statusCode === 5) status = "revoked";
  else status = "expired";

  return {
    status,
    productId: String(txn.productId ?? ""),
    originalTxnId: String(txn.originalTransactionId ?? ""),
    expiresAt: expiresMs ? new Date(expiresMs).toISOString() : null,
    autoRenewing: Number(renewal.autoRenewStatus ?? 0) === 1,
  };
}

/** `originalTransactionId` için güncel abonelik durumu. */
export async function appleSubscription(
  cfg: AppleCfg,
  originalTxnId: string,
  nowSec: number,
): Promise<SubState | null> {
  const base = cfg.sandbox
    ? "https://api.storekit-sandbox.itunes.apple.com"
    : "https://api.storekit.itunes.apple.com";
  const jwt = await appleToken(cfg, nowSec);
  const res = await fetch(
    `${base}/inApps/v1/subscriptions/${encodeURIComponent(originalTxnId)}`,
    { headers: { Authorization: `Bearer ${jwt}` } },
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`apple ${res.status}`);

  const body = await res.json();
  const group = body?.data?.[0];
  const item = group?.lastTransactions?.[0];
  if (!item) return null;

  return appleToState(
    decodeJwsPayload(item.signedTransactionInfo),
    decodeJwsPayload(item.signedRenewalInfo),
    Number(item.status ?? 0),
  );
}

// ============================================================ GOOGLE PLAY
interface GoogleCfg {
  clientEmail: string;
  privateKey: string;
  packageName: string;
}

export function googleConfig(): GoogleCfg | null {
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT");
  const packageName = Deno.env.get("ANDROID_PACKAGE_NAME");
  if (!raw || !packageName) return null;
  try {
    const sa = JSON.parse(raw);
    if (!sa.client_email || !sa.private_key) return null;
    return {
      clientEmail: sa.client_email,
      privateKey: String(sa.private_key).replace(/\\n/g, "\n"),
      packageName,
    };
  } catch {
    return null;
  }
}

let googleToken: { value: string; expiresAt: number } | null = null;

async function googleAccessToken(cfg: GoogleCfg, nowSec: number): Promise<string> {
  if (googleToken && googleToken.expiresAt > nowSec + 60) return googleToken.value;

  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: cfg.clientEmail,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSec,
    exp: nowSec + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(cfg.privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(new Uint8Array(sig))}`,
    }),
  });
  if (!res.ok) throw new Error(`google token ${res.status}`);
  const data = await res.json();
  googleToken = {
    value: data.access_token,
    expiresAt: nowSec + (data.expires_in ?? 3600),
  };
  return googleToken.value;
}

/** Play'in `subscriptionsv2` yanıtını defterin biçimine indirger. */
export function googleToState(
  body: Record<string, unknown>,
  purchaseToken: string,
): SubState {
  const line = (body.lineItems as Array<Record<string, unknown>> | undefined)?.[0];
  const state = String(body.subscriptionState ?? "");
  // Play durumları: ..._ACTIVE, _IN_GRACE_PERIOD, _ON_HOLD, _CANCELED,
  // _EXPIRED, _PENDING, _PAUSED.
  let status: SubState["status"];
  if (state === "SUBSCRIPTION_STATE_ACTIVE") {
    status = line?.offerDetails &&
        (line.offerDetails as Record<string, unknown>).offerId
      ? "trial"
      : "active";
  } else if (
    state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ||
    state === "SUBSCRIPTION_STATE_ON_HOLD"
  ) {
    status = "grace";
  } else if (state === "SUBSCRIPTION_STATE_CANCELED") {
    // İPTAL DÜŞÜRMÜYOR: kullanıcı ödediği dönemin sonuna kadar premium kalır.
    // `expiryTime` zaten geleceği gösteriyor; `auto_renewing = false`.
    status = "active";
  } else {
    status = "expired";
  }

  return {
    status,
    productId: String(line?.productId ?? ""),
    originalTxnId: purchaseToken,
    expiresAt: (line?.expiryTime as string | undefined) ?? null,
    autoRenewing:
      String(body.subscriptionState ?? "") === "SUBSCRIPTION_STATE_ACTIVE",
  };
}

export async function googleSubscription(
  cfg: GoogleCfg,
  purchaseToken: string,
  nowSec: number,
): Promise<SubState | null> {
  const token = await googleAccessToken(cfg, nowSec);
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/` +
    `applications/${encodeURIComponent(cfg.packageName)}/purchases/` +
    `subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 404 || res.status === 410) return null;
  if (!res.ok) throw new Error(`google ${res.status}`);
  return googleToState(await res.json(), purchaseToken);
}

/** Play satın almasını ONAYLA. ÜÇ GÜN İÇİNDE yapılmazsa Google parayı İADE
 *  EDER. Doğrulama BAŞARILI olduktan SONRA çağrılmalı. */
export async function googleAcknowledge(
  cfg: GoogleCfg,
  purchaseToken: string,
  nowSec: number,
): Promise<void> {
  const token = await googleAccessToken(cfg, nowSec);
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/` +
    `applications/${encodeURIComponent(cfg.packageName)}/purchases/` +
    `subscriptions/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: "{}",
  });
  // Zaten onaylanmışsa Play 400 döndürüyor; bu bir hata değil.
  if (!res.ok && res.status !== 400) throw new Error(`ack ${res.status}`);
}
