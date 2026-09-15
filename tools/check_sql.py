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
  5. `create or replace function` ile OUT sutun listesini (returns table)
     DEGISTIREN gocler. Postgres OUT parametrelerinin tanimladigi satir tipini
     degistirmeye HIC izin vermez — SONA sutun EKLEMEK de dahil:
     "cannot change return type of existing function / Row type defined by OUT
     parameters is different". Tek yol `drop function` + `create function`.
     Bu depoda dort kez yasandi (0014/0015, 0016/0024, ve Task 12'de
     `consume_ai_use` DOGRU cozulurken `ai_state` atlandi); 0083'un kendi
     yorumu kurali yaziyor: "yeni `call_id` sutunu ... `create or replace` ile
     YAPILAMIYOR".
  6. `create or replace view` ile sutun listesinin ORTASINA sutun ekleyen
     gocler. Ayni kural: yalnizca SONA ekleme serbest, aksi halde
     "cannot change name of view column" ile patlar (0081'de `received_questions`).
  7. BAYAT MUTASYON GERI ALMALARI. Bir mutasyonun `-- @UNDO` bolumu bir
     fonksiyon govdesi kopyaliyorsa, o govde ilgili gocteki CANLI govdeyle
     birebir ayni olmali. Degilse geri alma ESKI surumu geri kurar ve
     `mutation_check.sh` FAZ 3'te takilip `exit 1` ile TUM kosuyu durdurur —
     ya da daha kotusu, sessizce bir korumayi geri alir. Task 12'de
     `36_window_wrong_length` tam boyle bayatladi; Task 13'te `39` ve `40`
     ayni sekilde bayatladi.

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


def _balanced(src, i):
    """`i` acilis parantezinden SONRAKI indeks; kapanisa kadar icerigi dondur."""
    depth, buf = 1, []
    while depth and i < len(src):
        c = src[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                break
        buf.append(c)
        i += 1
    return ''.join(buf)


def _cols(body):
    """Virgulle ayrilmis bildirim listesinden ilk sozcukleri (ad) cikar."""
    body = re.sub(r'--[^\n]*', '', body)
    return [p.strip().split()[0] for p in body.split(',') if p.strip()]


def out_columns(src):
    """(fonksiyon adi, OUT sutunlari) — YALNIZCA arg listesinden hemen sonra
    `returns table` geliyorsa. Ileri arama yapilmiyor: yapilsaydi `returns
    boolean` olan bir fonksiyon bir SONRAKININ listesini kapardi."""
    found = []
    for m in re.finditer(
            r'create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(',
            src, re.I):
        i = m.end()
        depth = 1
        while depth and i < len(src):
            if src[i] == '(':
                depth += 1
            elif src[i] == ')':
                depth -= 1
            i += 1
        head = re.match(r'\s*returns\s+table\s*\(', src[i:i + 400], re.I)
        if not head:
            continue
        found.append((m.group(1), _cols(_balanced(src, i + head.end()))))
    return found


def view_columns(src):
    """(gorunum adi, `or replace` mi, sutun adlari)."""
    found = []
    for m in re.finditer(r'create\s+(or\s+replace\s+)?view\s+public\.(\w+)',
                         src, re.I):
        seg = src[m.end():]
        sel = seg.lower().find('select')
        frm = seg.lower().find('\nfrom ')
        if sel < 0 or frm < 0 or sel > frm:
            continue
        body = re.sub(r'--[^\n]*', '', seg[sel + 6:frm])
        cols, depth, cur = [], 0, ''
        for ch in body:
            if ch in '([':
                depth += 1
            elif ch in ')]':
                depth -= 1
            if ch == ',' and depth == 0:
                cols.append(cur.strip())
                cur = ''
            else:
                cur += ch
        if cur.strip():
            cols.append(cur.strip())
        names = []
        for c in cols:
            c = ' '.join(c.split())
            alias = re.search(r'\bas\s+(\w+)$', c, re.I)
            names.append(alias.group(1) if alias else c.split('.')[-1])
        found.append((m.group(2), bool(m.group(1)), names))
    return found


def _fn_bodies(text):
    """{ad: [normalize edilmis imza+govde, ...]} — yalnizca `$fn$` govdeliler."""
    out = {}
    for m in re.finditer(
            r'create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(',
            text, re.I):
        start = text.find('$fn$', m.end())
        if start < 0:
            continue
        end = text.find('$fn$', start + 4)
        if end < 0:
            continue
        chunk = text[m.start():start] + text[start:end + 4]
        chunk = re.sub(r'--[^\n]*', '', chunk)
        out.setdefault(m.group(1), []).append(re.sub(r'\s+', ' ', chunk).strip())
    return out


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

    # 5) OUT sutun listesini degistiren `create or replace function`
    # 6) sutun listesinin ORTASINA ekleyen `create or replace view`
    #
    # Ikisi de ayni Postgres kuralindan: yalnizca SONA ekleme serbest.
    # `drop function/view if exists` yazilmissa sorun yok.
    fn_hist, view_hist = {}, {}
    for path in files:
        src = io.open(path, encoding='utf-8').read()
        for name, cols in out_columns(src):
            prev = fn_hist.get(name)
            # SONA EKLEME DE GUVENLI DEGIL: Postgres OUT satir tipinin
            # degismesini hic kabul etmiyor. Tek istisna yok.
            if prev is not None and cols != prev:
                if not re.search(
                        r'drop\s+function\s+if\s+exists\s+public\.%s\b' % name,
                        src, re.I):
                    problems.append(
                        ('OUT SUTUN LISTESI DEGISTI, DROP YOK: %s '
                         '(create or replace bunu reddeder; drop + create yazin)'
                         % name, path))
            fn_hist[name] = cols
        for name, replace, cols in view_columns(src):
            prev = view_hist.get(name)
            if prev is not None and replace and cols[:len(prev)] != prev:
                problems.append(
                    ('GORUNUM SUTUNU ORTAYA EKLENDI: %s '
                     '(create or replace yalnizca SONA ekler; drop + create yazin)'
                     % name, path))
            view_hist[name] = cols

    # 7) bayat mutasyon geri almalari
    live_body = {}
    for path in files:
        src = io.open(path, encoding='utf-8').read()
        for name, bs in _fn_bodies(src).items():
            live_body[name] = (bs[-1], os.path.basename(path))

    mut_dir = 'supabase/mutations'
    if os.path.isdir(mut_dir):
        for name in sorted(os.listdir(mut_dir)):
            if not name.endswith('.sql'):
                continue
            mpath = os.path.join(mut_dir, name).replace(os.sep, '/')
            text = io.open(mpath, encoding='utf-8').read()
            marker = chr(10) + '-- @UNDO' + chr(10)
            if marker not in text:
                continue
            undo = text.split(marker, 1)[1]
            for fn, bs in _fn_bodies(undo).items():
                # Mutasyonun kendi urettigi yardimcilar (`__mut_*`) gocte yok.
                if fn.startswith('__mut') or fn not in live_body:
                    continue
                if bs[-1] != live_body[fn][0]:
                    problems.append(
                        ('BAYAT @UNDO: %s -> %s (canli govde %s; geri alma ESKI '
                         'surumu kuruyor)' % (name, fn, live_body[fn][1]), mpath))

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
