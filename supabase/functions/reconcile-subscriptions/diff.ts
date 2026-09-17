// Mutabakatın TEK KARARI: mağazadan gelen durum defterdekinden farklı mı?
//
// Ayrı dosyada çünkü `Deno.serve` çağıran bir modül test edilemiyor ve bu
// karar sessizce yanlış olabilecek türden: yanlış "aynı" cevabı hiçbir yerde
// hata üretmiyor, yalnızca kullanıcı premium'unu kaybediyor.

export interface LedgerRow {
  status: string;
  expires_at: string | null;
  auto_renewing: boolean | null;
  product_id: string | null;
}

export interface StoreState {
  status: string;
  expiresAt: string | null;
  autoRenewing: boolean | null;
  productId: string | null;
}

/** İki damga aynı ANI mı gösteriyor? Biçimleri farklı olabilir:
 *  Postgres `2026-10-15T12:00:00+00:00`, mağaza `2026-10-15T12:00:00.000Z`. */
function sameInstant(a: string | null, b: string | null): boolean {
  if (a === null || b === null) return a === b;
  const x = Date.parse(a);
  const y = Date.parse(b);
  if (Number.isNaN(x) || Number.isNaN(y)) return a === b;
  return x === y;
}

/// Defter satırı mağazanın söylediğinden sapıyorsa `true`.
///
/// YENİLEME BURADAN GEÇİYOR (Task 17 · T17-6). Karar eskiden yalnızca
/// `status`a bakıyordu:
///
///     if (next.status === row.status && state) continue;
///
/// Bir YENİLEME durumu değiştirmiyor — `active` iken `active` kalıyor,
/// değişen tek şey `expires_at`. Yani mutabakat yenilemeyi her gece atlıyordu
/// ve `profiles.premium_until` (= `max(expires_at)`) eski tarihte donuyordu.
/// İşin varlık sebebi tam olarak buydu: "webhook hiç kurulmasa bile" doğru
/// kalmak. Webhook çalışırken görünmüyor, çalışmadığında ise ödeme yapan
/// kullanıcı premium'unu kaybediyordu.
///
/// `auto_renewing` ve `product_id` de karşılaştırılıyor: iptal (yenileme
/// kapatıldı) ve yükseltme/düşürme (aylık ↔ yıllık) de durumu değiştirmiyor.
export function needsWrite(row: LedgerRow, next: StoreState): boolean {
  if (row.status !== next.status) return true;
  if (!sameInstant(row.expires_at, next.expiresAt)) return true;
  // Mağaza bilgiyi vermiyorsa (null) defterdeki değer KORUNUYOR —
  // `apply_subscription` da `coalesce` ile aynı şeyi yapıyor.
  if (next.autoRenewing !== null && row.auto_renewing !== next.autoRenewing) {
    return true;
  }
  if (next.productId !== null && row.product_id !== next.productId) return true;
  return false;
}
