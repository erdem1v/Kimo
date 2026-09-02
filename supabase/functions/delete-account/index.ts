// Hesap silme — KVKK Md. 7 / GDPR Md. 17.
//
// `uid` GÖVDEDEN DEĞİL JWT'DEN okunuyor. Gövdeden alsaydık servis rolüyle
// çalışan bu fonksiyon herkesin herkesi silmesine izin veren bir primitif
// olurdu. `verify_jwt = true`, yani geçersiz jeton bu koda hiç ulaşmıyor;
// buradaki `getUser` çağrısı jetondaki kullanıcıyı ÇÖZÜYOR.
//
// SIRA ÖNEMLİ:
//   1. `<uid>/` önekindeki depolama nesneleri listelenip silinir
//      (önce mistake-photos, sonra avatars; sayfalı).
//   2. YALNIZCA hepsi silindiyse `auth.admin.deleteUser(uid)` çağrılır.
//   3. Cascade gerisini alır (0048 göçü her FK'nin cascade olduğunu doğruluyor).
//
// Depolama adımı kısmen başarısız olursa **işlem DURUR ve kullanıcıya görünür
// hata döner**. Sessizce "silindi" demek, silinmemiş fotoğrafları silinmiş
// göstermek olurdu — Task 01'in aynı gerekçesi.
//
// Bu depodaki TEK servis rolü yüzeyi burasıdır.
//
// Deploy: supabase functions deploy delete-account

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Silinecek kovalar. Sıra önemli değil; ikisi de tamamen boşalmalı. */
const BUCKETS = ["mistake-photos", "avatars"] as const;

/** Tek listeleme sayfası. Supabase üst sınırı 100. */
const PAGE = 100;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function deny(status: number, logDetail: string): Response {
  console.error(`[delete-account] ${status}: ${logDetail}`);
  return json({ error: "silinemedi" }, status);
}

/**
 * Bir kovadaki `<uid>/` klasörünü boşaltır.
 *
 * Kaç nesne silindiğini döndürür; silinemeyen kalırsa HATA FIRLATIR.
 */
async function purgeFolder(
  // deno-lint-ignore no-explicit-any
  admin: any,
  bucket: string,
  uid: string,
): Promise<number> {
  let removed = 0;
  // Sayfalı: `limit` kadar listele, sil, tekrar listele. Offset KULLANMIYORUZ
  // çünkü silme listeyi kaydırıyor; her turda baştan listelemek doğru olan.
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

    // Sayfa dolmadıysa klasör bitti.
    if (data.length < PAGE) {
      const { data: rest } = await admin.storage
        .from(bucket)
        .list(uid, { limit: 1 });
      if (!rest || rest.length === 0) return removed;
    }
  }
  throw new Error(`${bucket} boşaltılamadı: 1000 turdan sonra hâlâ nesne var`);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return deny(405, `yöntem: ${req.method}`);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!url || !serviceKey || !anonKey) {
      return deny(500, "SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY tanımlı değil");
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return deny(401, "Authorization başlığı yok");

    // Kimliği ÇAĞIRANIN jetonundan çöz. Ağ geçidi jetonu zaten doğruladı;
    // buradaki çağrı `uid`'i öğrenmek için.
    const caller = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: userData, error: userError } = await caller.auth.getUser();
    const uid = userData?.user?.id;
    if (userError || !uid) return deny(401, `kullanıcı çözülemedi: ${userError}`);

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    // 1) Depolama.
    let removed = 0;
    for (const bucket of BUCKETS) {
      removed += await purgeFolder(admin, bucket, uid);
    }

    // 2) Hesap. Buraya YALNIZCA depolama tamamen boşaldıysa geliniyor:
    // purgeFolder hata fırlatırsa aşağıdaki satır hiç çalışmıyor.
    const { error: delError } = await admin.auth.admin.deleteUser(uid);
    if (delError) {
      return deny(500, `auth kullanıcısı silinemedi: ${delError.message}`);
    }

    // 3) Cascade gerisini aldı. İZ BIRAKILMIYOR: hash'lenmiş bir
    // `deleted_accounts` kaydı tutmak da bir tür kalıcı iz olurdu ve
    // "gerçekten silme" kararıyla çelişirdi.
    console.log(`[delete-account] uid silindi, ${removed} nesne kaldırıldı`);
    return json({ ok: true, objects_removed: removed }, 200);
  } catch (e) {
    // Depolama yarıda kaldıysa buraya düşüyoruz ve hesap SİLİNMİYOR.
    // Kullanıcı hatayı görüyor ve tekrar deneyebiliyor; ikinci deneme kalan
    // nesneleri siler (silme işlemi yeniden çalıştırılabilir).
    return deny(500, String(e));
  }
});
