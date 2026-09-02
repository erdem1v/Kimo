"""Goc dosyalari icin ucuz yerel denetimler.

Bu makinede `psql` yok, `supabase db reset` calistirilamiyor. Bu betik SQL
ayristirmasi YAPMAZ ve dogrulama yerine gecmez; yalnizca toplu duzenlemeden
sonra en sik cikan ve en ucuz yakalanan hatalari gorunur kilar:

  1. Dolar-tirnak (`$fn$ ... $fn$`) dengesi.
  2. Ayrac dengesi (dolar-tirnak ve metin disinda).
  3. `function_grants_recheck` beyaz listesindeki her adin gercekten bir
     fonksiyon olarak yaratilmis olmasi. Bu kontrol onemli: liste bir ada
     sahipse ama fonksiyon yoksa, goc "beyaz listedeki fonksiyon cagrilamiyor"
     diye PATLAR ve tum `db reset` kirmiziya doner.
  4. `revoke execute` / `grant execute` yazilmamis yeni fonksiyonlar. Postgres
     yeni fonksiyonda EXECUTE'u PUBLIC'e verir; unutulan bir revoke sessiz bir
     acik birakir.

Kullanim:  python tools/check_sql.py
Cikis kodu 1 ise sorun bulunmustur.
"""

import io
import os
import re
import sys

MIGRATIONS = 'supabase/migrations'
TESTS = 'supabase/tests'

# pgTAP iddia fonksiyonlari. `plan(n)` bunlarin sayisiyla birebir olmali;
# tutmazsa suit "planned N but ran M" ile kirmizi doner ve hangi iddianin
# eksik oldugu gorunmez.
ASSERTIONS = (
    'ok', 'is', 'isnt', 'matches', 'imatches', 'doesnt_match',
    'lives_ok', 'throws_ok', 'throws_like', 'performs_ok',
    'is_empty', 'isnt_empty', 'results_eq', 'results_ne', 'set_eq', 'bag_eq',
    'has_table', 'hasnt_table', 'has_view', 'hasnt_view',
    'has_column', 'hasnt_column', 'col_is_null', 'col_not_null',
    'has_function', 'hasnt_function', 'has_index', 'has_pk', 'has_fk',
    'col_type_is', 'col_default_is', 'has_enum', 'has_schema', 'has_role',
    'function_returns', 'is_definer', 'isnt_definer',
)
SQ = chr(39)


