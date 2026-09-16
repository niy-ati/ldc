# Portfolio · Yield Hub · CoinGecko Trace

Generated: 2025-06-19  
CoinGecko: **DISABLED** (`VITE_COINGECKO_ENABLED` must be `true` to enable)

---

## 1. Portfolio page — end-to-end data path

```
PortfolioPage
  └─ MandateViewGate (blocks if no view)
       └─ usePortfolioEngine(view)
            ├─ useAuth() → Sui RPC wallet
            ├─ useMarketData() → CoinGecko (disabled → empty)
            └─ buildPortfolioView() [@mandateos/sdk]
                 inputs: view.vault.*, view.risk.*, view.liquidity.*, view.activity[]
```

### Mandate load (prerequisite)

| Step | Detail |
|------|--------|
| Source endpoint | Sui fullnode `{network}` via `@mysten/sui/client` |
| On-chain query | `MandateOSReader.fetchMandateView` → `fetchMandateBundle` → multiple `client.getObject` on mandate, vault, constitution, obligations, risk profile, liquidity engine, forecast, guardian |
| Refresh | Initial bootstrap once; `useMandateEvents` poll **30s** + WebSocket `subscribeEvent` on package |
| Cache | Zustand `mandateStore.view`; `lastSyncMs` updated on setView / activity |
| Last updated | `mandateStore.lastSyncMs` |

### Wallet balance (Portfolio + top bar)

| Step | Detail |
|------|--------|
| Source endpoint | Sui RPC |
| On-chain query | `useSuiClientQuery('getBalance', { owner, coinType: '0x2::sui::SUI' })` |
| Refresh | dapp-kit React Query (default refetch on focus/reconnect) |
| Cache | React Query in-memory |
| Last updated | Not surfaced on Portfolio UI (only balance string) |

### Every displayed Portfolio metric

| UI label | Value source | Endpoint / query | Refresh | Cache | Last updated | Shows 0 when |
|----------|--------------|------------------|---------|-------|--------------|--------------|
| **Total (SUI)** | `metrics.totalValueSui` | Sum of holdings from `view.vault.*` + wallet | Mandate 30s + wallet RQ | mandateStore | `portfolio.computedAtMs` | No vault balance & wallet disconnected |
| **PnL** | `metrics.pnlSui` | `(vault + wallet) − (deposited − withdrawn)` | Recomputed each render | None | `computedAtMs` | costBasis equals current balance |
| **Daily / Weekly / Monthly %** | `deriveReturnsFromActivity` | Audit events in 1d/7d/30d windows ÷ vault balance | Activity poll 30s | mandateStore activity | `computedAtMs` | No `vault_funded` / `mandate_executed` / `vault_debited` in window |
| **Realized Yield** | Sum of execution + fulfillment events | `view.activity` filter by kind | 30s | mandateStore | `computedAtMs` | No executed/fulfilled events |
| **Sharpe** | `computeSharpe(dailyReturns)` | Last 20 activity amounts / balance | 30s | mandateStore | `computedAtMs` | **< 3 activity-derived returns** (always 0) |
| **Concentration** | `view.risk.concentrationBps / 100` | Risk profile object on-chain | Mandate refresh | mandateStore | `lastSyncMs` | Rarely 0 if risk object loaded |
| **Idle Capital** | `max(0, liquid − obligationBuffer)` | `vault.liquidMist`, `liquidity.requiredBufferMist` | Mandate refresh | mandateStore | `computedAtMs` | Liquid ≤ buffer |
| **Allocation pie** | Holdings with `valueSui > 0` | Same as holdings rows | Same | Same | `computedAtMs` | Empty pie if all zero |
| **Returns bar chart** | daily/weekly/monthly metrics | Derived | Same | Same | `computedAtMs` | All zero if no activity |

### Holdings table rows

| Row | On-chain fields | LP / stake? | Shows 0 / missing when |
|-----|-----------------|-------------|-------------------------|
| **Wallet SUI** | `getBalance` totalBalance | N/A | **Row omitted** if wallet not connected |
| **Treasury Liquid** | `vault.liquidMist` | No | Row omitted if liquid = 0 |
| **Treasury Reserved** | `vault.reserveAmountMist` | No | Row omitted if reserved = 0 |
| **Treasury Illiquid** | `balanceMist × illiquidAllocationBps` | No | Row omitted if illiquid = 0 |
| **Idle Capital** | Derived liquid − buffer | No | Row omitted if idle = 0 |
| **LP tokens** | — | **Not implemented** | Never shown |
| **Staked assets** | — | **Not implemented** | Never shown |
| **Position NFTs** | `getOwnedObjects` in useAuth only | Not in portfolio table | Count in top bar only |
| **Per-row Realized** | Activity by holding category | Derived | 0 for wallet/reserved/idle |
| **Per-row Risk / Liquidity** | Mapped from `view.risk.*` | Derived heuristics | 0 if risk profile zero |

### Not displayed but computed (always 0 today)

