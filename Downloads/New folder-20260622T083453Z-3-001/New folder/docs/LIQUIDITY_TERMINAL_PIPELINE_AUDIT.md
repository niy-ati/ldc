# Liquidity Terminal — Data Pipeline Audit

> Audit date: 2026-06-21  
> Script: `node scripts/audit-liquidity-terminal.mjs [baseUrl]`  
> Console: filter browser DevTools by `[liquidity-terminal]`

## Executive Summary

The terminal showed **External API Unavailable**, empty lending/LP tables, and **DeepBook pools unavailable** when the refresh pipeline produced **zero rows**. APIs themselves are healthy when probed directly. Root causes were **pipeline fragility** (uncaught refresh errors, missing deploy proxies, broken volume mapping), not absent upstream data.

| Symptom | Root cause | Fix applied |
|---------|------------|-------------|
| External API Unavailable | `MetricProvenance` used filtered row count; empty `rows` after failed refresh | Status uses `dataLive` (`allRows.length > 0`); refresh wrapped in try/catch with partial recovery |
| No lending/LP pools | DefiLlama fetch returned `[]` on error with no fallback logging | Proxy + direct fallback fetch; schema validation + console diagnostics |
| DeepBook pools unavailable | `/api/deepbook` missing from `packages/command-center/vercel.json` on some deploys; CLOB rows only render when pool names exist | Added DeepBook + DefiLlama rewrites to both `vercel.json` files; fallback pool names; per-pool ticker mapping |
| Magma always empty | **0 Sui pools** on DefiLlama for `magma` | **Removed** from tracked protocols |
| Inflated CLOB volume | `historical_volume` returns quote volume × 1e6 | `normalizeDeepBookVolume()` divides when raw > 1e12 |

**Expected row counts after fix:** lending **8**, LP **12**, CLOB **10** (top 4 pools × 5 protocols + 10 DeepBook pools).

---

## Source-by-Source Report

### DefiLlama (Navi, Scallop, Cetus, Turbos, Bluefin)

| Field | Value |
|-------|-------|
| **Endpoint (preferred)** | `/api/defillama/pools` → `https://yields.llama.fi/pools` |
| **Endpoint (fallback)** | `https://yields.llama.fi/pools` (direct, CORS `*`) |
| **Reachable** | Yes (direct always 200; proxy 404 until next Vercel deploy) |
| **Records returned** | 16,286 total pools; **246 Sui pools with TVL > 0** |
| **Records rendered** | 20 rows (8 lending + 12 LP) |
| **Schema** | `{ data: DefiLlamaPoolRow[] }` — fields used: `chain`, `project`, `symbol`, `tvlUsd`, `apy`, `apyBase`, `apyReward`, `apyMean30d`, `apyBaseBorrow`, `volumeUsd1d`, `volumeUsd7d`, `totalSupplyUsd`, `totalBorrowUsd` |
| **Failures** | Proxy route not on current production build (404) |
| **Fixes applied** | Proxy in root + package `vercel.json`; Vite dev proxy; direct URL fallback; `fetchDefiLlamaSuiPoolRowsRaw()` with validation logging |

#### Per-protocol DefiLlama match (Sui, TVL > 0)

| Protocol | DefiLlama `project` match | Pools found | Rendered (max 4) | Deploy desk |
|----------|---------------------------|-------------|------------------|-------------|
| **Navi** | `navi`, `navi-lending` | 31 | 4 | `/app/navi-capital` |
| **Scallop** | `scallop`, `scallop-lend` | 22 | 4 | `/app/scallop-capital` |
| **Cetus** | `cetus`, `cetus-clmm` | 70 | 4 | `/app/cetus-capital` |
| **Turbos** | `turbos` | 24 | 4 | — (discover only) |
| **Bluefin** | `bluefin`, `bluefin-spot` | 51 | 4 | — (discover only) |
| **Magma** | — | **0** | **Removed** | — |

**Field mappings (lending rows):**

| UI column | Source field | Notes |
|-----------|--------------|-------|
| TVL | `tvlUsd` | Direct |
| Supply APY | `apy` → `apyBase+apyReward` → `apyMean30d` | `resolveDefiLlamaApr()` |
| Borrow APY | `apyBaseBorrow` | Often null — shows "Not in feed" |
| Utilization | `totalBorrowUsd / totalSupplyUsd` | When borrow fields present |
| Volume | `volumeUsd1d` or `volumeUsd7d/7` | Many pools lack volume — shows "—" |

