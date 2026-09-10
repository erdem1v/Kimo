// Model A/B — analyze-question için çağrı başı MALİYET ve KALİTE ölçümü.
//
// NEDEN VAR: rev. 2/3 planındaki maliyet tablosu OpenAI dokümantasyonundan
// TÜRETİLDİ, ölçülmedi. Özellikle iki iddia sezgiye aykırı ve doğrulanmadan
// karar dayanağı olamaz:
//   (1) `detail:"high"` bu model ailesinde `auto`'dan UCUZ (2.500 patch
//       bütçesi görseli küçültüyor; `auto` = `original` = küçültme yok).
//   (2) `reasoning.effort:"none"` ile luna'nın çıktı token'ı JSON'un
//       kendisinden ibaret kalıyor (reasoning token'ları çıktı fiyatından
//       faturalanır — ölçülmezse premium kotası yanlış boyutlanır).
//
// Bu betik tahmin ETMİYOR: her çağrının `usage` bloğunu okuyup gerçek
// token sayılarından maliyeti hesaplıyor.
//
// Sistem prompt'u üretimdeki ile AYNI olmak zorunda; taksonomi bu yüzden
// `analyze-question/taxonomy.ts`'den doğrudan içe aktarılıyor (Node 25 tipleri
// kendiliğinden sıyırıyor). Prompt metni aşağıda aynalanmış durumda ve
// `index.ts` ile eşleştiği her koşumda denetleniyor.
//
// KULLANIM:
//   OPENAI_API_KEY=sk-... node tools/ab_model_bench.mjs <foto-dizini> [--limit N]
//
// Fotoğraflar ideal olarak uygulamanın çekim yolundan geçmiş kareler olmalı
// (image_picker maxWidth:1600, imageQuality:85). Karışım önemli: basılı test
// kitabı, el yazısı, grafik/şekil içeren soru, kötü ışık, eğik çekim.

import { execFile } from 'node:child_process';
import { mkdtemp, readdir, readFile, writeFile, rm } from 'node:fs/promises';
import { promisify } from 'node:util';
import { tmpdir } from 'node:os';
import path from 'node:path';

const execFileAsync = promisify(execFile);
const HERE = path.dirname(new URL(import.meta.url).pathname);
const FN_DIR = path.join(HERE, '..', 'supabase', 'functions', 'analyze-question');

const { taxonomyText, isValidPair } = await import(path.join(FN_DIR, 'taxonomy.ts'));

// ---------------------------------------------------------------- fiyatlar
// developers.openai.com/api/docs/pricing — $/1M token. Koşumdan önce teyit et:
// fiyat değişirse buradaki tablo sessizce yanlış maliyet üretir.
const PRICES = {
  'gpt-4o-mini':   { in: 0.15, cached: 0.075, out: 0.60 },
  'gpt-5.6-luna':  { in: 0.20, cached: 0.02,  out: 1.20 },
};

// --------------------------------------------------------- yapılandırmalar
const CONFIGS = [
  { id: 'kontrol',    model: 'gpt-4o-mini',  detail: null,     effort: null   },
  { id: 'luna-high',  model: 'gpt-5.6-luna', detail: 'high',   effort: 'none' },
  { id: 'luna-auto',  model: 'gpt-5.6-luna', detail: 'auto',   effort: 'none' },
];
const WIDTHS = [1600, 1200];
const CURRICULUM = 'eski';
const MAX_COMPLETION_TOKENS = 800;
const CONCURRENCY = 3;

// ------------------------------------------------------------ sistem prompt
// index.ts:158-175 ile birebir aynı olmalı.
const SYSTEM_PROMPT =
  "Sen bir YKS sorusu doğrulama, şık çıkarma ve konu sınıflandırma " +
  "aracısın. Verilen fotoğrafı değerlendir. GEÇERLİ bir çoktan " +
  "seçmeli soru fotoğrafı için üç şart: (1) metin net OKUNABİLİR, " +
  "(2) bir SORU/problem ifadesi var, (3) ŞIKLAR var. is_readable, " +
  "has_question, has_options bayraklarını buna göre doldur. Şıkları " +
  "aynen çıkar (doğru cevabı SEN belirleme). Geçerliyse soruyu " +
  "sınıflandır: 'sinav' TYT veya AYT; 'ders' ve 'konu' ise AŞAĞIDAKİ " +
  "LİSTEDEN seçilmeli. 'konu' listedeki bir konu adıyla BİREBİR aynı " +
  "yazılmalı (kendi adını uydurma). MÜMKÜN OLAN EN SPESİFİK (EN DAR) " +
  "konuyu seç; genel/şemsiye başlık yerine tam eşleşen alt konuyu " +
  "tercih et (ör. genel 'İnsan Fizyolojisi' yerine 'Destek ve Hareket " +
  "Sistemi'). Emin değilsen en yakın konuyu seç. Geçersizse ders/" +
  "konu/sinav boş kalsın ve 'reason_code' alanına nedenlerden birini " +
  "yaz: unreadable (metin okunmuyor), no_question (soru ifadesi yok), " +
  "no_options (şıklar yok). Geçerliyse 'ok' yaz. SERBEST METİN YAZMA.\n\n" +
  "KONU LİSTESİ (" + CURRICULUM + " müfredat):\n" +
  taxonomyText(CURRICULUM);

