#!/usr/bin/env node
/**
 * Liquidity Terminal data pipeline audit — run from repo root.
 * Usage: node scripts/audit-liquidity-terminal.mjs [baseUrl]
 * Default baseUrl: production app (tests proxied /api/* routes)
 */

const BASE = process.argv[2] ?? 'https://command-center-five-eta-sandy.vercel.app';
const DEFILLAMA_DIRECT = 'https://yields.llama.fi/pools';
const DEEPBOOK_DIRECT = 'https://deepbook-indexer.mainnet.mystenlabs.com';

const PROTOCOLS = [
  { id: 'navi', match: ['navi'], type: 'Lending' },
  { id: 'scallop', match: ['scallop'], type: 'Lending' },
  { id: 'cetus', match: ['cetus', 'cetus-clmm'], type: 'LP' },
  { id: 'turbos', match: ['turbos'], type: 'LP' },
  { id: 'bluefin', match: ['bluefin'], type: 'LP' },
];

function matches(project, patterns) {
  const p = (project ?? '').toLowerCase();
  return patterns.some((m) => p.includes(m));
}

async function probe(label, url) {
  const entry = { label, url, ok: false, status: null, records: 0, preview: '', errors: [] };
  try {
    const res = await fetch(url);
    entry.status = res.status;
    entry.ok = res.ok;
    const text = await res.text();
    try {
      const json = JSON.parse(text);
      if (Array.isArray(json)) {
        entry.records = json.length;
        entry.preview = JSON.stringify(json[0] ?? {}).slice(0, 180);
      } else if (json?.data && Array.isArray(json.data)) {
        entry.records = json.data.length;
        entry.preview = JSON.stringify(json.data[0] ?? {}).slice(0, 180);
      } else {
        entry.records = Object.keys(json).length;
        entry.preview = JSON.stringify(json).slice(0, 180);
      }
    } catch {
      entry.errors.push('Invalid JSON');
      entry.preview = text.slice(0, 120);
    }
  } catch (e) {
    entry.errors.push(e instanceof Error ? e.message : String(e));
  }
  return entry;
}

async function main() {
  console.log(`\n=== Liquidity Terminal Pipeline Audit ===`);
  console.log(`Base URL: ${BASE}\n`);

  const results = [];

  results.push(await probe('DefiLlama direct', DEFILLAMA_DIRECT));
  results.push(await probe('DefiLlama proxy', `${BASE}/api/defillama/pools`));
  results.push(await probe('DeepBook get_pools direct', `${DEEPBOOK_DIRECT}/get_pools`));
  results.push(await probe('DeepBook get_pools proxy', `${BASE}/api/deepbook/get_pools`));
  results.push(await probe('DeepBook ticker proxy', `${BASE}/api/deepbook/ticker`));
  results.push(await probe('DeepBook orderbook proxy', `${BASE}/api/deepbook/orderbook/SUI_USDC?level=2&depth=20`));

  let suiPools = [];
  try {
    const r = await fetch(DEFILLAMA_DIRECT);
    const j = await r.json();
    suiPools = (j.data ?? []).filter((p) => p.chain === 'Sui' && (p.tvlUsd ?? 0) > 0);
  } catch (e) {
    console.error('Failed to load Sui pools for protocol counts', e);
  }

  console.log('\n--- Endpoint probes ---');
  for (const r of results) {
    console.log(`${r.ok ? 'OK' : 'FAIL'} ${r.label}`);
    console.log(`  URL: ${r.url}`);
    console.log(`  HTTP: ${r.status}  records: ${r.records}`);
    if (r.errors.length) console.log(`  errors: ${r.errors.join('; ')}`);
    console.log(`  preview: ${r.preview}\n`);
  }

  console.log('--- Protocol match counts (DefiLlama Sui, TVL>0) ---');
  let lending = 0;
  let lp = 0;
  for (const proto of PROTOCOLS) {
    const count = suiPools.filter((p) => matches(p.project, proto.match)).length;
    const rendered = Math.min(4, count);
    if (proto.type === 'Lending') lending += rendered;
    else lp += rendered;
    console.log(`${proto.id}: ${count} pools → up to ${rendered} rendered (${proto.type})`);
  }
  console.log(`magma: REMOVED — 0 DefiLlama Sui pools`);
  console.log(`\nExpected terminal rows: lending=${lending}, lp=${lp}, clob=10 (DeepBook)`);

  const proxyDefi = results.find((r) => r.label.includes('DefiLlama proxy'));
  const proxyDb = results.find((r) => r.label.includes('get_pools proxy'));
  if (!proxyDefi?.ok) {
    console.error('\nACTION: DefiLlama proxy failed — add /api/defillama rewrite to vercel.json + vite.config.ts');
  }
  if (!proxyDb?.ok) {
    console.error('\nACTION: DeepBook proxy failed — add /api/deepbook rewrite to packages/command-center/vercel.json');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
