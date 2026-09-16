# Liquidity Terminal — Field Availability Audit

Protocol-specific views. Columns removed when not applicable (shown as `—` only when field applies but upstream empty).

Refresh interval: **45s** (`useLiquidityTerminal`).

---

## Ecosystem overview strip

| Metric | Source | Endpoint | Unavailable when |
|--------|--------|----------|------------------|
| Total TVL | DefiLlama | `GET https://yields.llama.fi/pools` → sum `tvlUsd` where `chain=Sui` | No Sui pools |
| 24h Volume | DefiLlama | same → `volumeUsd1d` or `volumeUsd7d/7` | No volume fields on pools |
| Avg APR | DefiLlama | TVL-weighted `apy` / `apyBase+apyReward` / `apyMean30d` | No APY on any pool |
| Total Fees 24h | DeepBook | `/api/deepbook/trades/{pool}` → sum `taker_fee+maker_fee` | No trades in window |
| Active pools | Derived | DefiLlama active count + DeepBook pool list length | Never if feeds OK |

Trend % on overview: **only** when comparing real fields (`volumeUsd1d` vs 7d avg; current APR vs `apyMean30d`).

---

## Lending (Navi, Scallop)

| Field | Source | Endpoint / field | Not shown / — when |
|-------|--------|------------------|---------------------|
| TVL | DefiLlama | `tvlUsd` | Pool missing |
| Supply APY | DefiLlama | `apy`, `apyBase+apyReward`, `apyMean30d` | No APY fields |
| Borrow APY | DefiLlama | `apyBaseBorrow` | **Protocol does not expose on yields API** → "Not in feed" |
| Utilization | DefiLlama | `totalBorrowUsd / totalSupplyUsd` | Missing borrow/supply fields |
| Volume | DefiLlama | `volumeUsd1d` | Missing |
| Fees | **Column removed** | Yields API has no fee field | N/A for lending |
| Depth / Slippage | **Column removed** | Not applicable to lending | N/A |
| Trend sparkline | DefiLlama | Points: `apyMean30d`, `apyBase7d`, current APY | <2 real points → — |

---

## LP (Cetus, Turbos, Magma, Bluefin)

| Field | Source | Endpoint / field | Not shown when |
|-------|--------|------------------|----------------|
| TVL | DefiLlama | `tvlUsd` | Missing |
| APR | DefiLlama | `resolveDefiLlamaApr()` | Missing |
| Volume | DefiLlama | `volumeUsd1d` | Missing |
| Fees | **Column removed** | Not in yields API | N/A |
| Borrow / Util | **Column removed** | N/A for LP | N/A |

Deploy PTB: wired for **Navi, Scallop, Cetus** only (`deployPath` set).

---

## DeepBook CLOB

| Field | Source | Endpoint | Not shown when |
|-------|--------|----------|----------------|
| Last price | DeepBook | `/api/deepbook/ticker` | Ticker down |
| Spread | Derived | Order book best bid/ask | Pool not selected / no book |
| Depth | Derived | Sum top 10 bid/ask qty | Pool not selected |
| Slippage | Derived | `estimateSlippageFromBook()` | Pool not selected |
| Volume 24h | DeepBook | `/historical_volume` or ticker `quoteVolume` | Missing |
| TVL / APR | **Column removed** | Not applicable to CLOB | N/A |

---

## Wallet / treasury (detail panel)

| Field | Source | Refresh |
|-------|--------|---------|
| Wallet SUI | Sui RPC via dapp-kit | 30–60s |
| Treasury liquid | Mandate view (on-chain read) | On mandate load |
| Positions | `fetchAllProtocolPositions` | 45s with terminal |

---

## Verification

1. DEV console: `[liquidity-terminal] refresh`
2. Network tab: `yields.llama.fi/pools`, `/api/deepbook/*`
3. Proof Center after deploy: digest + RPC verify

No synthetic charts. Sparklines and APY bars use **only** DefiLlama historical APY fields when ≥2 points exist.
