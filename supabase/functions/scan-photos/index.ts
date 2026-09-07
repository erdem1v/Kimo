// Fotoğraf içerik taraması (Task 03, bulgu 4.3).
//
// `mistakes.photo_scan = 'pending'` satırlarının nesnelerini depodan indirir,
// OpenAI moderation API'sine (omni-moderation-latest, ücretsiz) gösterir ve
// kararı yazar: temiz → 'clear', şüpheli → 'flagged'. 'clear' olmayan fotoğraf
// PAYLAŞIMA ÇIKAMAZ (0050 göçündeki kapılar); sahibinin kendi erişimi hiçbir
// durumda kısıtlanmaz — yanlış pozitif öğrenciyi kilitlemez.
//
// NEDEN KAYITLI NESNE TARANIYOR (analyze-question içinde değil):
//   • elle giriş ve kota-bitmiş yolunda analiz hiç çağrılmıyor;
//   • analiz ham byte görüyor — istemci masum görsel analiz ettirip depoya
//     BAŞKA byte yükleyebilir. Karar yüklenen nesneye bağlanmalı.
//
// İKİ ÇAĞIRMA MODU:
//   • Kullanıcı hızlı yolu: istemci, kayıttan hemen sonra KENDİ JWT'siyle
//     çağırır; yalnızca ÇAĞIRANIN pending satırları taranır. Mutlu yolda
//     paylaşım saniyeler içinde açılır. `bump_rate_limit` ile günde 20 çağrı —
//     uç nokta bedava bir "moderasyon kâhini"ne dönüşmesin.
//   • Süpürme: pg_cron 10 dakikada bir service_role jetonuyla çağırır (0051);
//     çöken istemcilerin, elle girişlerin ve çevrimdışı kuyrukların satırları
//     böylece takılı kalmaz. Parti başına üst sınır var.
//
// Tarama BAŞARISIZSA satır 'pending' kalır: paylaşıma kapalı (temkinli),
// kişisel kullanıma açık — task'ın istediği denge.
//
// Gizli değerler: OPENAI_API_KEY (analyze-question ile aynı sır).
// Deploy: supabase functions deploy scan-photos

import { createClient } from "jsr:@supabase/supabase-js@2";

/** Süpürme partisi üst sınırı: tek çağrı sınırsız iş yapmasın. */
const SWEEP_BATCH = 50;

/** Kullanıcı hızlı yolunda taranacak en fazla satır. */
const USER_BATCH = 10;

