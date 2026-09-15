// Abonelik defterine yazan TEK yol — `grant_ad_reward` (0076) deseninin
// aynısı.
//
// KORUNAN DEĞİŞMEZ: hiçbir edge fonksiyonu abonelik yazmak için SERVİS ROLÜ
// istemcisi kurmaz. Yazma yolu `anon`-çağrılabilir tek bir RPC ve paylaşılan
// bir sır:
//   sır sızarsa hasar : bedava abonelik.
//   anahtar sızarsa   : her satır + auth.admin.deleteUser.
//
// DÜRÜST KAYIT (ad-reward'dan devralınan): Supabase servis rolü anahtarını HER
// edge fonksiyonunun ortamına enjekte ediyor ve bu kapatılamıyor. "Anahtarı
// taşımıyor" ifadesi yalnızca "hiçbir kod yolu onu okumuyor" anlamında doğru.

export interface ApplyArgs {
  platform: "ios" | "android";
  originalTxnId: string;
  status: string;
  expiresAt: string | null;
  autoRenewing?: boolean | null;
  productId?: string | null;
  /** Satın alma akışında JWT'den çözülen kullanıcı; mağaza bildiriminde null
   *  (kullanıcı DEFTERDEN çözülüyor). */
  userId?: string | null;
  raw?: unknown;
}

/**
 * `false` dönebilir ve bu SESSİZ BİR HATA DEĞİL: sır yok, bilinmeyen makbuz
 * ya da eksik alan. Çağıran onu ayırt edip yanıt politikasına bağlıyor.
 * RPC'ye ULAŞILAMAZSA fırlatıyor — çağıran onu 503'e çeviriyor.
 */
export async function applySubscription(args: ApplyArgs): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const secret = Deno.env.get("IAP_SECRET");
  if (!url || !anon) {
    throw new Error("SUPABASE_URL / SUPABASE_ANON_KEY tanımlı değil");
  }
  // Sır yoksa RPC zaten reddeder (fail-closed); buradan da gitmiyoruz ki boş
  // bir sırla gereksiz bir tur atılmasın.
  if (!secret) throw new Error("IAP_SECRET tanımlı değil");

  const res = await fetch(`${url}/rest/v1/rpc/apply_subscription`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${anon}`,
      apikey: anon,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      p_secret: secret,
      p_platform: args.platform,
      p_original_txn: args.originalTxnId,
      p_status: args.status,
      p_expires_at: args.expiresAt,
      p_auto_renewing: args.autoRenewing ?? null,
      p_product: args.productId ?? null,
      p_user: args.userId ?? null,
      p_raw: args.raw ?? null,
    }),
  });
  if (!res.ok) {
    throw new Error(`apply_subscription ${res.status}: ${await res.text()}`);
  }
  return (await res.json()) === true;
}

/** Tek tip, ayrıntısız hata (deponun her edge fonksiyonunda aynı). */
export function deny(tag: string, status: number, logDetail: string): Response {
  console.error(`[${tag}] ${status}: ${logDetail}`);
  return new Response(JSON.stringify({ error: "gecersiz_istek" }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
