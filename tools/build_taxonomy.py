# -*- coding: utf-8 -*-
"""Konu agacinin TEK KAYNAGINDAN uretilen ciktilari yazar.

Kaynak:  taxonomy/yks-konulari.md   (insan duzenler)
Cikti:   supabase/migrations/20260907000200_curriculum_seed.sql   (veritabani)
         assets/curriculum/tree.json                              (istemci yedegi)

NEDEN VAR: agac Task 09'a kadar YEDI yerde duruyordu (taxonomy.ts,
yks_curriculum.dart, yks_subjects.dart, import_meb.dart, mistake_style.dart,
remap_konu.sql, manifests) ve hicbiri digerini dogrulamiyordu. Senkronu garanti
eden tek sey bir yorum satiriydi. Artik tek kaynak bu dosya; kopyalar ondan
turuyor ve `--check` sapmayi CI'da kirmizi yakiyor.

Kullanim:
    python3 tools/build_taxonomy.py            # ciktilari yaz
    python3 tools/build_taxonomy.py --check    # yeniden uret, diski karsilastir
    python3 tools/build_taxonomy.py --selftest # dogrulayicinin kendi sinamasi

`--selftest` ZORUNLU bir aliskanlik: bu depoda bir denetleyici (check_symbols)
bir kez sessizce hicbir sey bulmama hatasina dustu ve "sorun: 0" bos bir
guvence verdi. Uretici de ayni tuzaga acik.
"""

import hashlib
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = 'taxonomy/yks-konulari.md'
SEED = 'supabase/migrations/20260907000200_curriculum_seed.sql'
ASSET = 'assets/curriculum/tree.json'
STYLE = 'lib/widgets/mistake_style.dart'

CURRICULA = ('eski', 'maarif')
EXAMS = ('TYT', 'AYT')


class SourceError(Exception):
    """Kaynak dosya kurallari ihlal ediyor."""


# Turkce duyarli normalizasyon. SQL'deki `public.tr_norm` ve Dart'taki
# `trNorm` ile AYNI sonucu vermek ZORUNDA:
#   • SQL  : etiket cozumlemesi (alias_norm birincil anahtarin parcasi)
#   • Dart : istemci aramasi ("atislar" -> "Atislar")
#   • burasi: tohum uretilirken cakisma denetimi
# Ucu ayrisirsa tohum INSERT'i birincil anahtarda patlar ya da — daha kotusu —
# kullanicinin yazdigi kelime sunucunun bulduguyla eslesmez.
_TR_FROM = 'ÇĞİÖŞÜÂÎÛçğıöşüâîû'
_TR_TO = 'CGIOSUAIUcgiosuaiu'
_TR_MAP = {ord(a): b for a, b in zip(_TR_FROM, _TR_TO)}


def tr_norm(value):
    return ' '.join(value.translate(_TR_MAP).lower().split())


# --------------------------------------------------------------------- okuma
def read(rel):
    with io.open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        return f.read()


def parse(text):
    """Markdown -> [(curriculum, exam, subject, unit, topic, aliases)] duz liste.

    `aliases` = [(kind, alias, src_exam|None)].

    Ayristirici KATI: tanimadigi bir baslik seviyesi ya da yeri gelmemis bir
    madde sessizce atlanmaz, hata olur. Sessiz atlama en kotu sonucu verir —
    agactan bir ders duser ve bunu ancak konu secemeyen kullanici fark eder.
    """
    marker = '<!-- AGAC BASLANGICI -->'
    if marker not in text:
        raise SourceError('kaynak dosyada %s isareti yok' % marker)
    head, text = text.split(marker, 1)
    offset = head.count('\n') + 1

    rows = []
    cur = exam = subject = unit = None
    in_fence = False
    for no, raw in enumerate(text.split('\n'), offset + 1):
        line = raw.rstrip()
        if line.startswith('```'):
            in_fence = not in_fence
            continue
        if in_fence or not line.strip():
            continue

        if line.startswith('##### '):
            if subject is None:
                raise SourceError('%d: unite once ders ister' % no)
            unit = line[6:].strip()
            if not unit:
                raise SourceError('%d: bos unite adi' % no)
        elif line.startswith('#### '):
            if exam is None:
                raise SourceError('%d: ders once sinav ister' % no)
            subject, unit = line[5:].strip(), None
        elif line.startswith('### '):
            if cur is None:
                raise SourceError('%d: sinav once mufredat ister' % no)
            exam = line[4:].strip()
            if exam not in EXAMS:
                raise SourceError('%d: bilinmeyen sinav %r' % (no, exam))
            subject = unit = None
        elif line.startswith('## '):
            cur = line[3:].strip()
            if cur not in CURRICULA:
                raise SourceError('%d: bilinmeyen mufredat %r' % (no, cur))
            exam = subject = unit = None
        elif line.startswith('- '):
            if unit is None:
                # Baslik bolumundeki aciklama maddeleri: mufredat baslamadan
                # gelen her madde metindir, veri degil.
                if cur is None:
                    continue
                raise SourceError('%d: konu once unite ister' % no)
            rows.append((cur, exam, subject, unit) + _topic(line[2:], no))
        elif line.startswith('#'):
            if cur is not None:
                raise SourceError('%d: tanimsiz baslik seviyesi: %r' % (no, line[:40]))
    if not rows:
        raise SourceError('kaynak dosyada hic konu yok')
    return rows


