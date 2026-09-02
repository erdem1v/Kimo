#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tasarım token'ları ve kit sembolleri için statik doğrulama.

Bu depoda Flutter SDK yok; `flutter analyze` yalnızca CI'da koşuyor. Bir CI
turu dakikalar sürdüğü için, derleyicinin yakalayacağı en sık hata sınıfını
(var olmayan bir token/ikon/enum değerine başvurmak) burada yakalıyoruz.

Kapsam bilerek DAR: yalnızca "bilinen sınıf → bilinen üye listesi" biçimindeki
statik erişimler. Tip çıkarımı yapmıyor, bu yüzden yanlış alarm üretmiyor;
yakalayamadıklarını CI yakalıyor.

Kendi kendini sınar: `--selftest` ile çalıştırıldığında uydurma bir sembolü
gerçekten yakaladığını doğrular. (Bu dosyanın ilk sürümü sessizce hiçbir şey
bulmuyordu — regex'teki `\\b` bir yazım kazasıyla düşmüştü ve "sorun: 0" boş
bir güvence veriyordu.)

Kullanım:  python tools/check_symbols.py [--selftest]
Çıkış kodu: sorun varsa 1.
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = ('_archive', 'generated')

FIELD = r'\bfinal\s+[\w<>?, ]+\s+(\w+)\s*;'
CONST = r'\bstatic\s+const\s+[\w<>?, ]+\s+(\w+)\s*='
STATIC_ANY = r'\bstatic\s+(?:const\s+|final\s+)?[\w<>?, ]+\s+(\w+)\s*[=(]'


def read(rel):
    with io.open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        return f.read()


def dart_files():
    for base, dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if name.endswith('.dart'):
                path = os.path.join(base, name)
                yield os.path.relpath(path, ROOT).replace('\\', '/')


def strip_comments(src):
    """Yorum ve dizgileri boşaltır; içlerindeki `Gap.foo` sayılmasın."""
    out = []
    i, n = 0, len(src)
    while i < n:
        ch = src[i]
        two = src[i:i + 2]
        if two == '//':
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif two == '/*':
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
        elif ch in '"\'':
            quote = src[i:i + 3] if src[i:i + 3] in ('"""', "'''") else ch
            i += len(quote)
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src.startswith(quote, i):
                    i += len(quote)
                    break
                i += 1
        else:
            out.append(ch)
            i += 1
    return ''.join(out)


def members(rel, class_name, pattern):
    """Bir sınıfın gövdesindeki üyeleri toplar."""
    src = read(rel)
    m = re.search(r'\bclass\s+%s\b' % re.escape(class_name), src)
    if not m:
        sys.exit('BULUNAMADI: %s içinde class %s' % (rel, class_name))
    body = src[m.end():]
    nxt = re.search(r'\n(?:class|enum|extension|mixin)\s', body)
    if nxt:
        body = body[:nxt.start()]
    return set(re.findall(pattern, body))


def enum_values(rel, enum_name):
    """Enum değerleri + gövdesindeki statik üyeler (League.promotionCount)."""
    src = read(rel)
    m = re.search(r'\benum\s+%s\s*\{' % re.escape(enum_name), src)
    if not m:
        sys.exit('BULUNAMADI: %s içinde enum %s' % (rel, enum_name))
    depth, i = 1, m.end()
    while i < len(src) and depth:
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
        i += 1
    body = strip_comments(src[m.end():i - 1])
    head, _, tail = body.partition(';')
    out = set()
    for part in head.split(','):
        part = part.strip()
        w = re.match(r'^([a-z][A-Za-z0-9]*)\s*(?:\(|$)', part)
        if w:
            out.add(w.group(1))
    out |= set(re.findall(STATIC_ANY, tail))
    return out