function deny(status: number, logDetail: string): Response {
  console.error(`[scan-photos] ${status}: ${logDetail}`);
  return new Response(JSON.stringify({ error: "gecersiz_istek" }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** JWT gövdesinden rol/uid oku (imzayı ağ geçidi doğruladı — verify_jwt). */
function claimsOf(
  authHeader: string | null,
): { role: string | null; sub: string | null } {
  if (!authHeader?.startsWith("Bearer ")) return { role: null, sub: null };
  const parts = authHeader.slice(7).trim().split(".");
  if (parts.length !== 3) return { role: null, sub: null };
  try {
    const pad = "=".repeat((4 - (parts[1].length % 4)) % 4);
    const body = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/") + pad),
    );
    return { role: body?.role ?? null, sub: body?.sub ?? null };
  } catch {
    return { role: null, sub: null };
  }
}

/** Base64 (chunk'lı — büyük dizilerde çağrı yığını taşmasın). */
function toBase64(bytes: Uint8Array): string {
  let bin = "";
  const CHUNK = 0x8000;
  for (let i = 0; i < bytes.length; i += CHUNK) {
    bin += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(bin);
}

/**
 * Tek bir görseli moderasyona gösterir. `true` = şüpheli.
 * Hata fırlatırsa çağıran satırı 'pending' bırakır.
 */
async function isFlagged(apiKey: string, bytes: Uint8Array): Promise<boolean> {
  const resp = await fetch("https://api.openai.com/v1/moderations", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "omni-moderation-latest",
      input: [{
        type: "image_url",
        image_url: { url: `data:image/jpeg;base64,${toBase64(bytes)}` },
      }],
    }),
  });
  if (!resp.ok) {
    // Gövde istemciye YANSITILMAZ (analyze-question ile aynı kural).
    throw new Error(`moderation ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  return data?.results?.[0]?.flagged === true;
}

Deno.serve(async (req: Request) => {
  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) return deny(500, "OPENAI_API_KEY tanımlı değil");

    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return deny(500, "platform env eksik");

    const auth = req.headers.get("Authorization");
    const { role, sub } = claimsOf(auth);

    // Depo indirme ve karar yazma HER ZAMAN servis rolüyle: photo_scan
    // istemciye kapalı bir kolon ve depo nesnesi sahibinden bağımsız
    // okunabilmeli. Kullanıcı yolunda kapsam aşağıda uid süzgeciyle daralıyor.
    const admin = createClient(url, serviceKey);

    let scope: { uid: string | null; limit: number };
    if (role === "service_role") {
      scope = { uid: null, limit: SWEEP_BATCH };
    } else if (sub) {
      // Kullanıcı hızlı yolu: yalnızca kendi bekleyenleri + oran sınırı.
      // RPC çağıranın JWT'siyle yapılır ki auth.uid() doğru olsun.
      const anon = Deno.env.get("SUPABASE_ANON_KEY");
      if (!anon) return deny(500, "SUPABASE_ANON_KEY tanımlı değil");
      const rl = await fetch(`${url}/rest/v1/rpc/consume_scan_use`, {
        method: "POST",
        headers: {
          "Authorization": auth!,
          "apikey": anon,
          "Content-Type": "application/json",
        },
        body: "{}",
      });
      if (!rl.ok) {
        return deny(429, `scan oran sınırı: ${rl.status} ${await rl.text()}`);
      }
      if ((await rl.json()) !== true) {
        return deny(429, "scan günlük sınır aşıldı");
      }
      scope = { uid: sub, limit: USER_BATCH };
    } else {
      return deny(401, "kimlik yok");
    }

    let query = admin
      .from("mistakes")
      .select("id, photo_path")
      .eq("photo_scan", "pending")
      .not("photo_path", "is", null)
      .order("created_at", { ascending: true })
      .limit(scope.limit);
    if (scope.uid) query = query.eq("user_id", scope.uid);

    const { data: rows, error } = await query;
    if (error) return deny(500, `pending listesi: ${error.message}`);

    let cleared = 0, flagged = 0, failed = 0;
    for (const row of rows ?? []) {
      try {
        const { data: blob, error: dlErr } = await admin.storage
          .from("mistake-photos")
          .download(row.photo_path);
        if (dlErr || !blob) {
          // Nesne yoksa (yükleme yarıda kalmış) satırı temiz sayma; pending
          // kalsın — süpürücü nesne gelince yeniden dener, gelmezse paylaşım
          // zaten kapalı.
          failed++;
          console.error(`[scan-photos] indirme: ${row.photo_path}: ${dlErr?.message}`);
          continue;
        }
        const bytes = new Uint8Array(await blob.arrayBuffer());
        const bad = await isFlagged(apiKey, bytes);
        const { error: upErr } = await admin
          .from("mistakes")
          .update({
            photo_scan: bad ? "flagged" : "clear",
            photo_scan_at: new Date().toISOString(),
          })
          .eq("id", row.id)
          .eq("photo_scan", "pending"); // yarışta admin kararını ezme
        if (upErr) throw new Error(upErr.message);
        if (bad) flagged++;
        else cleared++;
      } catch (e) {
        failed++;
        console.error(`[scan-photos] ${row.id}: ${e}`);
      }
    }

    return json({ scanned: cleared + flagged, cleared, flagged, failed });
  } catch (e) {
    return deny(500, String(e));
  }
});
