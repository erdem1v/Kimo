// Kota / maliyet modeli — cap rakamlarını TEK kaynaktan üretir.
//
// NEDEN VAR: cap tabloları çağrı başı birim maliyete bağlı ve o değer A/B
// ölçülene kadar bilinmiyor. Bu betik her tabloyu formülden üretiyor; ölçüm
// gelince tek hamlede dolsun diye:
//
//   node tools/cap_model.mjs --unit 0.00107        # ölçülen birim maliyet
//   node tools/cap_model.mjs --unit 0.00107 --ceiling 0.0019 --fx 48.44
//
// Varsayılan birim maliyet DOKÜMANTASYONDAN türetilmiş tahmindir ve çıktıda
// böyle işaretlenir. `tools/ab_model_bench.mjs` koşulduktan sonra oradaki
// ölçülen ortalama buraya --unit ile geçilir.

const args = process.argv.slice(2);
const arg = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i > -1 ? Number(args[i + 1]) : def;
};

const UNIT      = arg('unit', 0.0011);      // $/analiz — tipik
const CEILING   = arg('ceiling', 0.0021);   // $/analiz — mutlak tavan
const MEASURED  = args.includes('--unit');
const FX        = arg('fx', 48.44);         // ₺/$
const PRICE_TRY = arg('price', 150);        // abonelik brüt ₺/ay
const VAT       = arg('vat', 0.20);         // KDV (fiyata dahil)
const COMMISSION= arg('commission', 0.15);  // mağaza komisyonu

// Aylık planın neti; yıllık plan aynı fiyattan indirimli satılırsa ayrıca
// verilir. TL'nin yıl içi erimesi yıllık planda muhafazakâr rakamı düşürüyor.
const NET_MONTHLY = (PRICE_TRY / (1 + VAT)) * (1 - COMMISSION) / FX;
const NET_ANNUAL  = arg('net-annual', 1.35);

const INFRA_RESERVE = arg('infra', 0.08);   // Supabase + depolama + push / premium kullanıcı / ay
const COACH_MSG_COST = arg('coach-msg', 0.001); // AI koç mesaj başına (metin, luna)

const nl = () => console.log('');
const rule = (n = 78) => console.log('─'.repeat(n));
const usd = (v, d = 2) => `$${v.toFixed(d)}`;

// ---------------------------------------------------------------- desenler
// Her desen AÇIKÇA tanımlı: günlük çalışmada çıkan yanlış + ayda kaç deneme.
// "Gerçekçi ağır" gibi tanımsız bir girdi kullanmamak için var.
const PATTERNS = [
  { ad: 'Medyan',        gunluk: 1,  gun: 30, deneme: 0,  denemeBoy: 0  },
  { ad: 'Düzenli',       gunluk: 5,  gun: 26, deneme: 2,  denemeBoy: 30 },
  { ad: 'Ağır',          gunluk: 8,  gun: 26, deneme: 4,  denemeBoy: 32 },
  { ad: 'Çok ağır',      gunluk: 12, gun: 26, deneme: 8,  denemeBoy: 35 },
];
const aylik = (p) => p.gunluk * p.gun + p.deneme * p.denemeBoy;
const gunlukOrt = (p) => aylik(p) / 30;

function patternTable() {
  console.log('KULLANIM DESENLERİ — her rakam tanımlı, varsayım yok');
  rule();
  console.log('DESEN         GÜNLÜK ÇALIŞMA   DENEME/AY   ANALİZ/AY   ANALİZ/GÜN ORT');
  for (const p of PATTERNS) {
    console.log(
      p.ad.padEnd(14) +
      `${p.gunluk}/gün × ${p.gun} gün`.padEnd(17) +
      (p.deneme ? `${p.deneme} × ${p.denemeBoy}` : '—').padEnd(12) +
      String(aylik(p)).padStart(9) +
      gunlukOrt(p).toFixed(1).padStart(17)
    );
  }
}