CATALOGUE = {
    # Erişim öneki -> (izin verilen üyeler, kaynak açıklaması)
    'Gap': (members('lib/theme/tokens.dart', 'Gap', CONST), 'theme/tokens.dart'),
    'Radii': (members('lib/theme/tokens.dart', 'Radii', STATIC_ANY),
              'theme/tokens.dart'),
    'Sizes': (members('lib/theme/tokens.dart', 'Sizes', CONST),
              'theme/tokens.dart'),
    'Motion': (members('lib/theme/tokens.dart', 'Motion', CONST),
               'theme/tokens.dart'),
    'KimoIcons': (members('lib/widgets/kit/kimo_icons.dart', 'KimoIcons',
                          STATIC_ANY), 'widgets/kit/kimo_icons.dart'),
    'BadgeTone': (enum_values('lib/widgets/kit/kimo_chips.dart', 'BadgeTone'),
                  'widgets/kit/kimo_chips.dart'),
    'KimoButtonKind': (enum_values('lib/widgets/kit/kimo_button.dart',
                                   'KimoButtonKind'),
                       'widgets/kit/kimo_button.dart'),
    'KimoReaction': (enum_values('lib/widgets/kimo/kimo_pose.dart',
                                 'KimoReaction'), 'widgets/kimo/kimo_pose.dart'),
    'KimoMood': (enum_values('lib/widgets/kimo/kimo_pose.dart', 'KimoMood'),
                 'widgets/kimo/kimo_pose.dart'),
    'MistakeType': (enum_values('lib/models/models.dart', 'MistakeType'),
                    'models/models.dart'),
    'League': (enum_values('lib/models/social.dart', 'League'),
               'models/social.dart'),
}

# `context.c` (KimoColors) ve `context.t` (KimoTypography) üyeleri.
COLOR_FIELDS = members('lib/theme/tokens.dart', 'KimoColors', FIELD)
TYPE_FIELDS = members('lib/theme/typography.dart', 'KimoTypography', FIELD)

# Enum/sınıf üzerinden okunan, değer olmayan üyeler.
EXTRA = {
    'KimoIcons': {'all'},
    'MistakeType': {'values', 'choices', 'fromDb'},
    'League': {'values', 'fromDb'},
    'KimoReaction': {'values'},
    'KimoMood': {'values'},
    'BadgeTone': {'values'},
    'KimoButtonKind': {'values'},
    'Radii': {'all'},
}


def scan(rel, src):
    """Bir dosyadaki bilinmeyen sembol erişimlerini döndürür."""
    found = []
    src = strip_comments(src)

    for prefix, (allowed, origin) in CATALOGUE.items():
        ok = allowed | EXTRA.get(prefix, set())
        # `[A-Za-z]` ile başlıyor: `Gap._` gibi özel kurucular atlanıyor.
        for m in re.finditer(r'\b' + re.escape(prefix) + r'\.([A-Za-z]\w*)', src):
            name = m.group(1)
            if name not in ok:
                line = src.count('\n', 0, m.start()) + 1
                found.append('%s:%d  %s.%s yok (%s)'
                             % (rel, line, prefix, name, origin))

    # KimoColors/KimoTypography: yalnızca yerel değişken adı `c`/`t` ise.
    for var, fields, label, decl in (
        ('c', COLOR_FIELDS, 'KimoColors', r'\bKimoColors\s+c\s*='),
        ('t', TYPE_FIELDS, 'KimoTypography', r'\bKimoTypography\s+t\s*='),
    ):
        if not re.search(decl, src):
            continue
        for m in re.finditer(r'(?<![\w.])' + var + r'\.([a-zA-Z]\w*)', src):
            name = m.group(1)
            if name in fields or name in ('copyWith', 'lerp', 'type'):
                continue
            line = src.count('\n', 0, m.start()) + 1
            found.append('%s:%d  %s.%s yok (%s)' % (rel, line, var, name, label))

    return found


def selftest():
    """Denetleyicinin gerçekten bir şey yakaladığını kanıtlar."""
    sample = '\n'.join([
        'Widget build(BuildContext context) {',
        '  final KimoColors c = context.c;',
        '  final KimoTypography t = context.t;',
        '  return Padding(',
        '    padding: const EdgeInsets.all(Gap.uydurmaBosluk),',
        '    child: StatusBadge(tone: BadgeTone.olmayanTon,',
        '      label: "x", color: c.olmayanRenk, style: t.olmayanStil),',
        '  );',
        '}',
    ])
    hits = scan('<selftest>', sample)
    beklenen = ['Gap.uydurmaBosluk', 'BadgeTone.olmayanTon',
                'c.olmayanRenk', 't.olmayanStil']
    eksik = [b for b in beklenen if not any(b in h for h in hits)]
    for h in hits:
        print('  ' + h)
    if eksik:
        print('SELFTEST BAŞARISIZ — yakalanmayan: %s' % ', '.join(eksik))
        return 1
    print('selftest: %d uydurma sembolün hepsi yakalandı' % len(beklenen))
    return 0


def main():
    if '--selftest' in sys.argv:
        return selftest()
    problems = []
    for rel in sorted(dart_files()):
        problems += scan(rel, read(rel))
    for p in problems:
        print(p)
    print('sorun: %d' % len(problems))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