def _topic(body, no):
    """`Konu | ara: a, b | eski: c, TYT/d` -> (topic, [(kind, alias, src)])."""
    parts = [p.strip() for p in body.split('|')]
    topic = parts[0]
    if not topic:
        raise SourceError('%d: bos konu adi' % no)
    aliases = []
    for part in parts[1:]:
        if part.startswith('ara:'):
            kind, rest = 'ara', part[4:]
        elif part.startswith('eski:'):
            kind, rest = 'eski', part[5:]
        else:
            raise SourceError('%d: tanimsiz alan %r (ara: / eski: bekleniyor)'
                              % (no, part[:20]))
        for item in rest.split(','):
            item = item.strip()
            if not item:
                continue
            src = None
            if kind == 'eski':
                m = re.match(r'^(TYT|AYT)/(.+)$', item)
                if m:
                    src, item = m.group(1), m.group(2).strip()
            aliases.append((kind, item, src))
    return topic, aliases


# ----------------------------------------------------------------- dogrulama
def validate(rows, subject_colors):
    """Kaynak dosyanin bes kuralini zorlar. Ihlal listesi doner."""
    bad = []
    topics = {}        # (cur,exam,subj) -> {topic}
    aliases = {}       # (cur,exam,subj) -> {alias: topic}
    units = {}         # (cur,exam,subj,unit) -> adet
    subjects = set()

    for cur, exam, subj, unit, topic, als in rows:
        scope = (cur, exam, subj)
        subjects.add(subj)
        units[(cur, exam, subj, unit)] = units.get((cur, exam, subj, unit), 0) + 1
        # 1) yinelenen konu
        if topic in topics.setdefault(scope, set()):
            bad.append('yinelenen konu: %s/%s/%s "%s"' % (cur, exam, subj, topic))
        topics[scope].add(topic)

    for cur, exam, subj, unit, topic, als in rows:
        scope = (cur, exam, subj)
        for kind, alias, src in als:
            # 2) etiket BASKA bir konunun adiyla cakisamaz.
            #
            # Kendi konusunun adiyla ayni olmasi sorun DEGIL, hatta gerekli:
            # `Maddenin Hâlleri | eski: Maddenin Halleri` (sapkasiz eski yazim)
            # normalize edildiginde ayni cikiyor ama remap'i o satir uretiyor.
            # Kurali "hicbir konu adiyla cakisamaz" diye yazmak o remap'i
            # sildirirdi ve eski kayitlar gecersiz konuda kalirdi.
            clash = [t for t in topics[scope]
                     if tr_norm(t) == tr_norm(alias) and t != topic]
            if clash:
                bad.append('etiket BASKA konunun adiyla cakisiyor: %s/%s/%s "%s" -> %s'
                           % (cur, exam, subj, alias, clash[0]))
            # 3) bir etiket iki konuya isaret edemez
            # ANAHTAR NORMALIZE EDILMIS BICIM: veritabaninda birincil anahtar
            # `alias_norm`. "Ivme" ile "ivme" ayni satiri hedefler; burada
            # yakalanmazsa tohum INSERT'i uretimde patlardi.
            key = tr_norm(alias)
            if not key:
                bad.append('bos etiket: %s/%s/%s "%s"' % (cur, exam, subj, topic))
                continue
            prev = aliases.setdefault(scope, {}).get(key)
            if prev is not None and prev[1] != topic:
                bad.append('etiket iki konuya isaret ediyor: %s/%s/%s "%s"/"%s" -> %s, %s'
                           % (cur, exam, subj, prev[0], alias, prev[1], topic))
            aliases[scope][key] = (alias, topic)

    # 4) her dersin bir rengi olmali
    for s in sorted(subjects):
        if s not in subject_colors:
            bad.append('ders rengi tanimsiz (%s): "%s"' % (STYLE, s))

    # 5) bos unite
    for key, n in units.items():
        if n == 0:
            bad.append('bos unite: %s/%s/%s/%s' % key)
    return bad