function burnTable(cap, pencere, katman) {
  console.log(`${katman} — cap ${cap}/ay, pencere ${pencere}/8 saat: hangi desen kaç günde duvara çarpar?`);
  rule();
  console.log('DESEN            ANALİZ/AY   ANALİZ/GÜN   PENCEREYE SIĞAR MI   CAP KAÇ GÜNDE DOLAR');
  for (const p of PATTERNS) {
    const g = gunlukOrt(p);
    const gun = aylik(p) <= cap ? '— (hiç)' : (cap / g).toFixed(0) + ' gün';
    // Deneme günü tek oturumda kaç analiz gerekiyor?
    const pik = p.deneme ? p.denemeBoy : p.gunluk;
    const sigar = pik <= pencere ? `evet (${pik}≤${pencere})` : `HAYIR (${pik}>${pencere})`;
    console.log(p.ad.padEnd(17) + String(aylik(p)).padStart(9) + g.toFixed(1).padStart(13) +
                sigar.padStart(21) + gun.padStart(21));
  }
  const patlama = pencere * 3;
  console.log('Tam patlama'.padEnd(17) + String(patlama * 30).padStart(9) + String(patlama).padStart(13) +
              '— (kötüye kullanım)'.padStart(21) + `${(cap / patlama).toFixed(1)} gün`.padStart(21));
}

function capCostTable(caps) {
  console.log('CAP SEVİYESİ BAŞINA AYLIK MALİYET VE GELİR ORANI');
  rule(92);
  console.log('CAP    TAVANDA $   MUTLAK $   / YILLIK NET $1,35   / AYLIK NET ' +
              usd(NET_MONTHLY) + '   %70 DOLULUKTA $');
  for (const c of caps) {
    const tavan = c * UNIT, mutlak = c * CEILING, ort = 0.7 * tavan;
    console.log(
      String(c).padEnd(7) +
      usd(tavan, 3).padStart(9) +
      usd(mutlak, 3).padStart(11) +
      `%${((100 * tavan) / NET_ANNUAL).toFixed(0)}`.padStart(20) +
      `%${((100 * tavan) / NET_MONTHLY).toFixed(0)}`.padStart(19) +
      usd(ort, 3).padStart(18)
    );
  }
}

function breakEven() {
  console.log('GELİRİN İZİN VERDİĞİ AZAMİ CAP');
  rule();
  const coach = [
    { ad: 'Hafif  (20 mesaj/ay)', n: 20 },
    { ad: 'Orta   (60 mesaj/ay)', n: 60 },
    { ad: 'Ağır  (200 mesaj/ay)', n: 200 },
  ];
  console.log('AI koç rezervi (metin sohbet, mesaj başı ' + usd(COACH_MSG_COST, 4) + '):');
  for (const c of coach) console.log(`  ${c.ad.padEnd(24)} ${usd(c.n * COACH_MSG_COST, 3)}/ay`);
  const COACH_RESERVE = 200 * COACH_MSG_COST;  // ağır kullanımı karşıla
  console.log(`  → rezerv olarak alınan: ${usd(COACH_RESERVE, 2)}/ay (ağır koç kullanımını karşılar)`);
  console.log(`  Altyapı payı (Supabase, depolama, push): ${usd(INFRA_RESERVE, 2)}/ay`);
  nl();

  for (const [net, ad] of [[NET_ANNUAL, 'Yıllık plan neti'], [NET_MONTHLY, 'Aylık plan neti']]) {
    const analiz = net - COACH_RESERVE - INFRA_RESERVE;
    const be = Math.floor(analiz / UNIT);
    const be70 = Math.floor(analiz / (0.7 * UNIT));
    console.log(`${ad} ${usd(net)}`);
    console.log(`  − AI koç ${usd(COACH_RESERVE)}  − altyapı ${usd(INFRA_RESERVE)}  = analize kalan ${usd(analiz)}`);
    console.log(`  Break-even cap (her kullanıcı tavanda bile geliri aşmaz): ${be} analiz/ay`);
    console.log(`  %70 doluluk varsayımıyla cap (portföy başabaş, tek kullanıcı aşabilir): ${be70} analiz/ay`);
    nl();
  }
}

function freeTierTable(caps) {
  console.log('ÜCRETSİZ KATMAN — 1000 KULLANICIDA AYLIK TOPLAM');
  rule(84);
  const head = 'CAP    ' + PATTERNS.map(p => p.ad.padStart(12)).join('') + '   HEPSİ TAVANDA';
  console.log(head);
  for (const c of caps) {
    const cells = PATTERNS.map(p => {
      const kullanim = Math.min(aylik(p), c);
      return usd(1000 * kullanim * UNIT, 0).padStart(12);
    }).join('');
    console.log(String(c).padEnd(7) + cells + usd(1000 * c * UNIT, 0).padStart(16));
  }
  nl();
  console.log('Not: sütunlar "1000 kullanıcının HEPSİ o deseni yaparsa" demek — üst sınır,');
  console.log('beklenen değer değil. Gerçek karma dağılımda medyan sütununa yakın çıkar.');
}

