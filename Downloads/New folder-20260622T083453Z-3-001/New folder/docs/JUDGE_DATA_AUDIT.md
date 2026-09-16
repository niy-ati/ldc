# Judge Data Audit — TITAN MandateOS Command Center

Complete authenticity registry for judge-facing dashboards. Every number should trace to a real source.

**In-app:** `/judge-audit` (sidebar → Judge Data Audit)

---

## Source taxonomy

| Source | Meaning |
|--------|---------|
| **On-chain** | Sui object fields, package events, or wallet RPC (`getBalance`, `getOwnedObjects`) |
| **External API** | CoinGecko (markets/OHLC), DefiLlama (Sui yields) |
| **Derived** | SDK formulas on on-chain or API inputs — includes **visual market models** (order book, tape) |
| **Demo** | `VITE_DEMO_MODE=true` offline fixtures, or what-if sliders (not executed on-chain) |

When `VITE_DEMO_MODE=false` and a wallet is connected, wallet-scoped metrics use live RPC. Demo mode replaces on-chain/derived mandate inputs with fixtures — those rows show **Demo** in `/judge-audit`.

---

## Refresh frequencies (global)

| Data plane | Refresh |
|------------|---------|
| Mandate view (vault, obligations, risk, guardian) | Initial `MandateOSReader.fetchMandateView`; then package event WS + **30s** audit poll → `refreshMandate()` |
| Connected wallet balance / owned objects | **60s** (React Query via dapp-kit) |
| CoinGecko spot (Portfolio SUI USD) | **60s** (`useMarketData`) |
| CoinGecko catalog (Market Terminal) | **120s** poll + **10min** localStorage cache |
| DefiLlama Sui yields (Yield Hub, Capital rebalance) | On mount + **5min** sessionStorage cache |
| User sliders (yield %, risk alert, allocation sim) | On interaction only |

---

## Fallback behavior (global)

| Condition | Behavior |
|-----------|----------|
| Demo mode / live fetch failure | Offline mandate fixture (`loadDemo()`) |
| CoinGecko rate limit / error | Keep last good fetch; else `FALLBACK_DATA` / `MARKET_SEED_CATALOG` |
| DefiLlama error | SDK **estimated** protocol metrics (`buildProtocolMetricsFromPools([])`) |
| Wallet disconnected | Wallet rows **0** or hidden; treasury-only metrics still from vault |
| Market depth / tape | **Simulated** from CoinGecko price/volume — not live exchange feeds |

---

## Summary counts

| Source | Metrics |
|--------|--------:|
| On-chain | 18 |
| External API | 9 |
| Derived | 49 |
| Demo | 2 |

**Total:** 78 metrics indexed in `metricAuditRegistry.ts`.

---

## Pages covered

1. **Treasury** — KPIs, allocation, obligations, positions, receipts, sankey  
2. **Portfolio** — KPIs, holdings, charts, SUI USD  
3. **Yield Hub** — Protocol APY/TVL, allocation engine, deployment simulation  
4. **Risk** — Dynamic budget, inputs, governance, alert slider (demo)  
5. **Guardian** — Status, alerts, monitors, rules  
6. **Capital Analytics** — Scores, health twin, forecast, rebalance, zones, sankey  
7. **Market Terminal** — Screener, quote, depth (simulated), tape (simulated), technicals, treasury context  

---

## Judging note

- **Order book / Time & Sales** in Market Terminal are **derived visual models**, not exchange L2 or live tape.  
- **Yield Hub deployment plan** and **Risk alert slider** are **demo/simulation** — never auto-executed.  
- **Unrealized yield** in Portfolio is **0 by design** until position-level chain reads exist.  

Wallet connectivity is documented separately; this audit covers **data honesty only**.

---

## Code references

| Artifact | Path |
|----------|------|
| Registry | `packages/command-center/src/lib/metricAuditRegistry.ts` |
| Refresh/fallback constants | `packages/command-center/src/lib/metricAuditConstants.ts` |
| UI | `packages/command-center/src/pages/JudgeDataAuditPage.tsx` |
