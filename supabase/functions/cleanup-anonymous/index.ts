// Süresi dolmuş anonim hesapların temizliği.
//
// NEDEN GEREKLİ: kayıt akışın sonunda; "İlk yanlışını çek" deyip vazgeçen her
// kullanıcı geride bir anonim hesap bırakıyor. Bu hesaplar Supabase MAU'suna
// SAYILIYOR, yani temizlenmezlerse doğrudan faturaya yazılıyorlar. Ayrıca
// depolamada yüklenmiş fotoğrafları olabiliyor.
//
// NE ZAMAN: `p_days` (varsayılan 7) günden eski anonim hesaplar. Yedi gün,
// "telefonu bir hafta açmadım" durumunu koruyacak kadar uzun.
//
// KİM ÇAĞIRIYOR: zamanlanmış bir iş. `verify_jwt = true`, çağıran servis rolü
// jetonuyla imzalıyor — yani uç nokta kimliksiz açık DEĞİL.
//
// DİKKAT — DEPODA HENÜZ ZAMANLAYICI YOK. `pg_cron` ya da Supabase Scheduled
// Functions kurulumu bu depoda bulunmuyor; bu fonksiyon yazıldı ama onu
// düzenli çağıran bir şey yok. Elle ya da dış bir zamanlayıcıyla çağrılana
// kadar temizlik YAPILMIYOR. (Raporda açık madde olarak duruyor.)
//
// SIRA: `delete-account` ile aynı — önce depolama, sonra hesap. Kısmi başarı
// durumunda o kullanıcı ATLANIYOR ve sonraki turda yeniden denenecek; tek bir
// takılan hesap bütün temizliği durdurmuyor.
//
// Deploy: supabase functions deploy cleanup-anonymous

import { createClient } from "jsr:@supabase/supabase-js@2";

const BUCKETS = ["mistake-photos", "avatars"] as const;
const PAGE = 100;

/** Tek turda en fazla kaç hesap. Fonksiyon süre sınırına takılmasın. */
const MAX_PER_RUN = 200;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function purgeFolder(
  // deno-lint-ignore no-explicit-any
  admin: any,
  bucket: string,
  uid: string,
): Promise<number> {
  let removed = 0;
  for (let guard = 0; guard < 1000; guard++) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(uid, { limit: PAGE });
    if (error) throw new Error(`${bucket} listelenemedi: ${error.message}`);
    if (!data || data.length === 0) return removed;

    const paths = data.map((o: { name: string }) => `${uid}/${o.name}`);
    const { error: rmError } = await admin.storage.from(bucket).remove(paths);
    if (rmError) throw new Error(`${bucket} silinemedi: ${rmError.message}`);
    removed += paths.length;

    if (data.length < PAGE) {
      const { data: rest } = await admin.storage
        .from(bucket)
        .list(uid, { limit: 1 });
      if (!rest || rest.length === 0) return removed;
    }
  }
  throw new Error(`${bucket} boşaltılamadı`);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "gecersiz_istek" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    console.error("[cleanup-anonymous] SUPABASE_URL / SERVICE_ROLE_KEY yok");
    return json({ error: "gecersiz_istek" }, 500);
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false },
  });

  let days = 7;
  try {
    const body = await req.json();
    const raw = Number(body?.days);
    if (Number.isFinite(raw) && raw >= 1 && raw <= 90) days = Math.floor(raw);
  } catch (_) {
    // Gövde yok ya da bozuk: varsayılan 7 gün.
  }

  const { data: rows, error } = await admin.rpc("stale_anonymous_users", {
    p_days: days,
  });
  if (error) {
    console.error(`[cleanup-anonymous] liste alınamadı: ${error.message}`);
    return json({ error: "gecersiz_istek" }, 500);
  }

  const ids: string[] = (rows ?? [])
    .map((r: { user_id: string }) => r.user_id)
    .slice(0, MAX_PER_RUN);

  let deleted = 0;
  let objects = 0;
  const skipped: string[] = [];

  for (const uid of ids) {
    try {
      for (const bucket of BUCKETS) {
        objects += await purgeFolder(admin, bucket, uid);
      }
      const { error: delError } = await admin.auth.admin.deleteUser(uid);
      if (delError) throw new Error(delError.message);
      deleted++;
    } catch (e) {
      // Tek bir takılan hesap turu durdurmuyor; sonraki turda yeniden denenir.
      console.error(`[cleanup-anonymous] atlandı: ${e}`);
      skipped.push(uid);
    }
  }

  console.log(
    `[cleanup-anonymous] aday=${ids.length} silindi=${deleted} ` +
      `nesne=${objects} atlanan=${skipped.length}`,
  );
  return json({
    candidates: ids.length,
    deleted,
    objects_removed: objects,
    skipped: skipped.length,
  });
});