const RESPONSE_FORMAT = {
  type: 'json_schema',
  json_schema: {
    name: 'question_analysis',
    strict: true,
    schema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        is_readable:  { type: 'boolean' },
        has_question: { type: 'boolean' },
        has_options:  { type: 'boolean' },
        reason_code:  { type: 'string', enum: ['ok', 'unreadable', 'no_question', 'no_options'] },
        sinav:        { type: 'string', enum: ['TYT', 'AYT', ''] },
        ders:         { type: 'string' },
        konu:         { type: 'string' },
        options: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            properties: { label: { type: 'string' }, text: { type: 'string' } },
            required: ['label', 'text'],
          },
        },
      },
      required: ['is_readable', 'has_question', 'has_options', 'reason_code',
                 'sinav', 'ders', 'konu', 'options'],
    },
  },
};

/** Aynalanan prompt üretimden ayrışmışsa yüksek sesle uyar. */
async function assertPromptInSync() {
  const src = await readFile(path.join(FN_DIR, 'index.ts'), 'utf8');
  const probe = 'Sen bir YKS sorusu doğrulama, şık çıkarma ve konu sınıflandırma';
  if (!src.includes(probe)) {
    console.warn('\x1b[33m! index.ts içindeki sistem prompt değişmiş görünüyor — ' +
                 'bu betikteki ayna güncellenmeli, ölçüm üretimi temsil etmiyor olabilir.\x1b[0m');
  }
}

// ------------------------------------------------------------------ görsel
/** sips ile GENİŞLİĞE göre küçültür (image_picker maxWidth ile aynı semantik). */
async function resizeToWidth(src, width, outDir) {
  const { stdout } = await execFileAsync('sips', ['--getProperty', 'pixelWidth', src]);
  const cur = Number(stdout.match(/pixelWidth:\s*(\d+)/)?.[1] ?? 0);
  const out = path.join(outDir, `${width}-${path.basename(src).replace(/\.\w+$/, '')}.jpg`);
  const args = ['-s', 'format', 'jpeg', '-s', 'formatOptions', '85'];
  // Kaynak zaten dar ise BÜYÜTME — image_picker da büyütmüyor.
  if (cur > width) args.push('--resampleWidth', String(width));
  await execFileAsync('sips', [...args, src, '--out', out]);
  const bytes = await readFile(out);
  const { stdout: dim } = await execFileAsync('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', out]);
  return {
    path: out,
    base64: bytes.toString('base64'),
    bytes: bytes.length,
    w: Number(dim.match(/pixelWidth:\s*(\d+)/)?.[1] ?? 0),
    h: Number(dim.match(/pixelHeight:\s*(\d+)/)?.[1] ?? 0),
  };
}

// ------------------------------------------------------------------ çağrı
function buildPayload(cfg, base64) {
  const image_url = { url: `data:image/jpeg;base64,${base64}` };
  if (cfg.detail) image_url.detail = cfg.detail;
  const payload = {
    model: cfg.model,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      {
        role: 'user',
        content: [
          { type: 'text', text: 'Bu fotoğrafı değerlendir; şıkları (harf + metin) çıkar ve soruyu sinav/ders/konu olarak sınıflandır.' },
          { type: 'image_url', image_url },
        ],
      },
    ],
    response_format: RESPONSE_FORMAT,
    max_completion_tokens: MAX_COMPLETION_TOKENS,
  };
  if (cfg.effort) payload.reasoning_effort = cfg.effort;
  return payload;
}

/** Hata gövdesini tek satıra indirir ve içindeki anahtar parçalarını siler. */
function tidyError(text) {
  return text.replace(/sk-[A-Za-z0-9_*-]+/g, 'sk-***')
             .replace(/\s+/g, ' ').trim().slice(0, 200);
}

