# TITAN Component Data Audit

Audit date: 2025-06-19  
Scope: `packages/command-center` — all user-facing pages and major widgets.

Legend:
- **Stub?** — Yes if value was synthetic, estimated, or fallback before this audit.
- **Keep/Remove** — Current disposition after audit.

| Component | Real Source | Stub? | Keep/Remove | Reason |
|-----------|-------------|-------|-------------|--------|
| Command Hub (Markets tile) | Route `/app/markets` | No | Keep | Active desk with live CoinGecko path |
| Command Hub (Yields tile) | Route `/app/yield-hub` | Partial | Keep | DefiLlama when available; mandate metrics need live view |
| Command Hub (Treasury tile) | — | Yes | Remove (hidden) | Desk hidden until full on-chain implementation |
| Command Hub (Operations tile) | — | Yes | Remove (hidden) | Desk hidden until execution/audit fully live |
| Left nav — Hub / Judge / Markets / Yield | React Router | No | Keep | Sub-links mirror hub quick access |
| Left nav — Treasury / Operations | — | Yes | Remove | Removed from sidebar |
| Top wallet bar (Slush + email) | Wallet Standard + localStorage onboarding | No | Keep | Moved from sidebar footer to horizontal top bar |
| Market Terminal — screener | CoinGecko `/api/coingecko` proxy | No | Keep | Live or stale cache only; seed catalog removed |
| Market Terminal — global breadth | CoinGecko global + catalog aggregation | Partial | Keep | BTC/ETH dom from API; adv/dec from catalog |
| Market Terminal — Fear & Greed | Invented formula | Yes | Remove | Removed — not from external index |
| Market Terminal — bid/ask/turnover | Simulated from last price | Yes | Remove | Shows **Data unavailable** |
| Market Terminal — order book | `buildOrderBook()` volume-derived | Yes | Remove | Panel removed |
| Market Terminal — time & sales | `buildTimeAndSales()` sparkline | Yes | Remove | Panel removed |
| Market Terminal — screener risk/liquidity/treasury cols | Heuristic scores in `useMarketCatalog` | Yes | Remove | Columns removed from table |
| Market Terminal — treasury context strip | `getAssetTreasuryContext()` | Yes | Remove | Fake suitability/risk/rec scores |
| Market Terminal — technicals | CoinGecko 7d sparkline + documented formulas | No | Keep | Derived from real sparkline; labeled Derived |
| Market Terminal — OHLC chart | CoinGecko OHLC or sparkline | No | Keep | Source badge on chart |
| Portfolio page | `buildPortfolioView` + wallet RPC | Partial | Keep | Wrapped in `MandateViewGate`; unavailable without live mandate |
| Trade page | DeepBook / wallet (varies) | Partial | Keep | Requires review per action button |
| Yield Hub — protocol APY/TVL | DefiLlama `yields.llama.fi/pools` | No | Keep | Empty when fetch fails (no estimated pools) |
| Yield Hub — Health Score | MAGMA composite | Yes | Keep (labeled) | Shown only with live mandate; derived advisory |
| Yield Hub — Generate Allocation Plan | Client-side proposal | N/A | Keep | Proposal mode (no on-chain tx) |
| Yield Hub — Apply Mandate Recommendation | Slider state only | N/A | Keep | Proposal mode |
| Treasury Account | MandateOSReader vault graph | No | Remove (hidden) | Route → Desk unavailable page |
| Obligations / Capital / Guardian / Risk / Position | Mandate view SDK builders | Partial | Remove (hidden) | Hidden until live mandate guaranteed |
| Agents / Trace / Audit / Templates | Mandate events + demo trace | Partial | Remove (hidden) | Operations desk hidden |
| Mission Control / Routes / Protection | Mandate overview | Partial | Remove (hidden) | Execution desk hidden |
| Objectives / Scenarios / Ecosystem | Governance overlays | Partial | Remove (hidden) | Governance desk hidden |
| Judge Data Audit | `metricAuditRegistry.ts` (78 rows) | No | Keep | Source/origin/refresh/fallback registry |
| Judge Demo (`/demo`) | On-chain tx proofs + lifecycle | No | Keep | Explicit simulation / live tx path |
| Proof Center | `txProofs` localStorage + chain digests | No | Keep | Real proofs when wallet signs |
| Mandate bootstrap | Sui RPC `MandateOSReader` | No | Keep | No auto-demo; fails → Data unavailable |
| `useMarketData` fallback | Hardcoded BTC/SUI prices | Yes | Remove | Fallback array deleted |
| CoinGecko seed catalog | `MARKET_SEED_CATALOG` | Yes | Remove | Returns empty + unavailable |
| DefiLlama estimated pools | `buildProtocolMetricsFromPools([])` | Yes | Remove | Returns empty when API fails |

## Metric display contract (post-audit)

Every live metric block should use `MetricProvenance`:

1. **Exact source** — badge + origin string  
2. **Last update timestamp** — ISO/local from fetch or `lastSyncMs`  
3. **Live status** — `live` · `stale` · `cached` · `unavailable` · `simulation`

When data cannot be loaded: show **Data unavailable** (never invent a number).

## UI changes (same audit)

| Issue | Fix |
|-------|-----|
| Treasury/Operations blank pages | Routes show `DeskUnavailablePage`; mandate pages use `MandateViewGate` |
| Missing sidebar sub-pages | Nav sections list all sub-routes under Markets / Yield / Judge |
| Black text on black background | Global rule: inputs/tables use `var(--text)` |
| Wallet/email in sidebar footer | Moved to top `wallet-top-bar` |
| Market terminal horizontal cram | `market-terminal-vertical` — single column scroll stack |

## Re-enabling hidden desks

To restore Treasury or Operations:

1. Ensure `VITE_MANDATEOS_*` env resolves a live mandate on production.  
2. Remove route entries in `App.tsx` that point to `DeskUnavailablePage`.  
3. Re-add nav sections in `Layout.tsx`.  
4. Confirm every metric in `metricAuditRegistry.ts` has `fallback: show unavailable` not demo fixture.

See also: [JUDGE_DATA_AUDIT.md](./JUDGE_DATA_AUDIT.md)
