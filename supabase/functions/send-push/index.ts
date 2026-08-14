// Anlık bildirim gönderici. Veritabanı tetikleyicisi çağırır, bu fonksiyon
// kullanıcının cihaz kayıtlarını bulup FCM'e iletir.
//
// Gizli değerler (Supabase secrets):
//   FIREBASE_SERVICE_ACCOUNT  → Firebase servis hesabı JSON'ı (tek satır)
//   PUSH_SECRET               → app_config.push_secret ile aynı değer
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY → platform tarafından sağlanır
//
// Deploy: supabase functions deploy send-push --no-verify-jwt
// (Çağrı veritabanından geldiği için JWT yok; yetki x-push-secret ile.)

import { createClient } from "jsr:@supabase/supabase-js@2";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

// Erişim jetonu pahalı üretiliyor; örnek yaşadığı sürece saklanır.
let cachedToken: { value: string; expiresAt: number } | null = null;

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
  if (!res.ok) throw new Error(`token alınamadı: ${await res.text()}`);

  const data = await res.json();
  cachedToken = {
    value: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return cachedToken.value;
}

Deno.serve(async (req: Request) => {
  try {
    // Yetki: veritabanı tetikleyicisinin bildiği paylaşılan sır.
    const secret = Deno.env.get("PUSH_SECRET");
    const headerSecret = req.headers.get("x-push-secret");
    if (!secret || headerSecret !== secret) {
      // Sırrı sızdırmadan neyin uyuşmadığını söyle (teşhis için).
      return new Response(
        JSON.stringify({
          error: "yetkisiz",
          sunucuda_sir_var: Boolean(secret),
          sunucudaki_uzunluk: secret?.length ?? 0,
          gelen_baslik_var: headerSecret !== null,
          gelen_uzunluk: headerSecret?.length ?? 0,
        }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    // Gövdeyi savunmacı ayrıştır: boş/bozuk gelirse net söyle.
    const raw = await req.text();
    let payload: Record<string, unknown> = {};
    try {
      payload = raw ? JSON.parse(raw) : {};
    } catch (_e) {
      return new Response(
        JSON.stringify({ error: "gövde JSON değil", uzunluk: raw.length }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }
    const user_id = payload.user_id as string | undefined;
    const title = payload.title as string | undefined;
    const body = payload.body as string | undefined;
    const kind = payload.kind as string | undefined;
    if (!user_id || !body) {
      return new Response(
        JSON.stringify({ error: "eksik alan", govde_uzunlugu: raw.length }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
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
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    // Servis hesabı: en sık hata kaynağı, o yüzden ayrı ayrı kontrol et.
    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
    if (saRaw.trim().length === 0) {
      return new Response(
        JSON.stringify({
          error: "FIREBASE_SERVICE_ACCOUNT boş ya da tanımsız",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }
    let sa: ServiceAccount;
    try {
      sa = JSON.parse(saRaw);
    } catch (_e) {
      return new Response(
        JSON.stringify({
          error: "FIREBASE_SERVICE_ACCOUNT geçerli JSON değil",
          uzunluk: saRaw.length,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }
    if (!sa.client_email || !sa.private_key || !sa.project_id) {
      return new Response(
        JSON.stringify({ error: "servis hesabı JSON'ında alan eksik" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
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
            notification: { title: title ?? "AI YKS Coach", body },
            data: { kind: kind ?? "" },
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
        // Kayıtlı olmayan/geçersiz jetonları temizleyelim.
        if (text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
          stale.push(token);
        }
      }
    }

    if (stale.length > 0) {
      await supabase.from("device_tokens").delete().in("token", stale);
    }

    return new Response(JSON.stringify({ sent, cleaned: stale.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
