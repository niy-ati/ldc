# Liquidity Terminal — Data Pipeline Mapping Report

Protocol-by-protocol field mapping: **source field → transformed field → rendered field**.

Pipeline entry points:
- `packages/command-center/src/lib/deepbookIndexer.ts` — DeepBook CLOB
- `packages/command-center/src/lib/liquidityTerminalData.ts` — DefiLlama yields
- `packages/command-center/src/hooks/useLiquidityTerminal.ts` — merge, rank, render
- `packages/command-center/src/components/SuiMarketTerminal.tsx` — UI table

DEV logging: `[liquidity-terminal] pipeline` in browser console when `import.meta.env.DEV`.

---

## DeepBook (CLOB)

| Source API | Source field | Transform | Rendered column | UNAVAILABLE when |
|------------|--------------|-----------|-----------------|------------------|
| DeepBook indexer | `poolName`, trades | `deepBookRows[].label` | Pool | Never if pool list loads |
| DeepBook ticker | `quoteVolume` | `volume24hUsd` | Volume | No ticker for pool |
| DeepBook trades | trade fees | `averageTradeFees()` → `feesUsd` | Fees | Active pool only; no trades |
| — | — | — | APR | Always UNAVAILABLE (CLOB has no yield) |
| Order book | bid/ask qty × last price | `liquidityUsd` | Liquidity | Non-active pools or no book |
| Order book | `estimateSlippageFromBook` | `slippagePct` | Slippage | Active pool only |
| Order book | `orderBookDepth` | `depthBid` / `depthAsk` | Depth | Active pool only |
| — | — | — | Risk / Treasury | Not scored for CLOB |
| Static | — | `dataSource: deepbook-indexer` | Source | Indexer unreachable |

---

## Navi (Lending)

| Source API | Source field | Transform | Rendered column | UNAVAILABLE when |
|------------|--------------|-----------|-----------------|------------------|
| DefiLlama `/pools` | `project` contains `navi`, `tvlUsd` | sum → `tvlUsd` | TVL | No Sui pools matching `navi` |
| DefiLlama | `volumeUsd1d`, `volumeUsd7d` | sum / 7d÷7 fallback → `volume24hUsd` | Volume | All matching pools lack volume fields |
| DefiLlama | — | `feesUsd: null` | Fees | **Honest UNAVAILABLE** — yields API has no fee field |
| DefiLlama | `apy`, `apyBase`+`apyReward`, `apyMean30d` | `resolveDefiLlamaApr()` TVL-weighted → `aprPct` | APR | No APY on any matching pool |
| DefiLlama | aggregate TVL | `liquidityUsd = tvlUsd` | Liquidity | No TVL |
| SDK yields rank | `buildProtocolMetricsFromPools` | `riskScore`, treasury composite | Risk / Treasury | No mandate view or no DefiLlama match |
| App route | `/app/navi-capital` | `deployPath` | Deploy link | Always wired |
| DefiLlama | `project` | `dataSource: defillama` | Source | Fetch failure |

**On-chain (capital desk, not terminal table):** `fetchNaviPositions` → supplied SUI, pool APY via Navi RPC.

---

## Scallop (Lending)

Same DefiLlama pipeline as Navi with `defillamaMatch: ['scallop']`.

| Rendered | Mapping notes |
|----------|---------------|
| TVL | Sum of all Scallop Sui pools on DefiLlama |
| APR | TVL-weighted `resolveDefiLlamaApr` across pools |
| Fees | UNAVAILABLE (API limitation) |
| Liquidity | Proxied as aggregate TVL |
| Deploy | `/app/scallop-capital` |

---

## Cetus (LP)

| Source | Field | Transform | Rendered |
|--------|-------|-----------|----------|
| DefiLlama | `project` contains `cetus` | aggregate | TVL, Volume, APR, Liquidity |
| App | — | `deployPath: /app/cetus-capital` | Deploy |

---

## Turbos, Magma, Bluefin (LP)

| Protocol | DefiLlama match | Deploy PTB | Notes |
|----------|-----------------|------------|-------|
| Turbos | `turbos` | Not wired | Terminal discovery only |
| Magma | — | **Removed** | No DefiLlama Sui pools (audit 2026-06-21) |
| Bluefin | `bluefin` | Not wired | Terminal discovery only |

---

## Treasury ranking overlay

When a mandate `view` exists:

1. DefiLlama Sui pools → `buildProtocolMetricsFromPools()`
2. `rankProtocolsForTreasury(metrics, view)` → `protocolRank`
3. Merged into terminal rows: `yieldRank`, `riskScore`, `treasuryScore`, fallback `aprPct`

Sort order: `treasuryScore ?? aprPct` descending.

---

## Fields that should remain UNAVAILABLE

| Field | Reason |
|-------|--------|
| Fees (DefiLlama protocols) | Yields API does not expose protocol fees |
| APR (DeepBook) | CLOB — no lending/LP yield |
| Slippage / Depth (non-active DeepBook row) | Requires order book for that pool |
| Deploy (Turbos/Magma/Bluefin) | PTB not wired in command center |

---

## Verification checklist

1. Open Liquidity Terminal → Refresh feeds
2. DEV console: inspect `[liquidity-terminal] pipeline` for per-protocol `aprPct`, `tvlUsd`, `mappingNotes`
3. Confirm Navi/Scallop/Cetus rows show APR when DefiLlama returns `apy` or `apyBase`
4. Confirm Fees shows UNAVAILABLE for lending/LP (not a regression)
5. Capital desks show protocol TVL/APY from same DefiLlama feed + on-chain position after deposit
