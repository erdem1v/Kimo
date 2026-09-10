// Tek soru silme (A-9).
//
// Kullanıcı arşivinden bir soruyu kalıcı olarak siler. Yanlış eklenen ya da
// özel bilgi içeren bir fotoğraf için tek çıkış yolu bugüne kadar TÜM HESABI
// silmekti.
//
// NEDEN EDGE FUNCTION, NEDEN RPC DEĞİL: silme İKİ nesneye dokunuyor — satır ve
// depodaki dosya. SQL'den `storage.objects`'i silmek YETMEZ: metadata satırı
// gider, arkadaki nesne nesne deposunda kalır. Depo bunu zaten biliyor —
// moderasyon temizliği bu yüzden kuyruk + Storage API kalıbı kullanıyor
// (0031). Gerçek silme yalnızca Storage API üzerinden olur.
//
// `mistake_id` gövdeden gelir ama SAHİPLİK JWT'den doğrulanır: servis rolüyle
// çalışan bu fonksiyon aksi hâlde herkesin her soruyu silmesine izin veren bir
// primitif olurdu (delete-account'ın aynı gerekçesi).
//
// SIRA: önce nesne, sonra satır. Satır önce gitseydi `photo_path`'i
// kaybederdik ve dosya sessizce yetim kalırdı (all_questions_screen.dart'taki
// yönetici silmesinin aynı gerekçesi). Ters yönde kalan risk — nesne gitti,
// satır kalmadı — kullanıcıya görünür hata olarak dönüyor ve ikinci deneme
// satırı siliyor; silme işlemi yeniden çalıştırılabilir.
//
// İstemcinin doğrudan DELETE yolu 0069'da kapatıldı; tek kapı burası.
//
// Deploy: supabase functions deploy delete-question

import { createClient } from "jsr:@supabase/supabase-js@2";

const BUCKET = "mistake-photos";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function deny(status: number, logDetail: string): Response {
  console.error(`[delete-question] ${status}: ${logDetail}`);
  return json({ error: "silinemedi" }, status);
}

Deno.serve(async (req: Request) => {
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

    const body = await req.json().catch(() => ({}));
    const mistakeId = body?.mistakeId;
    if (typeof mistakeId !== "string" || mistakeId.length === 0) {
      return deny(400, "mistakeId gerekli");
    }

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

    // 1) Satırı sahiplikle birlikte oku. `maybeSingle` yok: sahibi olmayan bir
    //    kimlik için "bulunamadı" ile "senin değil" AYNI yanıt olmalı, yoksa
    //    uç nokta "bu kimlik var mı" sorusuna cevap veren bir kâhine dönüşür.
    const { data: row, error: selError } = await admin
      .from("mistakes")
      .select("id, photo_path")
      .eq("id", mistakeId)
      .eq("user_id", uid)
      .limit(1);
    if (selError) return deny(500, `satır okunamadı: ${selError.message}`);
    if (!row || row.length === 0) return deny(404, "satır yok ya da sahibi değil");

    const photoPath = row[0].photo_path as string | null;

    // 2) Depo nesnesi. Yoksa `remove` hata vermiyor; bu iyi — yükleme yarıda
    //    kalmış bir satır da silinebilmeli.
    if (photoPath) {
      const { error: rmError } = await admin.storage
        .from(BUCKET)
        .remove([photoPath]);
      if (rmError) {
        return deny(500, `fotoğraf silinemedi: ${rmError.message}`);
      }
    }

    // 3) Satır. Buraya YALNIZCA nesne gerçekten silindiyse geliniyor.
    //    `user_id` koşulu ikinci kez yazılıyor: servis rolü RLS'i atlıyor ve
    //    bu koşul tek koruma.
    const { error: delError } = await admin
      .from("mistakes")
      .delete()
      .eq("id", mistakeId)
      .eq("user_id", uid);
    if (delError) return deny(500, `satır silinemedi: ${delError.message}`);

    // question_sends.mistake_id cascade ile gidiyor (0048 kapısı);
    // photo_violations.mistake_id `on delete set null` — ihlal sayacı KASTEN
    // ayakta kalıyor (0062), yoksa kullanıcı sorusunu silerek sicilini
    // temizleyebilirdi.
    console.log(`[delete-question] silindi (fotoğraf: ${photoPath !== null})`);
    return json({ ok: true, photo_removed: photoPath !== null }, 200);
  } catch (e) {
    return deny(500, String(e));
  }
});