async function callOpenAI(payload, key, attempt = 0) {
  const t0 = Date.now();
  const resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const ms = Date.now() - t0;
  const text = await resp.text();

  if (!resp.ok) {
    // Bilinmeyen parametre: reasoning_effort'suz bir kez daha dene ve bunu KAYDET.
    if (resp.status === 400 && /reasoning_effort/i.test(text) && payload.reasoning_effort) {
      const { reasoning_effort, ...rest } = payload;
      const retry = await callOpenAI(rest, key, attempt);
      return { ...retry, effortSupported: false };
    }
    // Hız sınırı / geçici sunucu hatası: üstel geri çekilme.
    if ((resp.status === 429 || resp.status >= 500) && attempt < 4) {
      await new Promise(r => setTimeout(r, 1500 * 2 ** attempt));
      return callOpenAI(payload, key, attempt + 1);
    }
    return { ok: false, status: resp.status, error: tidyError(text), ms };
  }

  const data = JSON.parse(text);
  const u = data.usage ?? {};
  return {
    ok: true,
    ms,
    effortSupported: payload.reasoning_effort ? true : undefined,
    usage: {
      prompt: u.prompt_tokens ?? 0,
      cached: u.prompt_tokens_details?.cached_tokens ?? 0,
      completion: u.completion_tokens ?? 0,
      reasoning: u.completion_tokens_details?.reasoning_tokens ?? 0,
    },
    finish: data.choices?.[0]?.finish_reason ?? null,
    content: data.choices?.[0]?.message?.content ?? null,
  };
}

function costOf(model, usage) {
  const p = PRICES[model];
  if (!p) return null;
  const fresh = Math.max(usage.prompt - usage.cached, 0);
  return (fresh * p.in + usage.cached * p.cached + usage.completion * p.out) / 1e6;
}

// ------------------------------------------------------------------- akış
async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx], idx);
    }
  }));
  return out;
}

function fmt(n, d = 5) { return n == null ? '—' : n.toFixed(d); }
function pct(a, b) { return b === 0 ? '—' : `%${Math.round((100 * a) / b)}`; }