def subject_colors():
    """`mistake_style.dart` icindeki ders -> renk tablosunun anahtarlari."""
    src = read(STYLE)
    m = re.search(r'_subjectColors\s*=\s*<String,\s*Color>\{(.*?)\};', src, re.S)
    if not m:
        raise SourceError('%s icinde _subjectColors bulunamadi' % STYLE)
    return set(re.findall(r"'([^']+)'\s*:", m.group(1)))


# ------------------------------------------------------------------- surum
def canonical(rows):
    """Surumun uzerinde hesaplandigi kanonik serilestirme.

    Surum ICERIKTEN turuyor: uretici hesapladigi icin surum ile agac
    AYRISAMAZ. Elle yazilan bir surum numarasi, guncellenmesi unutuldugunda
    sessizce yanlis olurdu ve tam da onu engellemek icin var.
    """
    out = []
    for cur, exam, subj, unit, topic, als in rows:
        labels = ';'.join(sorted('%s:%s:%s' % (k, a, s or '') for k, a, s in als))
        out.append('|'.join((cur, exam, subj, unit, topic, labels)))
    return '\n'.join(out)


def version_of(rows):
    return hashlib.sha256(canonical(rows).encode('utf-8')).hexdigest()[:12]


# ------------------------------------------------------------------ ciktilar
def sqlq(v):
    return "'" + v.replace("'", "''") + "'"


