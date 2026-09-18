// Ağ geçidinin `verify_jwt = true` ayarı YETERLİ DEĞİL (Task 18 bulgusu).
//
// Geçit yalnızca "projenin sırrıyla imzalanmış geçerli bir JWT var mı" diye
// bakıyor — ve HERKESE AÇIK anon anahtarı da böyle bir JWT. Yani `apikey`
// başlığıyla yapılan JWT'siz bir istek geçitten geçiyor. Yalnızca pg_cron'un
// (servis rolü jetonuyla) çağırması gereken `cleanup-anonymous` böylece
// anon anahtarı olan HERKES tarafından, gövdedeki `days` ile 1 güne kadar
// indirilerek tetiklenebiliyordu: kurulumu bitirmemiş anonim kullanıcıların
// hesapları ve fotoğrafları. `send-push` ve `reconcile-subscriptions` bu
// kontrolü zaten taşıyordu; üçü artık tek kopyayı paylaşıyor.
//
// Ağ geçidi imzayı doğruladı; burada yalnızca rol iddiası okunuyor. İmzasız
// bir jetonun buraya ULAŞAMAMASI geçidin işi, rolün ne olduğu bizim.

/** `Authorization: Bearer <jwt>` başlığındaki rol `service_role` mü? */
export function isServiceRole(authHeader: string | null): boolean {
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