**Field mappings (LP rows):**

| UI column | Source field |
|-----------|--------------|
| TVL | `tvlUsd` |
| APR | `resolveDefiLlamaApr()` |
| Volume | `volumeUsd1d` or `volumeUsd7d/7` |

**Navi / Scallop / Cetus on-chain positions** (portfolio panel, not screener rows): `@mandateos/sdk` `fetchAllProtocolPositions()` via Sui mainnet RPC when wallet connected.

---

### DeepBook (CLOB)

| Field | Value |
|-------|-------|
| **Endpoint** | `/api/deepbook/*` → `https://deepbook-indexer.mainnet.mystenlabs.com/*` |
| **Reachable** | Yes on production (200) |
| **Records returned** | 26 pools (`/get_pools`), 26 tickers (`/ticker`) |
| **Records rendered** | 10 CLOB rows (top pools by list order) |
| **Failures** | None on current production for DeepBook proxy |
| **Fixes applied** | Added proxy to `packages/command-center/vercel.json`; diagnostic logging in `deepbookIndexer.ts`; volume normalization |

#### DeepBook endpoints

| Route | Purpose | Schema OK | Rendered into |
|-------|---------|-----------|---------------|
| `GET /get_pools` | Pool list | `pool_name`, symbols | CLOB row labels |
| `GET /ticker` | Last price, 24h volume | `last_price`, `quote_volume`, `base_volume` | Last, Volume columns |
| `GET /orderbook/{pool}?level=2&depth=20` | Bids/asks | `bids[]`, `asks[]` [price, qty] | Spread, depth, slippage (selected pool) |
| `GET /trades/{pool}` | Recent trades | `taker_fee`, `maker_fee`, `price`, volumes | Fees 24h aggregate |
| `GET /historical_volume/{pools}` | 24h volume | `{ POOL: number }` | Volume (÷ 1e6 normalized) |

**Field mappings (CLOB rows):**

| UI column | Source | Notes |
|-----------|--------|-------|
| Last | `ticker[pool].lastPrice` | |
| Spread | `estimateSlippageFromBook().spreadPct` | Selected pool only |
| Depth | `orderBookDepth()` bid/ask qty sum | Selected pool only |
| Volume | `normalize(historical_volume)` or `ticker.quoteVolume` | Fixed 1e6 scale bug |
| Slippage | `estimateSlippageFromBook().priceImpactPct` | Uses `deploySizeSui` |

---

## Filter Pipeline (before vs after)

Logged on every refresh in console as `[liquidity-terminal] refresh complete`:

| Stage | Expected count |
|-------|----------------|
| Lending before filter | 8 |
| LP before filter | 12 |
| CLOB before filter | 10 |
| After default filters (`all` / `all` / no search) | Same as before |

Empty table messages (**No lending pools matched filters**, etc.) only appear when **filtered** row count is 0 — not when upstream is live but a protocol filter excludes all rows.

---

## Files Changed

| File | Change |
|------|--------|
| `src/lib/liquidityTerminalDiagnostics.ts` | New — logging, schema validation, audit types |
| `src/lib/liquidityTerminalData.ts` | Magma removed; proxy+direct DefiLlama fetch; diagnostics |
| `src/lib/deepbookIndexer.ts` | Fetch diagnostics; volume normalization |
| `src/hooks/useLiquidityTerminal.ts` | Robust refresh; audit report; `dataLive`; error recovery |
| `src/components/liquidity-terminal/LiquidityTerminalView.tsx` | Magma filter removed; status uses `dataLive` |
| `vite.config.ts` | `/api/defillama` proxy |
| `vercel.json` (root + package) | `/api/deepbook` + `/api/defillama` rewrites |
| `scripts/audit-liquidity-terminal.mjs` | CLI endpoint probe |

---

## Verification

```bash
# Endpoint probe (production)
node scripts/audit-liquidity-terminal.mjs

# Local dev (start dev server first)
npm run dev:cc
node scripts/audit-liquidity-terminal.mjs http://localhost:5173

# Browser: open /app/markets, DevTools → Console → filter [liquidity-terminal]
```

After Vercel redeploy, `/api/defillama/pools` should return 200 (currently 404 on production until deploy).

---

## What was NOT changed (per request)

- Terminal **UI styling** — no visual redesign
- Mock/seed data — still none

---

## Next step

Redeploy to Vercel so `/api/defillama` proxy is live on production. Direct DefiLlama fallback works in the interim after this code ships.
