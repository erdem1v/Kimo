"""GitHub Actions is akisi dosyalarinin AYRISTIRILABILIR oldugunu dogrular.

NEDEN VAR: `.github/workflows/ci.yml` Task 10'un `5feeb02` commit'inde
gecersiz YAML haline geldi ve KIMSE FARK ETMEDI.

    - name: "Sinirsiz" vaadi kullaniciya verilmemis mi

YAML'de cift tirnakla BASLAYAN bir skalerden sonra duz metin gelemez. Bozuk
bir is akisi dosyasi GitHub Actions tarafindan hic kosulmaz — yani pgTAP
suiti, mutasyon kontrolu, statik kapilar ve `flutter analyze/test` Task 10'dan
Task 13'e kadar HIC KOSMADI. Task 12'nin yedi kirik noktasinin (biri
`supabase db reset`i patlatan bir goc) fark edilmeden commit'e hazir hale
gelmesinin sebebi de budur.

BU KONTROL NEDEN CI'DA DEGIL DE ONCE YERELDE: bozuk bir ci.yml, kendi
icindeki kontrolu de kosturamaz. Tavuk-yumurta. Bu yuzden betik YEREL geri
bildirim yolu olarak yazildi (`check_symbols.py` / `check_imports.py` ile ayni
gerekce: bu makinede Flutter yok) ve ci.yml'in static isine de EKLENDI —
ikincisi yalnizca dosya ZATEN gecerliyken bir sonraki bozulmayi yakalar.

Kullanim:  python3 tools/check_workflows.py [--selftest]
Cikis kodu 1 ise sorun bulunmustur.
"""

import io
import os
import re
import sys

WORKFLOWS = '.github/workflows'

# Tirnakla baslayip tirnaktan SONRA metin devam eden skaler. PyYAML yoksa
# kullanilan yedek desen; yakaladigi sinif tam olarak yasanan hata.
BAD_SCALAR = re.compile(
    r'^\s*(?:-\s*)?[\w-]+:\s*'          # anahtar
    r'(?P<q>["\'])'                      # acilis tirnagi
    r'(?:(?!(?P=q)).)*'                  # tirnak ici
    r'(?P=q)'                            # kapanis tirnagi
    r'\s*\S'                             # ...ve ARDINDAN metin: gecersiz
)


def files():
    if not os.path.isdir(WORKFLOWS):
        return []
    return sorted(
        os.path.join(WORKFLOWS, f).replace(os.sep, '/')
        for f in os.listdir(WORKFLOWS)
        if f.endswith(('.yml', '.yaml'))
    )


def check_text(text):
    """(satir_no, satir) listesi — yedek desenle bulunan sorunlar."""
    out = []
    for i, line in enumerate(text.split(chr(10)), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if BAD_SCALAR.match(line):
            out.append((i, stripped))
    return out


def check_file(path):
    text = io.open(path, encoding='utf-8').read()
    try:
        import yaml
    except ImportError:
        return [('YEDEK DESEN (PyYAML yok) satir %d: %s' % (n, s[:60]), path)
                for n, s in check_text(text)]

    try:
        yaml.safe_load(text)
    except Exception as exc:                      # noqa: BLE001
        mark = getattr(exc, 'problem_mark', None)
        where = ('satir %d' % (mark.line + 1)) if mark else 'yer belirsiz'
        return [('AYRISTIRILAMIYOR (%s) — GitHub bu is akisini HIC KOSTURMAZ'
                 % where, path)]
    # Ayristirilabiliyor olmak yetmiyor: bos ya da `jobs` tasimayan bir dosya
    # da sessizce hicbir sey kosturmaz.
    data = yaml.safe_load(text)
    if not isinstance(data, dict) or not data.get('jobs'):
        return [('`jobs` yok — dosya hicbir sey kosturmuyor', path)]
    return []


def selftest():
    """Kapinin kendi sinamasi: uydurma bir ihlali yakalamali.

    Bu depoda bir denetleyicinin SESSIZCE hicbir sey bulmama hatasina iki kez
    dusuldugu icin (check_symbols'un dusen `\\b`'si, check_imports'un 0x08
    kazasi) her kapi kendini siniyor.
    """
    broken = 'jobs:\n  a:\n    steps:\n      - name: "Sinirsiz" vaadi kullaniciya\n'
    problems = check_text(broken)
    if not problems:
        print('selftest BASARISIZ: uydurma ihlal yakalanmadi')
        return 1
    try:
        import yaml
        try:
            yaml.safe_load(broken)
            print('selftest BASARISIZ: PyYAML bozuk dosyayi kabul etti')
            return 1
        except Exception:                          # noqa: BLE001
            pass
    except ImportError:
        pass
    good = 'jobs:\n  a:\n    steps:\n      - name: duz baslik\n'
    if check_text(good):
        print('selftest BASARISIZ: gecerli dosyada yanlis alarm')
        return 1
    print('selftest: bozuk is akisi yakalandi, gecerli olan temiz')
    return 0


def main():
    if '--selftest' in sys.argv:
        return selftest()
    problems = []
    paths = files()
    for path in paths:
        problems.extend(check_file(path))
    for what, where in problems:
        print('%-70s %s' % (what, where))
    print()
    print('is akisi: %d | sorun: %d' % (len(paths), len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
