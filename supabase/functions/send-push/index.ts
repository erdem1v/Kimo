// Anlık bildirim gönderici. Veritabanı tetikleyicisi çağırır, bu fonksiyon
// kullanıcının cihaz kayıtlarını bulup FCM'e iletir.
//
// YETKİ MODELİ (0028 göçüyle değişti):
// Eskiden fonksiyon `--no-verify-jwt` ile yayımlanıyordu ve tek koruma
// `x-push-secret` başlığıydı. O model dört ayrı sorun üretiyordu: 401 gövdesi
// sunucudaki sırrın tam uzunluğunu yayınlıyordu, karşılaştırma sabit zamanlı
// değildi, deneme sınırı yoktu ve uç nokta kimlik doğrulamasız olarak internete
// açıktı.
//
// Artık doğrulamayı Supabase ağ geçidi yapıyor: config.toml'da
// [functions.send-push] verify_jwt = true. Geçersiz ya da eksik JWT bu koda
// HİÇ ULAŞMADAN reddediliyor — yani sır karşılaştırması, uzunluk sızıntısı ve
// kaba kuvvet yüzeyi tamamen ortadan kalktı. Veritabanı çağrıyı app_config'teki
// service_role jetonuyla imzalıyor (bkz. public.send_push).
//
// Gizli değerler (Supabase secrets):
//   FIREBASE_SERVICE_ACCOUNT  → Firebase servis hesabı JSON'ı (tek satır)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY → platform tarafından sağlanır
//
// Deploy (artık bayrak YOK):
//   supabase functions deploy send-push

import { createClient } from "jsr:@supabase/supabase-js@2";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/** Yalnızca veritabanı tetikleyicilerinin ürettiği senaryolar. */
const ALLOWED_KINDS = new Set([
  "question_received",
  "friend_request",
  "question_solved",
  "friend_league_up",
  "friend_streak",
]);

const MAX_TITLE = 120;
const MAX_BODY = 400;

// Erişim jetonu pahalı üretiliyor; örnek yaşadığı sürece saklanır.
let cachedToken: { value: string; expiresAt: number } | null = null;

/**
 * Tek tip, ayrıntısız hata. Dışarıya HİÇBİR iç durum sızdırmaz: uzunluk yok,
 * "sunucuda sır var mı" yok, hangi alanın eksik olduğu yok. Teşhis sunucu
 * günlüğüne yazılır, yanıta değil.
 */
function deny(status: number, logDetail: string): Response {
  console.error(`[send-push] ${status}: ${logDetail}`);
  return new Response(JSON.stringify({ error: "gecersiz_istek" }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Ağ geçidi JWT imzasını zaten doğruladı (verify_jwt = true); burada yalnızca
 * rol iddiasını okuyoruz. Yani bu, imza doğrulaması DEĞİL — savunma derinliği:
 * geçerli bir SON KULLANICI jetonuyla yapılan çağrıyı da reddetmek için.
 * İmza doğrulamasının tek kaynağı ağ geçididir; verify_jwt kapatılırsa bu
 * kontrol tek başına yeterli olmaz.
 */
function isServiceRole(authHeader: string | null): boolean {
  if (!authHeader?.startsWith("Bearer ")) return false;
  const parts = authHeader.slice(7).trim().split(".");
  if (parts.length !== 3) return false;
  try {
    const pad = "=".repeat((4 - (parts[1].length % 4)) % 4);
    const json = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/") + pad);
    return JSON.parse(json)?.role === "service_role";
  } catch {
    return false;
  }
}

function pemToBinary(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Servis hesabıyla imzalanmış JWT'yi OAuth2 erişim jetonuna çevirir. */
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(sa.private_key.replace(/\\n/g, "\n")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const jwt = `${header}.${claims}.${b64url(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`token alınamadı: ${res.status}`);

  const data = await res.json();
  cachedToken = {
    value: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return cachedToken.value;
}

Deno.serve(async (req: Request) => {
  try {
    // Ağ geçidi imzayı doğruladı; burada yalnızca "bu bir service_role jetonu mu"
    // sorusunu soruyoruz. Son kullanıcı jetonuyla yapılan çağrılar reddedilir.
    if (!isServiceRole(req.headers.get("Authorization"))) {
      return deny(403, "service_role olmayan cagri");
    }

    let payload: Record<string, unknown> = {};
    try {
      const raw = await req.text();
      payload = raw ? JSON.parse(raw) : {};
    } catch {
      return deny(400, "govde JSON degil");
    }

    const user_id = typeof payload.user_id === "string" ? payload.user_id : "";
    const kind = typeof payload.kind === "string" ? payload.kind : "";
    const title = typeof payload.title === "string" ? payload.title : "";
    const body = typeof payload.body === "string" ? payload.body : "";

    // UUID biçimi + senaryo beyaz listesi + uzunluk sınırları. Çağıran güvenilir
    // olsa da bunlar bozuk bir tetikleyicinin FCM'e çöp göndermesini engelliyor.
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(user_id)) {
      return deny(400, "user_id UUID degil");
    }
    if (!ALLOWED_KINDS.has(kind)) {
      return deny(400, `bilinmeyen kind: ${kind.slice(0, 40)}`);
    }
    if (!body || body.length > MAX_BODY || title.length > MAX_TITLE) {
      return deny(400, "body/title uzunlugu gecersiz");
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: rows } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id);

    const tokens: string[] = (rows ?? []).map((r: { token: string }) => r.token);
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
    let sa: ServiceAccount;
    try {
      sa = JSON.parse(saRaw);
    } catch {
      // Yapılandırma hatası: ayrıntı günlüğe, çağırana genel yanıt.
      return deny(500, "FIREBASE_SERVICE_ACCOUNT gecerli JSON degil ya da bos");
    }
    if (!sa.client_email || !sa.private_key || !sa.project_id) {
      return deny(500, "servis hesabi JSON'inda alan eksik");
    }

    const accessToken = await getAccessToken(sa);
    const endpoint =
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let sent = 0;
    const stale: string[] = [];

    for (const token of tokens) {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: title || "AI YKS Coach", body },
            data: { kind },
            android: {
              priority: "HIGH",
              notification: { channel_id: "social_events" },
            },
          },
        }),
      });
      if (res.ok) {
        sent++;
      } else {
        const text = await res.text();
        if (text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
          stale.push(token);
        }
      }
    }

    if (stale.length > 0) {
      // user_id ile sınırlı: servis rolüyle yapılan geniş bir silme olmasın.
      await supabase
        .from("device_tokens")
        .delete()
        .eq("user_id", user_id)
        .in("token", stale);
    }

    return new Response(JSON.stringify({ sent, cleaned: stale.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return deny(500, `beklenmeyen hata: ${String(e)}`);
  }
});