def build_seed(rows, version, source_sha):
    o = []
    o.append("-- 0072 — Konu agaci tohumu (URETILEN DOSYA — ELLE DUZENLEMEYIN)")
    o.append("--")
    o.append("-- Kaynak: taxonomy/yks-konulari.md")
    o.append("-- Uretici: python3 tools/build_taxonomy.py")
    o.append("-- Surum: %s  ·  kaynak sha256: %s" % (version, source_sha[:16]))
    o.append("--")
    o.append("-- Surum ICERIKTEN turuyor (kanonik serilestirmenin sha256'si), yani")
    o.append("-- guncellenmesi UNUTULAMAZ. Istemci bu degeri onbellegiyle karsilastirip")
    o.append("-- agaci ne zaman tazeleyecegine karar veriyor.")
    o.append("--")
    o.append("-- SIRA ONEMLI: once agac yazilir, SONRA eski adlarin remap'i calisir.")
    o.append("-- Tersi olsaydi remap'in yazdigi kanonik ad henuz agacta olmaz ve 0071'in")
    o.append("-- dogrulama tetikleyicisi kendi tohumunu reddederdi.")
    o.append("")
    o.append("delete from public.curriculum_aliases;")
    o.append("delete from public.curriculum_topics;")
    o.append("")

    ords = {}
    vals = []
    for cur, exam, subj, unit, topic, _ in rows:
        s_key, u_key, t_key = (cur, exam), (cur, exam, subj), (cur, exam, subj, unit)
        if subj not in ords.setdefault(s_key, {}):
            ords[s_key][subj] = len(ords[s_key])
        if unit not in ords.setdefault(u_key, {}):
            ords[u_key][unit] = len(ords[u_key])
        # DIKKAT: `ords.setdefault(k, {})[x] = len(ords[k])` YAZILAMAZ —
        # Python atamada SAG tarafi once degerlendiriyor ve `ords[k]` henuz
        # yokken KeyError veriyor.
        slot = ords.setdefault(t_key, {})
        slot[topic] = len(slot)
        vals.append('  (%s, %s, %s, %s, %s, %d, %d, %d)' % (
            sqlq(cur), sqlq(exam), sqlq(subj), sqlq(unit), sqlq(topic),
            ords[s_key][subj], ords[u_key][unit], slot[topic]))
    o.append("insert into public.curriculum_topics")
    o.append("  (curriculum, exam, subject, unit, topic,"
             " subject_ord, unit_ord, topic_ord)")
    o.append("values")
    o.append(',\n'.join(vals) + ';')
    o.append("")

    avals, remaps = [], []
    # `curriculum_aliases`in benzersiz indeksi (curriculum, exam, subject,
    # alias_norm) uzerinde ve `alias_norm` uretilmis bir sutun: tr_norm(alias).
    # Yani "olasilik" ile "Olasilik" AYNI satiri hedefliyor ve ikisini birden
    # yazmak INSERT'i patlatiyor.
    #
    # Dogrulayici (yukarida) bu cakismayi yalnizca iki FARKLI konuya isaret
    # ettiginde hata sayiyor — cunku ayni konuya giden iki yazim bir celiski
    # degil. Ama celiski olmamasi, IKISININ DE YAZILABILECEGI anlamina
    # gelmiyor. Yazici o zamana kadar ham listeyi geziyordu ve tohum
    # bos bir veritabaninda 23505 ile duruyordu (Task 11).
    #
    # Eleme KAYIPSIZ: arama zaten alias_norm uzerinden yapiliyor
    # (20260907000100_curriculum.sql:259), yani tek satir her iki yazimi da
    # cozuyor. remaps ASAGIDA elenmiyor — orasi `mistakes.concept` ile HAM
    # string karsilastiriyor, iki yazim iki ayri eski kayit kumesi demek.
    seen_alias = set()
    for cur, exam, subj, unit, topic, als in rows:
        for kind, alias, src in als:
            akey = (cur, exam, subj, tr_norm(alias))
            if akey not in seen_alias:
                seen_alias.add(akey)
                avals.append('  (%s, %s, %s, %s, %s, %s, %s)' % (
                    sqlq(cur), sqlq(exam), sqlq(subj), sqlq(alias), sqlq(topic),
                    sqlq(kind), sqlq(src) if src else 'null'))
            if kind == 'eski' and cur == 'eski':
                # Remap yalnizca 'eski' mufredat icin uretiliyor: MEB ice
                # aktarimi ve bugune kadarki tum kayitlar o agactan.
                if src and src != exam:
                    remaps.append(
                        "update public.mistakes set exam = %s, concept = %s\n"
                        "  where curriculum = 'eski'\n"
                        "    and exam = %s and subject = %s and concept = %s;"
                        % (sqlq(exam), sqlq(topic), sqlq(src), sqlq(subj), sqlq(alias)))
                else:
                    remaps.append(
                        "update public.mistakes set concept = %s\n"
                        "  where curriculum = 'eski'\n"
                        "    and exam = %s and subject = %s and concept = %s;"
                        % (sqlq(topic), sqlq(exam), sqlq(subj), sqlq(alias)))
    if avals:
        o.append("insert into public.curriculum_aliases")
        o.append("  (curriculum, exam, subject, alias, topic, kind, src_exam)")
        o.append("values")
        o.append(',\n'.join(avals) + ';')
        o.append("")

    o.append("-- ------------------------------------------------- eski adlarin remap'i")
    o.append("-- Bir konu yeniden adlandirildiginda gecmis kayitlar oksuz kalmasin diye.")
    o.append("-- Idempotent: ikinci calistirmada eslesen satir kalmaz.")
    o.append("--")
    o.append("-- `curriculum = 'eski'` SUZGECI SART: eski adlar yalnizca o agacin")
    o.append("-- tarihinden geliyor. Suzgec olmasaydi ayni (sinav, ders, konu) uclusune")
    o.append("-- sahip bir maarif satiri eski agacin konusuna cevrilir ve dogrulama")
    o.append("-- tetikleyicisi gocun kendisini reddederdi.")
    o.append("--")
    o.append("-- `tools/remap_konu.sql` bu blokta eridi: 265 satirlik, elle calistirilan,")
    o.append("-- 80'i no-op olan ve hicbir yerden referans verilmeyen bir betikti.")
    o.extend(remaps)
    o.append("")
    o.append("insert into public.curriculum_meta (only_row, version, source_sha)")
    o.append("values (true, %s, %s)" % (sqlq(version), sqlq(source_sha)))
    o.append("on conflict (only_row) do update")
    o.append("   set version = excluded.version,")
    o.append("       source_sha = excluded.source_sha,")
    o.append("       generated_at = now();")
    return '\n'.join(o) + '\n'


