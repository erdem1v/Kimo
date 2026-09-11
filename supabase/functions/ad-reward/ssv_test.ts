// `deno test supabase/functions/ad-reward/ssv_test.ts`
//
// Burada sınanan şey kriptografi değil KODLAMA: DER ayrıştırıcısı bu paketin
// en kırılgan parçası ve hataları aralıklı — imzaların yaklaşık yarısında bir
// bileşen 33 bayt, yaklaşık 1/256'sında 32'den kısa. Tek dalı doğru yazmak
// callback'lerin birkaç yüzdesini kalıcı olarak düşürür ve bu hiçbir yerde
// hata olarak görünmez.

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { b64urlToBytes, derToRaw, signedPortion } from "./ssv.ts";

function der(r: number[], s: number[]): Uint8Array {
  const body = [0x02, r.length, ...r, 0x02, s.length, ...s];
  return new Uint8Array([0x30, body.length, ...body]);
}

Deno.test("r ve s tam 32 bayt", () => {
  const r = new Array(32).fill(0x11);
  const s = new Array(32).fill(0x22);
  const out = derToRaw(der(r, s));
  assertEquals(out.length, 64);
  assertEquals(out[0], 0x11);
  assertEquals(out[32], 0x22);
});

Deno.test("33 baytlik r — bastaki 0x00 isaret bayti atiliyor", () => {
  // En yüksek bit 1 olduğu için DER bir 0x00 ekler. Atılmazsa 65 bayt olur
  // ve WebCrypto imzayı reddeder.
  const r = [0x00, 0xff, ...new Array(31).fill(0xaa)];
  const s = new Array(32).fill(0x01);
  const out = derToRaw(der(r, s));
  assertEquals(out.length, 64);
  assertEquals(out[0], 0xff);
  assertEquals(out[1], 0xaa);
  assertEquals(out[32], 0x01);
});

Deno.test("31 baytlik s — sola dolduruluyor", () => {
  // Kısa bileşen (~1/256). Sola doldurulmazsa s yanlış konumdan okunur.
  const r = new Array(32).fill(0x05);
  const s = new Array(31).fill(0x07);
  const out = derToRaw(der(r, s));
  assertEquals(out.length, 64);
  assertEquals(out[32], 0x00, "ilk bayt sifir dolgu olmali");
  assertEquals(out[33], 0x07);
  assertEquals(out[63], 0x07);
});

Deno.test("ikisi de kisa", () => {
  const out = derToRaw(der(new Array(30).fill(0x09), new Array(20).fill(0x08)));
  assertEquals(out.length, 64);
  assertEquals(out[0], 0x00);
  assertEquals(out[1], 0x00);
  assertEquals(out[2], 0x09);
  assertEquals(out[32 + 11], 0x00);
  assertEquals(out[32 + 12], 0x08);
});

Deno.test("degeri sifir olan bilesen son bayti koruyor", () => {
  const out = derToRaw(der([0x00], new Array(32).fill(0x03)));
  assertEquals(out.length, 64);
  assertEquals(out[31], 0x00);
});

Deno.test("bozuk DER firlatiyor — sessizce gecmiyor", () => {
  assertThrows(() => derToRaw(new Uint8Array([0x31, 0x02, 0x02, 0x00])));
  assertThrows(() => derToRaw(new Uint8Array([0x30, 0x02, 0x03, 0x00])));
  // 33 bayttan uzun bileşen P-256 için geçersiz.
  assertThrows(() => derToRaw(der(new Array(34).fill(0x01), new Array(32).fill(1))));
  // Artakalan bayt.
  const d = der(new Array(32).fill(1), new Array(32).fill(2));
  assertThrows(() => derToRaw(new Uint8Array([...d, 0x00])));
});

Deno.test("signedPortion imzadan ONCEKI ham diziyi veriyor", () => {
  assertEquals(
    signedPortion("?ad_network=5450213213286189855&ad_unit=123&signature=AB&key_id=7"),
    "ad_network=5450213213286189855&ad_unit=123",
  );
  // Soru işareti olmadan da çalışıyor.
  assertEquals(signedPortion("a=1&b=2&signature=X&key_id=1"), "a=1&b=2");
  // Yüzde kodlaması OLDUĞU GİBİ kalıyor: yeniden kodlamak imzayı bozar.
  assertEquals(
    signedPortion("custom_data=a%2Bb&signature=X&key_id=1"),
    "custom_data=a%2Bb",
  );
});

Deno.test("signedPortion imzasiz ya da bas imzali girdide null", () => {
  assertEquals(signedPortion("?a=1&b=2"), null);
  assertEquals(signedPortion(""), null);
  assertEquals(signedPortion("?signature=X&key_id=1"), null);
});

Deno.test("b64urlToBytes hem base64url hem base64 okuyor", () => {
  assertEquals([...b64urlToBytes("AQID")], [1, 2, 3]);
  assertEquals([...b64urlToBytes("-_8")], [251, 255]);
  assertEquals([...b64urlToBytes("+/8=")], [251, 255]);
});
