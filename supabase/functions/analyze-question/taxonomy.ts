// YKS konu taksonomisi — AI sınıflandırmasının referans ağacı.
//
// VERİ GÖVDESİ BURADAN KALKTI (Task 09). Eskiden 434 konu bu dosyada elle
// yazılıydı ve `lib/data/yks_curriculum.dart` aynı listenin ikinci kopyasını
// taşıyordu; senkronu garanti eden tek şey bir yorum satırıydı. Dosyanın
// başlığı kaynak olarak `YKS_TYT_AYT_Konulari.md` gösteriyordu — o dosya git
// geçmişinde HİÇ commit edilmemişti.
//
// Artık tek çalışma zamanı kaynağı VERİTABANI (göç 0071). Yazım kaynağı
// `taxonomy/yks-konulari.md`, tohum `tools/build_taxonomy.py` ile üretiliyor.
//
// NEDEN İKİ GÖMÜLÜ KOPYA DEĞİL: istemcinin GÖSTERDİĞİ ağaç ile sunucunun
// DOĞRULADIĞI ağaç aynı olmak zorunda. İki ayrı derleme hedefine gömülen iki
// kopya, sürümleri ayrıştığı anda kullanıcıya "listeden seçtiğim konu
// reddedildi" diye görünür.

export type Curriculum = "eski" | "maarif";
export type Exam = "TYT" | "AYT";

/** Ağacın bellek içi biçimi: sınav → ders → konu[]. Etiketler DAHİL DEĞİL. */
export interface Taxonomy {
  version: string;
  byExam: Record<Exam, Record<string, string[]>>;
}

/**
 * Isolate ömrü boyunca yaşayan önbellek.
 *
 * TTL VAR ÇÜNKÜ SÜRESİZ ÖNBELLEK YANLIŞ OLURDU: müfredat değiştiğinde sıcak
 * bir isolate eski ağaçla doğrulamaya devam eder ve istemci yeni ağacı
 * gösterirken sunucu eskisine göre karar verir — tam da bu paketin kapatmaya
 * çalıştığı ayrışma. Beş dakika, "her istekte bir RPC" ile "sınırsız bayat"
 * arasında bilinçli bir orta yol.
 */
const TTL_MS = 5 * 60 * 1000;
const cache = new Map<Curriculum, { at: number; tree: Taxonomy }>();

/** Test/ölçüm araçları için: önbelleği boşaltır. */
export function resetTaxonomyCache(): void {
  cache.clear();
}

interface TreeResponse {
  version: string;
  fresh: boolean;
  exams?: Record<string, Array<{
    subject: string;
    units: Array<{ unit: string; topics: Array<{ topic: string }> }>;
  }>>;
}

function flatten(version: string, exams: TreeResponse["exams"]): Taxonomy {
  const byExam: Record<Exam, Record<string, string[]>> = { TYT: {}, AYT: {} };
  for (const exam of ["TYT", "AYT"] as Exam[]) {
    for (const s of exams?.[exam] ?? []) {
      byExam[exam][s.subject] = s.units.flatMap((u) =>
        u.topics.map((t) => t.topic)
      );
    }
  }
  return { version, byExam };
}

/**
 * Ağacı getirir (gerekirse veritabanından).
 *
 * `rpc` çağırandan geliyor: `index.ts` zaten kullanıcının JWT'siyle RPC atan
 * bir yardımcı taşıyor ve `curriculum_tree` oturum istiyor. Servis rolü
 * KULLANILMIYOR — bu okuma kullanıcının kendi yetkisiyle yapılabilir ve
 * fonksiyonun servis rolü yüzeyini genişletmemek gerekiyor.
 *
 * Sürüm pazarlığı: elde bir sürüm varsa RPC'ye gönderiliyor ve sunucu
 * değişmediyse ağacı GÖNDERMİYOR (`fresh: true`).
 */
export async function loadTaxonomy(
  rpc: (name: string, body: Record<string, unknown>) => Promise<unknown>,
  curriculum: Curriculum,
): Promise<Taxonomy> {
  const hit = cache.get(curriculum);
  if (hit && Date.now() - hit.at < TTL_MS) return hit.tree;

  const res = await rpc("curriculum_tree", {
    p_curriculum: curriculum,
    p_known_version: hit?.tree.version ?? null,
  }) as TreeResponse;

  if (!res || typeof res.version !== "string" || res.version === "") {
    throw new Error("curriculum_tree bozuk yanıt döndürdü");
  }

  // Değişmediyse eldeki ağaç geçerli; yalnızca tazelik damgasını ilerletiyoruz.
  const tree = res.fresh && hit
    ? hit.tree
    : flatten(res.version, res.exams);

  if (Object.keys(tree.byExam.TYT).length === 0 &&
      Object.keys(tree.byExam.AYT).length === 0) {
    // Boş ağaçla devam etmek, sınıflandırmayı sessizce doğrulamasız
    // bırakmak demek. Çağıran bunu 503'e çeviriyor.
    throw new Error("konu ağacı boş döndü");
  }

  cache.set(curriculum, { at: Date.now(), tree });
  return tree;
}

/** Prompt'a gömmek için dersleri ve konuları kompakt metin bloğu olarak üretir. */
export function taxonomyText(tree: Taxonomy): string {
  const lines: string[] = [];
  for (const exam of ["TYT", "AYT"] as Exam[]) {
    lines.push(`${exam}:`);
    const subjects = tree.byExam[exam];
    for (const ders of Object.keys(subjects)) {
      lines.push(`- ${ders}: ${subjects[ders].join("; ")}`);
    }
  }
  return lines.join("\n");
}

/**
 * AI'ın döndürdüğü ders/konu'yu taksonomiye göre doğrular (birebir eşleşme).
 *
 * ARAMA ETİKETLERİ BURADA YOK ve olmamalı: etiketler ("atışlar") kullanıcının
 * seçicide arama yapması için var. Modelin onlardan birini yazması, kanonik
 * adı yazmamak demek olurdu ve arşiv iki adla bölünürdü. Prompt da bu yüzden
 * yalnızca kanonik listeyi görüyor.
 */
export function isValidPair(
  tree: Taxonomy,
  exam: string,
  ders: string,
  konu: string,
): boolean {
  const subjects = exam === "AYT"
    ? tree.byExam.AYT
    : exam === "TYT"
    ? tree.byExam.TYT
    : null;
  if (!subjects) {
    // Sınav bilinmiyorsa TYT+AYT birleşiminde ara.
    return hasKonu(tree.byExam.TYT[ders], konu) ||
      hasKonu(tree.byExam.AYT[ders], konu);
  }
  return hasKonu(subjects[ders], konu);
}

function hasKonu(konular: string[] | undefined, konu: string): boolean {
  if (!konular) return false;
  return konular.some((k) => k.toLowerCase() === konu.toLowerCase());
}
