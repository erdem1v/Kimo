"""Dart kaynagi icin ucuz yerel denetimler: import hijyeni + ayrac dengesi.

Neden var: bu makinede Dart SDK yok, `flutter analyze` calistirilamiyor ve
`unused_import` CI'da isi kirmizaya dondurur. Bu betik analiz yerine GECMEZ;
yalnizca en sik ve en ucuz yakalanabilir iki hatayi (kullanilmayan import,
var olmayan dosyaya import) yerelde gorunur kilar.

Metin ve yorumlar gercek bir sozcuk tarayicisiyla ayikliyor: duz regex ile
yapildiginda `$` iceren metinler dosyanin buyuk bolumunu yutup bildirimleri
kaybediyor ve tarayici sessizce yanlis sonuc uretiyordu.

Kullanim:  python tools/check_imports.py
Cikis kodu 1 ise sorun bulunmustur.
"""

import io
import os
import re
import sys

PACKAGE = 'ai_yks_coach'
ROOTS = ('lib', 'test')
SKIP_DIR_MARKER = '_archive'


def slash(path):
    return path.replace(os.sep, '/')


SQ = chr(39)
BSL = chr(92)


def strip_strings_and_comments(src):
    """Metin sabitlerini ve yorumlari bosluga cevirir, uzunlugu korur.

    Metin ARASINA gomulu ifadeler (`${...}`) KORUNUR: orasi gercek kod ve
    yalnizca orada kullanilan bir ad varsa import gercekten gereklidir.

    Ic ice tirnaklari saymak sart. `'... ${x ? "a" : "b" + SQ + "c"} ...'` gibi bir
    satirda naif tarayici dis metni erken kapatiyor, ardindan kalan dosyayi
    yanlis ayristirip yuzlerce satiri yutuyordu — tarama da sessizce
    "hicbir sorun yok" diyordu.
    """
    out = list(src)
    n = len(src)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != chr(10):
                out[k] = ' '

    def skip_comment(i):
        two = src[i:i + 2]
        if two == '//':
            j = src.find(chr(10), i)
            return n if j < 0 else j
        if two == '/*':
            j = src.find('*/', i + 2)
            return n if j < 0 else j + 2
        return -1

    def skip_string(i):
        raw = i > 0 and src[i - 1] == 'r'
        triple = src[i:i + 3]
        quote = triple if triple in ('"""', SQ * 3) else src[i]
        j = i + len(quote)
        blank(i, j)
        while j < n:
            ch = src[j]
            if not raw and ch == BSL:
                blank(j, min(j + 2, n))
                j += 2
                continue
            if src[j:j + len(quote)] == quote:
                blank(j, j + len(quote))
                return j + len(quote)
            if not raw and ch == '$' and j + 1 < n and src[j + 1] == '{':
                blank(j, j + 2)
                j = skip_braces(j + 1)   # icerideki kod OLDUGU GIBI kalir
                # Acilis `${` silindiyse kapanis `}` da silinmeli; yoksa
                # parantez denge sayimi her interpolasyonda bir eksiliyor.
                blank(j - 1, j)
                continue
            blank(j, j + 1)
            j += 1
        return n

    def skip_braces(i):
        depth = 0
        j = i
        while j < n:
            ch = src[j]
            if ch == '{':
                depth += 1
                j += 1
                continue
            if ch == '}':
                depth -= 1
                j += 1
                if depth == 0:
                    return j
                continue
            end_c = skip_comment(j)
            if end_c >= 0:
                blank(j, end_c)
                j = end_c
                continue
            if ch in '"' + SQ:
                j = skip_string(j)
                continue
            j += 1
        return n

    i = 0
    while i < n:
        end_c = skip_comment(i)
        if end_c >= 0:
            blank(i, end_c)
            i = end_c
            continue
        if src[i] in '"' + SQ:
            i = skip_string(i)
            continue
        i += 1
    return ''.join(out)


# Bildirimler SUTUN 0'da baslar. Satir bazli bakmak sart: cok satirli bir
# regex, girintili bir metot imzasini ust satirdaki bir sozcuge baglayip
# `build`, `title`, `pick` gibi UYE adlarini "ust duzey" sanabiliyor. O da her
# widget dosyasini "kullanilmis" gosterip taramayi degersizlestiriyordu.
DECL = re.compile(
    r'^(?:abstract |final |sealed |base |interface |mixin )*'
    r'(?:class|enum|mixin|extension|typedef)[ 	]+([A-Za-z_]\w*)')
TOPVAR = re.compile(r'^(?:final|const|late final)[ 	]+[^=;]*?([A-Za-z_]\w*)[ 	]*=')
TOPFN = re.compile(r'^[A-Za-z_][\w<>,\[\]? 	]*[ 	]([A-Za-z_]\w*)[ 	]*\(')
EXTENSION = re.compile(r'^extension\b')


def declared_names(code):
    """Yalnizca sutun 0'daki ust duzey bildirimler."""
    names = set()
    for line in code.split(chr(10)):
        if not line or line[0].isspace():
            continue
        for pattern in (DECL, TOPVAR, TOPFN):
            found = pattern.match(line)
            if found:
                names.add(found.group(1))
                break
    return names


def declares_extension(code):
    return any(EXTENSION.match(line) for line in code.split(chr(10)))


def dart_files():
    found = []
    for base in ROOTS:
        for folder, _dirs, files in os.walk(base):
            if SKIP_DIR_MARKER in slash(folder):
                continue
            for name in files:
                if name.endswith('.dart'):
                    found.append(slash(os.path.join(folder, name)))
    return sorted(found)


_names = {}
_extension_files = set()


