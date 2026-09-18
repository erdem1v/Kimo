// `deno test supabase/functions/_shared/auth_test.ts`
//
// AYIRT EDEN TEST: ilk iddia, anon anahtarının (role: "anon") servis rolü
// SAYILMADIĞINI sabitliyor — Task 18'de cleanup-anonymous'un açık kalmasına
// yol açan boşluk tam olarak bu ayrımın hiç yapılmamasıydı.

import { assertEquals } from "jsr:@std/assert@1";
import { isServiceRole } from "./auth.ts";

function jwt(payload: unknown): string {
  const b64 = (s: string) =>
    btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${b64('{"alg":"HS256","typ":"JWT"}')}.${b64(JSON.stringify(payload))}.imza`;
}

Deno.test("anon rolü servis rolü DEĞİL", () => {
  assertEquals(isServiceRole(`Bearer ${jwt({ role: "anon" })}`), false);
});

Deno.test("authenticated kullanıcı servis rolü değil", () => {
  assertEquals(
    isServiceRole(`Bearer ${jwt({ role: "authenticated", sub: "u1" })}`),
    false,
  );
});

Deno.test("service_role kabul", () => {
  assertEquals(isServiceRole(`Bearer ${jwt({ role: "service_role" })}`), true);
});

Deno.test("başlık yok / Bearer değil / bozuk jeton → false", () => {
  assertEquals(isServiceRole(null), false);
  assertEquals(isServiceRole("Basic abc"), false);
  assertEquals(isServiceRole("Bearer a.b"), false);
  assertEquals(isServiceRole("Bearer a.!!!.c"), false);
});