def build_asset(rows, version):
    """Istemcinin gomulu yedegi: RPC'nin dondurdugu bicimin aynisi."""
    tree = {}
    for cur, exam, subj, unit, topic, als in rows:
        exams = tree.setdefault(cur, {})
        subjects = exams.setdefault(exam, [])
        entry = next((s for s in subjects if s['subject'] == subj), None)
        if entry is None:
            entry = {'subject': subj, 'units': []}
            subjects.append(entry)
        u = next((x for x in entry['units'] if x['unit'] == unit), None)
        if u is None:
            u = {'unit': unit, 'topics': []}
            entry['units'].append(u)
        u['topics'].append({
            'topic': topic,
            'aliases': [a for _, a, _ in als],
        })
    doc = {'version': version, 'curricula': tree}
    return json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=False) + '\n'


# --------------------------------------------------------------------- akis
def generate():
    text = read(SOURCE)
    rows = parse(text)
    bad = validate(rows, subject_colors())
    if bad:
        raise SourceError('kaynak dosya kurallari ihlal ediyor:\n  ' + '\n  '.join(bad))
    version = version_of(rows)
    source_sha = hashlib.sha256(text.encode('utf-8')).hexdigest()
    return rows, version, {
        SEED: build_seed(rows, version, source_sha),
        ASSET: build_asset(rows, version),
    }