function attackTable() {
  console.log('E-POSTA DOĞRULAMASI OLMADAN: SAHTE KAYIT SALDIRISININ MALİYETİ');
  rule(84);
  const FREE_CAP = 300;
  const perAccount = FREE_CAP * UNIT;
  const RAMP_24H = 30;
  const rows = [
    { ad: 'Hiçbir kontrol yok', hesapGun: 8640, hesapDeger: perAccount,
      not: 'Supabase tabanı: IP başına 5 dk\'da 30 kayıt = 8.640/gün' },
    { ad: '+ kayıt hız sınırı (300/gün/IP)', hesapGun: 300, hesapDeger: perAccount,
      not: 'before_user_created kancası, CGNAT-güvenli cömert sınır' },
    { ad: '+ yeni hesap rampası', hesapGun: 300, hesapDeger: RAMP_24H * UNIT,
      not: 'ilk 24 saat 30 analiz; saldırgan beklerse rampa yalnızca geciktirir' },
  ];
  console.log('KONTROL                            HESAP/GÜN/IP   $/HESAP   GÜNLÜK $/IP   AYLIK $/IP');
  for (const r of rows) {
    console.log(r.ad.padEnd(35) + String(r.hesapGun).padStart(13) +
                usd(r.hesapDeger, 3).padStart(10) +
                usd(r.hesapGun * r.hesapDeger, 0).padStart(14) +
                usd(30 * r.hesapGun * r.hesapDeger, 0).padStart(13));
  }
  nl();
  console.log('Rampa KARARLI DURUMU bağlamıyor: saldırgan hesapları biriktirip beklerse');
  console.log('her biri sonunda tam cap\'e ulaşır. Kararlı durumu bağlayan tek şey cihaz sınırı:');
  nl();
  const DEVICE_CAP = 900;   // cihaz kurulumu başına aylık analiz
  console.log('CİHAZ SINIRI (kurulum başına ' + DEVICE_CAP + ' analiz/ay)');
  console.log('FİZİKSEL CİHAZ   AYLIK ANALİZ   AYLIK $');
  for (const n of [1, 10, 100, 1000]) {
    console.log(String(n).padEnd(17) + String(n * DEVICE_CAP).padStart(13) +
                usd(n * DEVICE_CAP * UNIT, 0).padStart(10));
  }
  nl();
  console.log('Saldırganın maliyeti artık kimlik değil DONANIM: 100 gerçek cihaz alıp');
  console.log(`bize ayda ${usd(100 * DEVICE_CAP * UNIT, 0)} yaktırmak ekonomik değil.`);
}

// ------------------------------------------------------------------- çıktı
console.log('='.repeat(84));
console.log('KİMO — KOTA VE MALİYET MODELİ');
console.log('='.repeat(84));
console.log(`Birim maliyet : ${usd(UNIT, 5)}/analiz  ${MEASURED ? '\x1b[32m[ÖLÇÜLDÜ]\x1b[0m' : '\x1b[33m[TAHMİN — A/B koşulmadı]\x1b[0m'}`);
console.log(`Mutlak tavan  : ${usd(CEILING, 5)}/analiz`);
console.log(`Abonelik      : ${PRICE_TRY} ₺/ay brüt · KDV %${VAT * 100} · komisyon %${COMMISSION * 100} · kur ${FX} ₺/$`);
console.log(`Net gelir     : aylık plan ${usd(NET_MONTHLY)} · yıllık plan ${usd(NET_ANNUAL)} (muhafazakâr)`);
nl();

patternTable(); nl();
capCostTable([300, 500, 750, 1000, 1500]); nl();
breakEven();
burnTable(1000, 40, 'PREMIUM'); nl();
burnTable(300, 15, 'ÜCRETSİZ'); nl();
freeTierTable([200, 300, 500, 750]); nl();
attackTable();
nl();
if (!MEASURED) {
  console.log('\x1b[33mUYARI: birim maliyet ölçülmedi. Yukarıdaki her dolar rakamı tahmindir.');
  console.log('       tools/ab_model_bench.mjs koşulduktan sonra:');
  console.log('       node tools/cap_model.mjs --unit <ölçülen ortalama>\x1b[0m');
}
