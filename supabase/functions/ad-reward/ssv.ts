// AdMob ödüllü reklam sunucu tarafı doğrulaması (SSV) — kriptografi.
//
// AYRI DOSYA OLMASININ SEBEBİ: aşağıdaki DER ayrıştırıcısı bu paketin en
// kırılgan parçası ve hataları ARALIKLI. Ayrı dosyada `deno test` ile bilinen
// vektörlere karşı sınanabiliyor (bkz. ssv_test.ts), handler'ı ayağa
// kaldırmadan.
//
// ÜÇ KODLAMA TUZAĞI, üçü de "reklam bazen çalışmıyor" gibi görünür:
//
//  1. DER → IEEE P1363. AdMob'un imzası base64url kodlu bir DER
//     `SEQUENCE { INTEGER r, INTEGER s }`; WebCrypto ECDSA ise ham 64 baytlık
//     `r‖s` bekliyor. Her INTEGER'da baştaki `0x00` işaret baytı ATILIP 32
//     bayta SOLA DOLDURULMALI. İki yön de oluyor: imzaların yaklaşık yarısında
//     bir bileşen 33 bayt (en yüksek bit 1 olduğu için işaret baytı eklenmiş),
//     yaklaşık 1/256'sında 32'den kısa. Tek dalı doğru yazmak callback'lerin
//     birkaç yüzdesini KALICI olarak düşürür.
//
//  2. İMZA HAM SORGU DİZESİ ÜZERİNDE. İmzalanan içerik, sorgunun ilk
//     parametreden `&signature=`'a kadarki kısmı — olduğu gibi, yeniden
//     kodlanmadan. `new URLSearchParams(...).toString()` yüzde-kodlamayı
//     normalleştirir ve doğrulamayı KESİN bozar.
//
//  3. ANAHTAR DÖNDÜRME. `key_id` AdMob'un sıralamasında `signature`dan SONRA
//     geliyor, yani imzalanan kısmın DIŞINDA; ayrıştırılmış parametrelerden
//     okunuyor. Bilinmeyen bir `key_id` yeniden çekmeyi tetikliyor ama
//     ALT SINIRLI: uydurma key_id gönderen biri gstatic'i bizim üzerinden
//     dövmesin.

/** Google'ın ECDSA doğrulayıcı anahtarları. */
export const VERIFIER_KEYS_URL =
  "https://gstatic.com/admob/reward/verifier-keys.json";

/** Anahtar önbelleği tazeliği. */
const KEY_TTL_MS = 6 * 60 * 60 * 1000;

/** Bilinmeyen key_id'de yeniden çekme arasındaki ALT SINIR. */
const KEY_REFETCH_FLOOR_MS = 5 * 60 * 1000;

/** Geri çağrının kabul edildiği azami yaş. */
export const MAX_AGE_MS = 60 * 60 * 1000;

interface RawKey {
  keyId: number | string;
  pem?: string;
  base64?: string;
}

/**
 * İmzalanan metin: sorgunun `&signature=` ÖNCESİNDE kalan kısmı.
 *
 * `search` hem `?a=1&b=2` hem `a=1&b=2` biçiminde verilebilir.
 * `signature` bulunamazsa `null` — imzasız bir geri çağrı reddedilmeli.
 */
export function signedPortion(search: string): string | null {
  const raw = search.startsWith("?") ? search.slice(1) : search;
  const idx = raw.indexOf("&signature=");
  // `idx === 0` da geçersiz: imzadan önce hiç parametre yoksa doğrulanacak
  // içerik yok demektir.
  if (idx <= 0) return null;
  return raw.slice(0, idx);
}

/** base64url (ve base64) → baytlar.
 *
 * DÖNÜŞ TİPİ `Uint8Array<ArrayBuffer>`, çıplak `Uint8Array` DEĞİL (Task 17):
 * TypeScript 5.7'den beri `Uint8Array` tampon tipinde jenerik ve çıplak biçim
 * `ArrayBufferLike`a çözülüyor; `crypto.subtle` ise `BufferSource` istiyor,
 * yani `SharedArrayBuffer` üzerine kurulu olmayan bir dizi. Bu dosya CI'da
 * HİÇ derlenmediği için (Deno testleri hiçbir yerde koşmuyordu) hata
 * görünmüyordu. */
