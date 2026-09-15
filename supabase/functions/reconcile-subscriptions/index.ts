// Gecelik abonelik mutabakatı — webhook'un SESSİZCE çalışmamasına karşı.
//
// NEDEN İKİ KATMAN: `store-notify` bildirimleri anında işliyor, ama o yolun
// bozuk olması FARK EDİLMEYEN türden bir arıza — konsolda geri çağrı adresi
// yanlış girilmiş olabilir, Pub/Sub aboneliği silinmiş olabilir, bir bildirim
// kaybolmuş olabilir. Hiçbirinde bir hata görünmez; yalnızca iade alan
// kullanıcılar premium kalmaya devam eder.
//
// Bu iş, aktif görünen her aboneliği MAĞAZANIN KENDİ API'sine yeniden soruyor
// ve sapma varsa düzeltiyor. Webhook hiç kurulmasa bile iade en geç 24 saatte
// kapanıyor.
//
// NEDEN `verify_jwt = true`: yalnızca pg_cron çağırıyor ve servis rolü jetonu
// taşıyor (`cleanup-anonymous` / `scan-photos` süpürmesiyle aynı desen).
//
// SIRLAR GİRİLMEMİŞSE NO-OP: hata üretmiyor, günlüğe yazıyor. `db reset` ve
// sırsız ortam bu işi çalıştırabilmeli.
//
// Deploy: supabase functions deploy reconcile-subscriptions
// config.toml: [functions.reconcile-subscriptions] verify_jwt = true

import {
  appleConfig,
  appleSubscription,
  googleConfig,
  googleSubscription,
} from "../_shared/stores.ts";
import { applySubscription } from "../_shared/iap.ts";

const TAG = "reconcile-subscriptions";

/** Ağ geçidi imzayı doğruladı; burada yalnızca rol iddiası okunuyor
 *  (`send-push`in savunma derinliği deseni). */
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

interface Row {
  platform: "ios" | "android";
  original_txn_id: string;
  status: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("yontem", { status: 405 });
  }
  if (!isServiceRole(req.headers.get("Authorization"))) {
    console.error(`[${TAG}] 403: servis rolu degil`);
    return new Response("forbidden", { status: 403 });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !service) {
    console.error(`[${TAG}] SUPABASE_URL / SERVICE_ROLE_KEY yok`);
    return new Response("config", { status: 500 });
  }

  const apple = appleConfig();
  const google = googleConfig();
  if (!apple && !google) {
    // SESSİZ DEĞİL: sır girilmemişse iş yapılmıyor ama bu günlüğe yazılıyor.
    console.warn(`[${TAG}] magaza gizlileri yok — mutabakat ATLANDI`);
    return new Response("skipped", { status: 200 });
  }

  // OKUMA SERVİS ROLÜYLE: `subscriptions` politikasız ve hiçbir uygulama
  // rolüne açık değil. YAZMA yine `apply_subscription` (anon + sır) —
  // servis rolü istemcisi bu fonksiyonda yalnızca OKUYOR.
  const res = await fetch(
    `${url}/rest/v1/subscriptions` +
      `?select=platform,original_txn_id,status` +
      `&status=in.(trial,active,grace)`,
    { headers: { Authorization: `Bearer ${service}`, apikey: service } },
  );
  if (!res.ok) {
    console.error(`[${TAG}] defter okunamadi: ${res.status}`);
    return new Response("read", { status: 503 });
  }

  const rows = (await res.json()) as Row[];
  const nowSec = Math.floor(Date.now() / 1000);
  let checked = 0;
  let changed = 0;

  for (const row of rows) {
    try {
      let state = null;
      if (row.platform === "ios" && apple) {
        state = await appleSubscription(apple, row.original_txn_id, nowSec);
      } else if (row.platform === "android" && google) {
        state = await googleSubscription(google, row.original_txn_id, nowSec);
      } else {
        continue; // o platformun sırrı yok
      }
      checked++;

      // Mağaza makbuzu tanımıyorsa defteri kapat: iade/iptal sonrası temizlik.
      const next = state ?? {
        status: "expired" as const,
        productId: null,
        originalTxnId: row.original_txn_id,
        expiresAt: new Date().toISOString(),
        autoRenewing: false,
      };

      if (next.status === row.status && state) continue;

      await applySubscription({
        platform: row.platform,
        originalTxnId: next.originalTxnId,
        status: next.status,
        expiresAt: next.expiresAt,
        autoRenewing: next.autoRenewing,
        productId: next.productId ?? null,
      });
      changed++;
    } catch (e) {
      // TEK SATIR TÜM İŞİ DÜŞÜRMESİN: bir makbuzun API hatası diğerlerini
      // engellemiyor; yarın tekrar denenecek.
      console.error(`[${TAG}] ${row.platform}/${row.original_txn_id}: ${e}`);
    }
  }

  console.log(`[${TAG}] bakilan=${checked} duzeltilen=${changed}`);
  return new Response(JSON.stringify({ checked, changed }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