def strip_literals(src):
    """Dolar-tirnakli govdeleri ve metinleri bosluga cevirir, uzunlugu korur."""
    out = list(src)
    n = len(src)
    i = 0

    def blank(a, b):
        for k in range(a, b):
            if out[k] != chr(10):
                out[k] = ' '

    while i < n:
        two = src[i:i + 2]
        if two == '--':
            j = src.find(chr(10), i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue
        if two == '/*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            blank(i, j)
            i = j
            continue
        if src[i] == SQ:
            j = i + 1
            while j < n:
                if src[j] == SQ:
                    if j + 1 < n and src[j + 1] == SQ:
                        j += 2
                        continue
                    j += 1
                    break
                j += 1
            blank(i, j)
            i = j
            continue
        if src[i] == '$':
            m = re.match(r'\$[A-Za-z_]?\w*\$', src[i:])
            if m:
                tag = m.group(0)
                j = src.find(tag, i + len(tag))
                if j < 0:
                    return ''.join(out), (tag, i)
                blank(i, j + len(tag))
                i = j + len(tag)
                continue
        i += 1
    return ''.join(out), None


def dollar_tags(src):
    """Dolar-tirnak etiketlerinin acik/kapali sayimi (yorum disinda)."""
    # Yorumlari temizle ama dolar-tirnaklara dokunma.
    text = re.sub(r'--[^\n]*', '', src)
    tags = re.findall(r'\$[A-Za-z_]?\w*\$', text)
    counts = {}
    for t in tags:
        counts[t] = counts.get(t, 0) + 1
    return {t: c for t, c in counts.items() if c % 2 != 0}


def plan_problems():
    """pgTAP dosyalarinda `plan(n)` ile gercek iddia sayisini karsilastirir."""
    found = []
    if not os.path.isdir(TESTS):
        return found
    for name in sorted(os.listdir(TESTS)):
        if not name.endswith('.sql'):
            continue
        path = (TESTS + '/' + name)
        src = io.open(path, encoding='utf-8').read()
        code = strip_literals(src)[0]
        m = re.search(r'select\s+plan\s*\(\s*(\d+)\s*\)', code, re.I)
        if not m:
            continue
        planned = int(m.group(1))
        pattern = r'^\s*select\s+(%s)\s*\(' % '|'.join(ASSERTIONS)
        actual = len(re.findall(pattern, code, re.I | re.M))
        if planned != actual:
            found.append(('PLAN UYUSMUYOR: plan(%d) ama %d iddia' % (planned, actual), path))
    return found


def main():
    problems = plan_problems()
    files = sorted(
        os.path.join(MIGRATIONS, f).replace(os.sep, '/')
        for f in os.listdir(MIGRATIONS) if f.endswith('.sql')
    )

    created = set()
    created_in = {}          # fonksiyon adi -> ilk yaratildigi goc dosyasi
    whitelisted = {}
    execute_managed = set()

    for path in files:
        src = io.open(path, encoding='utf-8').read()

        odd = dollar_tags(src)
        if odd:
            problems.append(('DOLAR-TIRNAK TEK SAYI %s' % sorted(odd), path))

        stripped, unterminated = strip_literals(src)
        if unterminated:
            problems.append(('KAPANMAMIS DOLAR-TIRNAK %s @%d' % unterminated, path))
            continue

        for opener, closer, label in (('(', ')', 'parantez'), ('[', ']', 'koseli')):
            delta = stripped.count(opener) - stripped.count(closer)
            if delta:
                problems.append(('DENGESIZ %s %+d' % (label, delta), path))

        # Yaratilan ve yetkisi yonetilen fonksiyonlar
        # Tetikleyici fonksiyonlar EXECUTE yetkisi gerektirmez (tetikleyici
        # olarak calisirlar); onlari 4. kontrolun disinda tutuyoruz.
        for m in re.finditer(
                r'create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)'
                r'\s*\([^)]*\)\s*returns\s+(\w+)',
                src, re.I | re.S):
            name, ret = m.group(1), m.group(2).lower()
            if ret != 'trigger':
                created.add(name)
                created_in.setdefault(name, path)
        for m in re.finditer(
                r'(?:revoke|grant)\s+execute\s+on\s+function\s+public\.(\w+)',
                src, re.I):
            execute_managed.add(m.group(1))

        # Beyaz liste (yalnizca en son recheck dosyasi gecerli)
        if 'v_keep text[] := array[' in src:
            block = src.split('v_keep text[] := array[', 1)[1].split('];', 1)[0]
            whitelisted[path] = set(re.findall(r"'(\w+)'", block))

    # 3) beyaz listedeki her ad yaratilmis mi?
    if whitelisted:
        last = sorted(whitelisted)[-1]
        missing = sorted(whitelisted[last] - created)
        if missing:
            problems.append(
                ('BEYAZ LISTEDE OLUP YARATILMAYAN FONKSIYON: %s' % missing, last))

    # 3b) SON kapidan SONRA yaratilmis cagirilabilir fonksiyonlar
    #
    # Kapi (`v_keep`) yalnizca kendi calisma anindaki fonksiyonlari suepueruer:
    # daha sonraki bir gocte yaratilan fonksiyon "yeni fonksiyon PUBLIC'e acik
    # dogar" kuralindan HIC gecmez. Bu tam olarak `dismiss_received_question`
    # ile yasandi; goc elle one alinarak duzeltildi. Kontrol o yuzden burada.
    if whitelisted:
        gate = sorted(whitelisted)[-1]
        late = sorted(
            name for name, where in created_in.items()
            if where > gate and name in execute_managed
        )
        if late:
            problems.append(
                ('KAPIDAN SONRA YARATILAN FONKSIYON: %s '
                 '(kapiyi gecmiyor; gocu kapidan ONCEYE alin ya da yeni bir '
                 'kapi yazin)' % late, gate))

    # 4) yetkisi hic yonetilmemis fonksiyonlar
    unmanaged = sorted(created - execute_managed)
    if unmanaged:
        problems.append(
            ('EXECUTE YETKISI YAZILMAMIS: %s' % unmanaged,
             '(son recheck gocu bunlari kapatir; yine de acikca yazilmali)'))

    for what, where in problems:
        print('%-58s %s' % (what, where))
    print()
    print('goc dosyasi: %d | sorun: %d' % (len(files), len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
