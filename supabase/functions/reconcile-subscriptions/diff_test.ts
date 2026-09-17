// `deno test supabase/functions/reconcile-subscriptions/diff_test.ts`
//
// AYIRT EDEN TEST: ilk iddia, düzeltmeden ÖNCEKİ kodla (yalnızca `status`
// karşılaştırması) kırmızıya döner. Gerisi kararın kenarları.

import { assertEquals } from "jsr:@std/assert@1";
import { needsWrite } from "./diff.ts";

const row = {
  status: "active",
  expires_at: "2026-10-15T12:00:00+00:00",
  auto_renewing: true,
  product_id: "kimo_plus_yearly",
};

Deno.test("YENİLEME yakalanıyor — durum aynı, bitiş ileri", () => {
  assertEquals(
    needsWrite(row, {
      status: "active",
      expiresAt: "2027-10-15T12:00:00.000Z",
      autoRenewing: true,
      productId: "kimo_plus_yearly",
    }),
    true,
  );
});

Deno.test("sapma yoksa yazma yok — biçim farkı sapma DEĞİL", () => {
  assertEquals(
    needsWrite(row, {
      status: "active",
      // Postgres `+00:00`, mağaza `.000Z` yazıyor: aynı an.
      expiresAt: "2026-10-15T12:00:00.000Z",
      autoRenewing: true,
      productId: "kimo_plus_yearly",
    }),
    false,
  );
});

Deno.test("iptal yakalanıyor — yalnızca auto_renewing değişti", () => {
  assertEquals(
    needsWrite(row, {
      status: "active",
      expiresAt: "2026-10-15T12:00:00Z",
      autoRenewing: false,
      productId: "kimo_plus_yearly",
    }),
    true,
  );
});

Deno.test("plan değişimi yakalanıyor — aylığa geçiş", () => {
  assertEquals(
    needsWrite(row, {
      status: "active",
      expiresAt: "2026-10-15T12:00:00Z",
      autoRenewing: true,
      productId: "kimo_plus_monthly",
    }),
    true,
  );
});

Deno.test("mağaza bilmiyorsa (null) defterdeki değer sapma sayılmıyor", () => {
  // `apply_subscription` bu alanları `coalesce` ile koruyor; boş bir yazma
  // turu atmanın anlamı yok.
  assertEquals(
    needsWrite(row, {
      status: "active",
      expiresAt: "2026-10-15T12:00:00Z",
      autoRenewing: null,
      productId: null,
    }),
    false,
  );
});

Deno.test("durum değişimi hâlâ yakalanıyor", () => {
  assertEquals(
    needsWrite(row, {
      status: "grace",
      expiresAt: "2026-10-15T12:00:00Z",
      autoRenewing: true,
      productId: "kimo_plus_yearly",
    }),
    true,
  );
});

Deno.test("defterde bitiş yokken mağaza tarih veriyorsa sapma", () => {
  assertEquals(
    needsWrite(
      { ...row, expires_at: null },
      {
        status: "active",
        expiresAt: "2026-10-15T12:00:00Z",
        autoRenewing: true,
        productId: "kimo_plus_yearly",
      },
    ),
    true,
  );
});