def exported_names(path):
    if path not in _names:
        try:
            code = strip_strings_and_comments(io.open(path, encoding='utf-8').read())
        except OSError:
            code = ''
        if declares_extension(code):
            # Uzanti UYELERI (ornegin `context.c`) ada bakilarak bulunamiyor.
            # Yanlis pozitif uretip gerekli bir importu sildirmektense bu
            # dosyalarin importunu hic sorgulamiyoruz.
            _extension_files.add(path)
        names = declared_names(code)
        # `export` ile yeniden yayilan adlari da say.
        for target in re.findall(r"^export\s+'([^']+)'", code, re.M):
            child = slash(os.path.normpath(os.path.join(os.path.dirname(path), target)))
            if os.path.exists(child) and child != path:
                names |= exported_names(child)
        _names[path] = names
    return _names[path]


def resolve(importer, uri):
    if uri.startswith('package:%s/' % PACKAGE):
        return 'lib/' + uri[len('package:%s/' % PACKAGE):]
    if uri.startswith('package:') or uri.startswith('dart:'):
        return None
    return slash(os.path.normpath(os.path.join(os.path.dirname(importer), uri)))


def balance_problems():
    """Ayrac dengesi. Toplu metin duzenlemesinden sonra en ucuz bozulma
    gostergesi: bir govde yanlis yerden kesilirse burada gorulur."""
    found = []
    for path in dart_files():
        code = strip_strings_and_comments(io.open(path, encoding='utf-8').read())
        for opener, closer, label in (('{', '}', 'suslu'),
                                      ('(', ')', 'parantez'),
                                      ('[', ']', 'koseli')):
            delta = code.count(opener) - code.count(closer)
            if delta:
                found.append(('DENGESIZ %s %+d' % (label, delta), path, ''))
    return found


def selftest():
    """Denetleyicinin kendi duzenli ifadeleri calisiyor mu.

    NEDEN VAR: bu depoda AYNI hata iki kez oldu. Bir kabuk here-doc'u Python
    kaynagindaki ters egik cizgiyi yiyip yerine bir kontrol karakteri koydu;
    `r'^extension\b'` sessizce `'^extension\\x08'` oldu ve uzanti dosyalarini
    taniyan kod aylarca (goruntude "sorun: 0" diyerek) hicbir sey yapmadi.
    Sessizce hicbir sey yapmayan bir denetleyici, denetleyicinin hic olmamasindan
    kotudur.
    """
    failures = []

    def check(label, ok):
        if not ok:
            failures.append(label)

    check('EXTENSION uzanti bildirimini taniyor',
          bool(EXTENSION.match('extension KimoColorsX on BuildContext {')))
    check('EXTENSION benzer bir adi yanlislikla saymiyor',
          not EXTENSION.match('extensionOfThing x = 1;'))
    m = DECL.match('class Foo {')
    check('DECL sinif adini yakaliyor', bool(m) and m.group(1) == 'Foo')
    m2 = DECL.match('extension Bar on Baz {')
    check('DECL uzanti adini yakaliyor', bool(m2) and m2.group(1) == 'Bar')
    check('strip_strings_and_comments dizgiyi bosaltiyor',
          "'Gap.md'" not in strip_strings_and_comments("var a = 'Gap.md';"))

    # Bozulma sinifinin kendisi: kaynakta kacis karakteri yerine gecmis
    # kontrol karakteri var mi.
    tools_dir = os.path.dirname(os.path.abspath(__file__))
    for name in sorted(os.listdir(tools_dir)):
        if not name.endswith('.py'):
            continue
        text = io.open(os.path.join(tools_dir, name), encoding='utf-8').read()
        bad = {ord(ch) for ch in text
               if ord(ch) < 32 and ord(ch) not in (9, 10, 13)}
        check('%s icinde kontrol karakteri yok (%s)'
              % (name, sorted(hex(b) for b in bad)), not bad)

    for f in failures:
        print('SELFTEST BASARISIZ: %s' % f)
    if not failures:
        print('selftest: tum ic kontroller gecti')
    return 1 if failures else 0


def main():
    if '--selftest' in sys.argv:
        return selftest()
    problems = balance_problems()
    for path in dart_files():
        src = io.open(path, encoding='utf-8').read()
        code = strip_strings_and_comments(src)
        # Yonergeler HAM kaynaktan okunuyor: temizleyici tirnak icini de
        # bosluga cevirdigi icin import URI'si stripped metinde kalmiyordu ve
        # tarama sessizce hicbir sey bulmuyordu.
        directives = list(re.finditer(r"^import\s+'([^']+)'([^;]*);", src, re.M))
        for match in directives:
            uri, tail = match.group(1), match.group(2)
            target = resolve(path, uri)
            if target is None:
                continue
            if not os.path.exists(target):
                # gen_l10n ciktisi `flutter pub get` sirasinda uretiliyor.
                if '/generated/' not in target:
                    problems.append(('EKSIK DOSYA', path, uri))
                continue
            names = exported_names(target)
            if not names or target in _extension_files:
                continue
            alias = re.search(r'\bas\s+(\w+)', tail)
            if alias:
                names = {alias.group(1)}
            # Import satirlarinin kendisi "kullanim" sayilmasin.
            body = re.sub(r"^import\s+'[^']*'[^;]*;", '', code, flags=re.M)
            if not any(re.search(r'\b%s\b' % re.escape(n), body) for n in names):
                problems.append(('KULLANILMAYAN', path, uri))

    for kind, path, uri in problems:
        print('%-14s %-52s -> %s' % (kind, path, uri))
    print()
    print('sorun: %d' % len(problems))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
