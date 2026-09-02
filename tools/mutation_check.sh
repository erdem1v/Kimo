#!/usr/bin/env bash
# Mutasyon kontrolü — testlerin gerçekten AYIRT ETTİĞİNİ doğrular.
#
# NEDEN GEREKLİ: hem düzeltilmiş hem düzeltilmemiş şemada yeşil yanan bir test
# yalnızca "hata vermiyor"u kanıtlar, düzeltmeyi değil.
#
# ÜÇ FAZLI KONTROL (mutasyon başına):
#   1. YEŞİL   — mutasyondan ÖNCE test geçmeli. Bu faz YANLIŞ POZİTİFİ kapatıyor:
#                test zaten kırmızıysa onu "mutasyon yakalandı" saymak, aracın
#                doğrulamak için var olduğu şeyi yanlış raporlaması olurdu.
#   2. KIRMIZI — mutasyon uygulanınca test DÜŞMELİ. Düşmüyorsa o test o korumayı
#                ayırt etmiyor, yani ilgili bulgu için kanıt üretmiyor.
#   3. YEŞİL   — geri alma sonrası tekrar geçmeli; geri almanın çalıştığını
#                kanıtlıyor.
#
# GERİ ALMA NEDEN GÖÇ DOSYASI DEĞİL: ilk sürüm `-- restore:` ile bir göçü
# yeniden çalıştırıyordu. Bu iki şekilde yanlıştı — (a) 0026 sonradan eklenen
# kolonlar yüzünden artık yeniden çalıştırılamıyor, (b) çalışsaydı bile
# xp/streak grant'larını geri açar, yani C3'ü YENİDEN AÇARDI. Artık her
# mutasyon dosyası kendi geri almasını `-- @UNDO` bölümünde taşıyor.
#
# Kullanım (supabase start + db reset sonrası, herhangi bir dizinden):
#   bash tools/mutation_check.sh
#
# Ortam: SUPABASE_DB_URL verilmezse yerel varsayılan (config.toml [db] 54322).

set -uo pipefail

# Depo köküne sabitlen: başlıklardaki yollar köke göre.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
MUT_DIR="supabase/tests/mutations"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v psql >/dev/null 2>&1; then
  echo "HATA: psql bulunamadı. Ubuntu'da: sudo apt-get install -y postgresql-client" >&2
  exit 127
fi

LAST_OUT=""

# 0 = yeşil, 1 = kırmızı, 2 = test hiç çalışmadı (SQL hatası / boş çıktı)
run_test() {
  LAST_OUT="$(psql "$DB_URL" -q -t -A -f "$1" 2>&1)"
  if printf '%s\n' "$LAST_OUT" | grep -q '^not ok'; then return 1; fi
  if printf '%s\n' "$LAST_OUT" | grep -q '^# Looks like'; then return 1; fi
  # Hiç "ok" yoksa dosya çalışmamıştır; bunu yeşil saymak sessiz bir yalan olur.
  if ! printf '%s\n' "$LAST_OUT" | grep -q '^ok'; then return 2; fi
  return 0
}

apply_sql() { psql "$DB_URL" -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null 2>&1; }
show_tail()  { printf '%s\n' "$LAST_OUT" | tail -n 12 | sed 's/^/           | /'; }

pass=0
fail=0

for mut in "$MUT_DIR"/*.sql; do
  [ -e "$mut" ] || continue
  name="$(basename "$mut")"

  # Başlık: CR ve baştaki/sondaki boşluklar temizlenir (CRLF checkout'a dayanıklı).
  test_file="$(grep -m1 '^-- test:' "$mut" \
    | sed 's/^-- test:[[:space:]]*//' | tr -d '\r' | sed 's/[[:space:]]*$//')"

  if [ -z "$test_file" ] || [ ! -f "$test_file" ]; then
    echo "BAŞARISIZ $name — '-- test:' başlığı yok ya da dosya bulunamadı: ${test_file:-<boş>}"
    fail=$((fail + 1)); continue
  fi
  if ! grep -q '^-- @UNDO$' "$mut"; then
    echo "BAŞARISIZ $name — '-- @UNDO' bölümü yok; geri alma tanımsız"
    fail=$((fail + 1)); continue
  fi

  # Mutasyonu ve geri almayı ayrı dosyalara böl.
  awk '/^-- @UNDO$/{f=1;next} !f' "$mut" > "$TMP/do.sql"
  awk '/^-- @UNDO$/{f=1;next}  f' "$mut" > "$TMP/undo.sql"

  tname="$(basename "$test_file")"

  # ---------------------------------------------------------------- 1) YEŞİL
  run_test "$test_file"; rc=$?
  if [ $rc -eq 2 ]; then
    echo "BAŞARISIZ $name — FAZ 1: $tname hiç çalışmadı (SQL hatası?)"
    show_tail; fail=$((fail + 1)); continue
  fi
  if [ $rc -eq 1 ]; then
    echo "BAŞARISIZ $name — FAZ 1: $tname mutasyondan ÖNCE ZATEN KIRMIZI."
    echo "           Bu bir mutasyon bulgusu DEĞİL; test ya da fikstürü bozuk."
    show_tail; fail=$((fail + 1)); continue
  fi

  # -------------------------------------------------------------- 2) KIRMIZI
  if ! apply_sql "$TMP/do.sql"; then
    echo "BAŞARISIZ $name — FAZ 2: mutasyon uygulanamadı"
    fail=$((fail + 1)); continue
  fi
  run_test "$test_file"; rc=$?
  if [ $rc -eq 0 ]; then
    echo "BAŞARISIZ $name — FAZ 2: $tname HÂLÂ YEŞİL."
    echo "           Bu test o korumayı ayırt etmiyor; iddialarını gözden geçirin."
    fail=$((fail + 1))
  elif [ $rc -eq 2 ]; then
    echo "BAŞARISIZ $name — FAZ 2: $tname çalışmadı (mutasyon testi bozmuş olabilir)"
    show_tail; fail=$((fail + 1))
  else
    pass=$((pass + 1))
    echo "OK        $name — $tname mutasyonla kırmızıya döndü"
  fi

  # ------------------------------------------------------ 3) geri al + YEŞİL
  # Buradan sonrası başarısızsa DURUYORUZ: bozuk bir şemaya karşı çalışan
  # sonraki mutasyonların sonucu güvenilmez olur.
  if ! apply_sql "$TMP/undo.sql"; then
    echo "KRİTİK    $name — FAZ 3: geri alma çalıştırılamadı."
    echo "           Veritabanı BOZUK; 'supabase db reset' çalıştırın."
    exit 1
  fi
  run_test "$test_file"; rc=$?
  if [ $rc -ne 0 ]; then
    echo "KRİTİK    $name — FAZ 3: geri almadan SONRA $tname yeşile dönmedi."
    echo "           Geri alma eksik; sonraki sonuçlar güvenilmez olurdu."
    show_tail
    exit 1
  fi
done

echo
echo "Mutasyon kontrolü: $pass ayırt edildi, $fail sorun."
[ "$fail" -eq 0 ] || exit 1