async function main() {
  const key = process.env.OPENAI_API_KEY;
  const dir = process.argv[2];
  const limitArg = process.argv.indexOf('--limit');
  const limit = limitArg > -1 ? Number(process.argv[limitArg + 1]) : Infinity;

  if (!dir) {
    console.error('Kullanım: OPENAI_API_KEY=sk-... node tools/ab_model_bench.mjs <foto-dizini> [--limit N]');
    process.exit(2);
  }
  if (!key) {
    console.error('OPENAI_API_KEY tanımlı değil. gpt-5.6-luna erişimi olan bir anahtar gerekiyor.');
    process.exit(2);
  }

  await assertPromptInSync();

  const files = (await readdir(dir))
    .filter(f => /\.(jpe?g|png|heic)$/i.test(f))
    .slice(0, limit)
    .map(f => path.join(dir, f));

  if (files.length === 0) {
    console.error(`${dir} içinde görsel bulunamadı (jpg/jpeg/png/heic).`);
    process.exit(2);
  }

  console.log(`${files.length} fotoğraf · ${CONFIGS.length} yapılandırma · ${WIDTHS.length} çözünürlük`);
  console.log(`= ${files.length * CONFIGS.length * WIDTHS.length} çağrı\n`);
  console.log(`sistem prompt: ${SYSTEM_PROMPT.length} karakter (taksonomi üretimden içe aktarıldı)\n`);

  const work = [];
  const tmp = await mkdtemp(path.join(tmpdir(), 'kimo-ab-'));
  try {
    for (const f of files) {
      for (const w of WIDTHS) {
        const img = await resizeToWidth(f, w, tmp);
        for (const cfg of CONFIGS) work.push({ file: path.basename(f), width: w, img, cfg });
      }
    }

    let done = 0;
    const rows = await mapLimit(work, CONCURRENCY, async (job) => {
      const res = await callOpenAI(buildPayload(job.cfg, job.img.base64), key);
      done++;
      process.stdout.write(`\r  ${done}/${work.length} çağrı tamamlandı`);

      let parsed = null;
      try { parsed = res.content ? JSON.parse(res.content) : null; } catch { /* şema dışı */ }

      return {
        file: job.file,
        width: job.width,
        px: `${job.img.w}x${job.img.h}`,
        kb: Math.round(job.img.bytes / 1024),
        config: job.cfg.id,
        model: job.cfg.model,
        detail: job.cfg.detail,
        effort: job.cfg.effort,
        effortSupported: res.effortSupported,
        ok: res.ok,
        status: res.status ?? 200,
        error: res.error ?? null,
        ms: res.ms,
        usage: res.usage ?? null,
        cost: res.ok ? costOf(job.cfg.model, res.usage) : null,
        finish: res.finish ?? null,
        quality: parsed && {
          is_readable: parsed.is_readable,
          has_question: parsed.has_question,
          has_options: parsed.has_options,
          reason_code: parsed.reason_code,
          sinav: parsed.sinav,
          ders: parsed.ders,
          konu: parsed.konu,
          option_count: Array.isArray(parsed.options) ? parsed.options.length : 0,
          option_labels: Array.isArray(parsed.options) ? parsed.options.map(o => o.label).join('') : '',
          konu_valid: Boolean(parsed.ders && parsed.konu &&
            isValidPair(CURRICULUM, parsed.sinav ?? '', parsed.ders, parsed.konu)),
        },
      };
    });
    console.log('\n');

    // ------------------------------------------------------------- özet
    const out = path.join(HERE, 'ab-results.json');
    await writeFile(out, JSON.stringify({ ranAt: new Date().toISOString(), prices: PRICES, rows }, null, 2));

    const groups = new Map();
    for (const r of rows) {
      const k = `${r.config}@${r.width}`;
      if (!groups.has(k)) groups.set(k, []);
      groups.get(k).push(r);
    }

    const control = rows.filter(r => r.config === 'kontrol' && r.width === 1600 && r.ok);
    const controlBy = new Map(control.map(r => [r.file, r.quality]));

    console.log('YAPILANDIRMA          n   görsel+prompt   çıktı  reasoning     $/çağrı   okunur  şık≥4  konu✓   ms');
    console.log('─'.repeat(104));
    for (const [k, g] of groups) {
      const okRows = g.filter(r => r.ok);
      if (okRows.length === 0) { console.log(`${k.padEnd(20)} ${String(g.length).padStart(3)}   — tümü hata: ${g[0].error?.slice(0,60)}`); continue; }
      const avg = (f) => okRows.reduce((s, r) => s + f(r), 0) / okRows.length;
      const q = okRows.filter(r => r.quality);
      console.log(
        k.padEnd(20) +
        String(okRows.length).padStart(4) +
        String(Math.round(avg(r => r.usage.prompt))).padStart(15) +
        String(Math.round(avg(r => r.usage.completion))).padStart(8) +
        String(Math.round(avg(r => r.usage.reasoning))).padStart(11) +
        fmt(avg(r => r.cost)).padStart(12) +
        pct(q.filter(r => r.quality.is_readable).length, q.length).padStart(9) +
        pct(q.filter(r => r.quality.option_count >= 4).length, q.length).padStart(7) +
        pct(q.filter(r => r.quality.konu_valid).length, q.length).padStart(7) +
        String(Math.round(avg(r => r.ms))).padStart(6)
      );
    }

    // Kontrol ile aynı fotoğrafta bayrak/şık uyuşmazlığı — kalite riskinin asıl ölçüsü.
    console.log('\nKONTROLLE UYUŞMA (aynı fotoğraf, gpt-4o-mini@1600 referans)');
    console.log('─'.repeat(104));
    for (const [k, g] of groups) {
      if (k.startsWith('kontrol@1600')) continue;
      const cmp = g.filter(r => r.ok && r.quality && controlBy.has(r.file));
      if (cmp.length === 0) continue;
      const sameFlags = cmp.filter(r => {
        const c = controlBy.get(r.file);
        return c.is_readable === r.quality.is_readable &&
               c.has_question === r.quality.has_question &&
               c.has_options === r.quality.has_options;
      }).length;
      const sameOpts = cmp.filter(r => controlBy.get(r.file).option_labels === r.quality.option_labels).length;
      const sameDers = cmp.filter(r => controlBy.get(r.file).ders === r.quality.ders).length;
      console.log(`${k.padEnd(20)} bayraklar ${pct(sameFlags, cmp.length).padStart(5)}   şık harfleri ${pct(sameOpts, cmp.length).padStart(5)}   ders ${pct(sameDers, cmp.length).padStart(5)}`);
    }

    const truncated = rows.filter(r => r.finish === 'length');
    const failed = rows.filter(r => !r.ok);
    const noEffort = rows.filter(r => r.effortSupported === false);
    console.log('');
    if (noEffort.length) console.log(`\x1b[33m! reasoning_effort kabul edilmedi (${noEffort.length} çağrı) — luna maliyeti reasoning token'ı İÇERİYOR.\x1b[0m`);
    if (truncated.length) console.log(`\x1b[33m! ${truncated.length} yanıt max_completion_tokens=${MAX_COMPLETION_TOKENS} sınırında kesildi — sınır yükseltilmeli.\x1b[0m`);
    if (failed.length) console.log(`\x1b[31m! ${failed.length} çağrı başarısız (ilk: ${failed[0].status} ${failed[0].error?.slice(0, 120)})\x1b[0m`);

    const totalCost = rows.reduce((s, r) => s + (r.cost ?? 0), 0);
    console.log(`\nBu koşumun OpenAI maliyeti: $${totalCost.toFixed(4)}`);
    console.log(`Ham sonuçlar: ${out}`);
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
}

await main();