| Field | Reason |
|-------|--------|
| `metrics.unrealizedYieldSui` | Hardcoded `0` in SDK — no position-level yield read |
| `metrics.totalValueUsd` | `totalValueSui × suiPriceUsd`; **0 with CoinGecko off** |
| `holding.unrealizedYieldSui` | Always 0 in SDK |

---

## 2. Yield Hub — button audit

| Button | Function called | Data source | Real execution? | Simulation? | Output |
|--------|-----------------|-------------|-----------------|----------------|--------|
| Yield capital slider | `engine.setYieldCapitalPct` | Local React state | No | UI only | Updates % label & budget |
| **Generate Allocation Proposal** | `deployment.generatePlan()` → `buildCapitalDeploymentPlan(view, protocols)` | Mandate view + DefiLlama pools | **No** | **Yes** | `CapitalDeploymentPlan` panel |
| **Apply Recommendation (proposal only)** | `engine.applyRecommended()` → `equalWeight(low-risk protocols)` | Mandate `recommendYieldStrategy` + protocol list | No | Yes | Slider weights in UI |
| **Equal-weight (proposal only)** | `engine.equalWeight(compareIds)` | Selected protocol IDs | No | Yes | Equal % allocations |
| **Compare (UI)** | `toggleCompare(id)` | Local state | No | UI only | Row highlight + enables equal-weight |
| Weight % input | `engine.setAllocation(id, pct)` | Local state | No | UI only | Row weight + simulation panel |
| **Mark Plan Verified (proposal only)** | `deployment.verifyPlan()` | None — sets `verified=true` | **No** | **Yes** | Badge “Verified” (no chain tx) |
| **Clear Plan** | `deployment.clearPlan()` | Local state | No | UI only | Removes plan panel |

All Yield Hub buttons are **proposal / UI only**. None submit a PTB or sign a transaction.

---

## 3. CoinGecko disabled — what the user sees

With `coingeckoEnabled: false` (default unless `VITE_COINGECKO_ENABLED=true`):

| Page | User-visible result |
|------|---------------------|
| **Market Terminal** | Full-page **“Data unavailable”** + “CoinGecko disabled — set VITE_COINGECKO_ENABLED=true to enable” + Retry (still empty). **No** prices, gainers, losers, market caps, heatmap, or ticker. |
| **Portfolio** | If mandate loaded: SUI metrics from chain. Banner: **“CoinGecko off — USD values not shown”**. No USD column on page. |
| **Yield Hub MAGMA banner** | Still renders if mandate loaded; volatility input from DefiLlama path may use default 0.03 when no SUI market row. |
| **Top bar wallet** | Unaffected (Sui RPC). |

Stale `localStorage` catalog is **not** read when CoinGecko is disabled (hard off at fetch entry).

---

## 4. Complete TITAN component classification

| Component | Classification | Notes |
|-----------|----------------|-------|
| Command Hub (active tiles) | STATIC | Navigation only |
| Command Hub (disabled Treasury/Ops) | STATIC | “Data unavailable” label |
| Sidebar nav | STATIC | Routes |
| Top wallet bar — Slush connect | ON_CHAIN | Wallet Standard + RPC |
| Top wallet bar — email | STATIC | localStorage onboarding |
| Top wallet bar — mandate/vault counts | ON_CHAIN | `getOwnedObjects` |
| Network status bar | REAL_TIME | RPC health |
| **Market Terminal** (CoinGecko off) | STATIC | Unavailable message only |
| Market Terminal (CoinGecko on) | API_BACKED / CACHED | CoinGecko proxy; 120s catalog interval; 10min LS cache |
| Market technicals (when feed on) | API_BACKED + derived | Sparkline from CoinGecko |
| Portfolio KPIs | ON_CHAIN + derived | Vault + activity |
| Portfolio wallet row | ON_CHAIN | getBalance |
| Portfolio Sharpe / returns | derived | Activity windows |
| Portfolio USD (internal) | API_BACKED | Blocked when CoinGecko off |
| Trade page | varies | DeepBook — separate audit |
| Yield Hub — vault KPIs | ON_CHAIN | vault fields |
| Yield Hub — protocol table | API_BACKED / CACHED | DefiLlama; 5min sessionStorage |
| Yield Hub — health / MAGMA | SIMULATION | Advisory composite |
| Yield Hub — allocation simulation | SIMULATION | Labeled panel |
| Yield Hub — deployment plan | SIMULATION | No execution |
| Judge Data Audit | STATIC | Registry metadata |
| Judge Demo | ON_CHAIN + SIMULATION | Real txs when wallet signs |
| Proof Center | ON_CHAIN + STATIC | txProofs + digests |
| Desk unavailable pages | STATIC | Hidden desk message |
| MandateViewGate unavailable | STATIC | Error copy |
| Demo mandate fixtures | SIMULATION | `/demo` only |

---

## 5. Verification checklist (CoinGecko off)

- [x] No synthetic seed catalog
- [x] No cached catalog bypass when disabled
- [x] No gainers/losers/ticker/screener without API
- [x] No fake order book / tape
- [x] Portfolio shows chain SUI only
- [x] Yield buttons renamed/disabled where non-executing

Re-enable markets: set `VITE_COINGECKO_ENABLED=true` in env and redeploy.