def selftest():
    """Dogrulayicinin gercekten AYIRT ETTIGINI kanitlar.

    Her vaka bir kurali bozuyor ve BEKLENEN hata metnini iceriyor olmali.
    Gecen bir vaka = sessizce kaybolmus bir kural.
    """
    M = '<!-- AGAC BASLANGICI -->\n'
    base = M + "## eski\n### TYT\n#### Fizik\n##### Mekanik\n- Optik\n- Enerji\n"
    cases = [
        ('yinelenen konu',
         M + "## eski\n### TYT\n#### Fizik\n##### Mekanik\n- Optik\n- Optik\n"),
        ('etiket BASKA konunun adiyla cakisiyor',
         M + "## eski\n### TYT\n#### Fizik\n##### Mekanik\n- Optik | ara: Enerji\n- Enerji\n"),
        ('etiket iki konuya isaret ediyor',
         M + "## eski\n### TYT\n#### Fizik\n##### Mekanik\n- Optik | ara: ayna\n- Enerji | ara: ayna\n"),
        ('etiket iki konuya isaret ediyor',
         M + "## eski\n### TYT\n#### Fizik\n##### Mekanik\n"
             "- Optik | ara: İvme\n- Enerji | ara: ivme\n"),
        ('ders rengi tanimsiz',
         M + "## eski\n### TYT\n#### Simya\n##### Mekanik\n- Optik\n"),
    ]
    colors = subject_colors()
    fails = []
    for expect, src in cases:
        bad = validate(parse(src), colors)
        if not any(expect in b for b in bad):
            fails.append('YAKALANMADI: %s' % expect)

    # Ayristirici tarafi: bozuk yapi sessizce atlanmamali.
    parse_cases = [
        ('bilinmeyen mufredat', M + "## yeni\n"),
        ('bilinmeyen sinav', M + "## eski\n### LGS\n"),
        ('konu once unite ister', M + "## eski\n### TYT\n#### Fizik\n- Optik\n"),
        ('unite once ders ister', M + "## eski\n### TYT\n##### Mekanik\n"),
        ('tanimsiz alan', M + "## eski\n### TYT\n#### Fizik\n##### M\n- Optik | xyz: a\n"),
        ('hic konu yok', M + "## eski\n### TYT\n#### Fizik\n"),
        ('AGAC BASLANGICI', "## eski\n### TYT\n#### Fizik\n##### M\n- Optik\n"),
    ]
    for expect, src in parse_cases:
        try:
            parse(src)
        except SourceError as e:
            if expect not in str(e):
                fails.append('YANLIS HATA: %s -> %s' % (expect, e))
        else:
            fails.append('YAKALANMADI (ayristirici): %s' % expect)

    # Saglikli girdi temiz gecmeli — yanlis pozitif kapisi.
    if validate(parse(base), colors | {'Fizik'}):
        fails.append('YANLIS POZITIF: saglikli girdi sorun uretti')

    # Etiket KENDI konusunun adiyla ayni olabilmeli (sapkasiz eski yazim).
    own = M + ("## eski\n### TYT\n#### Fizik\n##### Mekanik\n"
               "- Maddenin Hâlleri | eski: Maddenin Halleri\n")
    if validate(parse(own), colors | {'Fizik'}):
        fails.append('YANLIS POZITIF: kendi adiyla ayni etiket reddedildi')

    # Surum icerige duyarli olmali.
    if version_of(parse(base)) == version_of(parse(base.replace('Enerji', 'Isi'))):
        fails.append('SURUM icerik degisince DEGISMIYOR')

    # YAZICI KAPISI (Task 11 regresyonu).
    #
    # Yukaridaki "etiket iki konuya isaret ediyor" vakasi AYNI konuya giden
    # buyuk/kucuk harf ciftini bilerek gecirir — o bir celiski degil. Ama
    # `curriculum_aliases` benzersiz indeksi tr_norm(alias) uzerinde, yani
    # ikisi de YAZILIRSA tohum bos bir veritabaninda 23505 ile duruyor.
    # Bu tam olarak Task 11'de oldu: 8 cakisma, gocler 77'de durdu.
    #
    # Dogrulayici degil YAZICI sinaniyor: uretilen SQL'de o kapsam icin
    # TEK alias satiri olmali. Ayrica remap satirlari ELENMEMELI — orasi
    # mistakes.concept ile ham string karsilastiriyor.
    # `eski:` kullaniliyor cunku remap YALNIZCA o tur icin uretiliyor
    # (kind == 'eski' and cur == 'eski'); `ara:` ile ikinci iddia bos gecerdi.
    dup = M + ("## eski\n### TYT\n#### Fizik\n##### Mekanik\n"
               "- Optik | eski: mercek, Mercek\n")
    drows = parse(dup)
    seed = build_seed(drows, version_of(drows), 'x' * 64)
    abody = seed.split('insert into public.curriculum_aliases')[-1].split(';')[0]
    if abody.count("'mercek'") + abody.count("'Mercek'") != 1:
        fails.append('YAZICI: tr_norm cakismasi elenmedi — tohum 23505 ile patlar')
    if seed.count("concept = 'mercek'") < 1 or seed.count("concept = 'Mercek'") < 1:
        fails.append('YAZICI: remap satirlari da elenmis — eski kayitlar sahipsiz kalir')

    for f in fails:
        print(f)
    print('selftest: %d sorun' % len(fails))
    return 1 if fails else 0


def main():
    args = sys.argv[1:]
    if '--selftest' in args:
        return selftest()
    try:
        rows, version, outputs = generate()
    except SourceError as e:
        print('HATA: %s' % e)
        return 1

    if '--check' in args:
        stale = []
        for rel, want in outputs.items():
            path = os.path.join(ROOT, rel)
            have = read(rel) if os.path.exists(path) else None
            if have != want:
                stale.append(rel)
        if stale:
            print('URETILEN DOSYA BAYAT (yeniden uretin: python3 tools/build_taxonomy.py):')
            for s in stale:
                print('   %s' % s)
            return 1
        print('taksonomi: %d konu · surum %s · ciktilar guncel' % (len(rows), version))
        return 0

    for rel, body in outputs.items():
        path = os.path.join(ROOT, rel)
        d = os.path.dirname(path)
        if not os.path.isdir(d):
            os.makedirs(d)
        with io.open(path, 'w', encoding='utf-8') as f:
            f.write(body)
        print('yazildi: %s' % rel)
    print('taksonomi: %d konu · surum %s' % (len(rows), version))
    return 0


if __name__ == '__main__':
    sys.exit(main())