export function b64urlToBytes(input: string): Uint8Array<ArrayBuffer> {
  const norm = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = norm + "=".repeat((4 - (norm.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Bir DER INTEGER gövdesini 32 baytlık alana sağa yaslar. */
function placeComponent(v: Uint8Array, out: Uint8Array, offset: number): void {
  // Baştaki işaret baytlarını at. `length - 1` sınırı bilinçli: değerin
  // kendisi 0 ise son baytı korumak gerekiyor.
  let start = 0;
  while (start < v.length - 1 && v[start] === 0x00) start++;
  const len = v.length - start;
  if (len > 32) throw new Error("DER: bileşen 32 bayttan uzun");
  // KISA bileşen de oluyor (~1/256): sola doldurma bu yüzden şart.
  out.set(v.subarray(start), offset + (32 - len));
}

/** DER `SEQUENCE { INTEGER r, INTEGER s }` → ham 64 baytlık `r‖s` (P-256). */
export function derToRaw(der: Uint8Array): Uint8Array<ArrayBuffer> {
  let i = 0;
  if (der[i++] !== 0x30) throw new Error("DER: SEQUENCE beklendi");

  let seqLen = der[i++];
  if (seqLen & 0x80) {
    const n = seqLen & 0x7f;
    if (n < 1 || n > 2) throw new Error("DER: desteklenmeyen uzunluk biçimi");
    seqLen = 0;
    for (let k = 0; k < n; k++) seqLen = (seqLen << 8) | der[i++];
  }
  if (i + seqLen !== der.length) {
    throw new Error("DER: SEQUENCE uzunluğu gövdeyle tutmuyor");
  }

  // Dilim `der`in tamponunu paylaşıyor, yani tipi `der`den geliyor: burada
  // çıplak `Uint8Array` DOĞRU. Dönüş (`out`) yeni bir tampon ve orada
  // `Uint8Array<ArrayBuffer>` gerekiyor.
  const readInt = (): Uint8Array => {
    if (der[i++] !== 0x02) throw new Error("DER: INTEGER beklendi");
    const len = der[i++];
    if (len & 0x80) throw new Error("DER: INTEGER uzun uzunluk biçimi");
    if (len === 0) throw new Error("DER: boş INTEGER");
    if (i + len > der.length) throw new Error("DER: INTEGER gövdeyi aşıyor");
    const v = der.subarray(i, i + len);
    i += len;
    return v;
  };

  const r = readInt();
  const s = readInt();
  if (i !== der.length) throw new Error("DER: artakalan bayt");

  const out = new Uint8Array(64);
  placeComponent(r, out, 0);
  placeComponent(s, out, 32);
  return out;
}

/** Anahtar önbelleği — modül kapsamında, isolate ömrü boyunca. */
export class KeyStore {
  private keys = new Map<string, CryptoKey>();
  private fetchedAt = 0;

  constructor(
    private readonly fetchJson: (url: string) => Promise<unknown> = defaultFetch,
    private readonly now: () => number = () => Date.now(),
  ) {}

  /** `key_id` için doğrulama anahtarı; bulunamazsa bir kez tazeler. */
  async get(keyId: string): Promise<CryptoKey | null> {
    const age = this.now() - this.fetchedAt;
    if (this.fetchedAt === 0 || age > KEY_TTL_MS) {
      await this.refresh();
    } else if (!this.keys.has(keyId) && age > KEY_REFETCH_FLOOR_MS) {
      // Anahtar döndürmüş olabilir. ALT SINIR olmadan, uydurma bir key_id
      // gönderen her istek bizi gstatic'e sürerdi.
      await this.refresh();
    }
    return this.keys.get(keyId) ?? null;
  }

  private async refresh(): Promise<void> {
    const body = await this.fetchJson(VERIFIER_KEYS_URL);
    const raw = (body as { keys?: RawKey[] })?.keys;
    if (!Array.isArray(raw)) throw new Error("doğrulayıcı anahtar listesi bozuk");

    const next = new Map<string, CryptoKey>();
    for (const k of raw) {
      const spki = k.base64 ?? pemToBase64(k.pem);
      if (!spki) continue;
      try {
        next.set(String(k.keyId), await importSpki(spki));
      } catch (e) {
        // Tek bozuk anahtar listeyi çöpe atmasın; diğerleri çalışsın.
        console.error(`[ad-reward] anahtar ${k.keyId} alınamadı: ${e}`);
      }
    }
    if (next.size === 0) throw new Error("hiç doğrulayıcı anahtar alınamadı");
    this.keys = next;
    this.fetchedAt = this.now();
  }
}

function pemToBase64(pem?: string): string | null {
  if (!pem) return null;
  return pem.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
}

async function importSpki(base64Spki: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "spki",
    b64urlToBytes(base64Spki),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
}

async function defaultFetch(url: string): Promise<unknown> {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`${url} → ${resp.status}`);
  return await resp.json();
}

/** İmzayı doğrular. Bozuk kodlama `false` döner, fırlatmaz. */
export async function verifySignature(
  signedText: string,
  signatureB64Url: string,
  key: CryptoKey,
): Promise<boolean> {
  let raw: Uint8Array<ArrayBuffer>;
  try {
    raw = derToRaw(b64urlToBytes(signatureB64Url));
  } catch (e) {
    console.error(`[ad-reward] imza kodlaması bozuk: ${e}`);
    return false;
  }
  return await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    raw,
    new TextEncoder().encode(signedText),
  );
}
