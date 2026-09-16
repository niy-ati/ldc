# STUB_AUDIT — Production vs Sandbox Inventory

**Audited:** 2026-06-20  
**Network:** Sui testnet  
**Package:** `0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713`

Legend: **Real** = chain or documented external API only. **Fake** = fixture, simulation, or derived model without on-chain execution. **Sandbox** = isolated to `/demo`, `/scenarios`, or labeled mock routes.

| Component | Source | Real or Fake | Replacement plan |
|-----------|--------|--------------|------------------|
| `demoState.ts` | `packages/command-center/src/demo/demoState.ts` | **Sandbox** | Keep on `/demo` only; never load on `/app/*`. Already gated in `useMandateBootstrap.ts`. |
| `demoScenario.ts` | `packages/command-center/src/demo/demoScenario.ts` | **Sandbox** | Same as demoState; `/scenarios` only. |
| `TX_*` fake digests | `demoState.ts`, `demoScenario.ts` | **Fake** | Purged from production via `isRealTxDigest()` in `mandateStore.ts`. Sandbox only. |
| `DeskMockups.tsx` | `components/hub/DeskMockups.tsx` | **Fake (visual)** | Hub/intro tiles only; APR/dollar strings removed. Replace with static “protocol · on-chain” labels or live DefiLlama badges when wired. |
| `TitanSplash.tsx` tickers | `components/TitanSplash.tsx` | **Fake (cosmetic)** | Random % moves on splash; no dollar prices. Acceptable intro animation or replace with neutral branding. |
| `CapitalDeploymentPanel.tsx` | `components/CapitalDeploymentPanel.tsx` | **Fake** | Not routed in production nav. Delete or gate behind `/scenarios` if unused. |
| `useCapitalDeployment.ts` | `hooks/useCapitalDeployment.ts` | **Fake** | Simulation plan generator. Disable any route that calls it; use investment mandate PTB only. |
| `YieldPage` strategies | `pages/YieldPage.tsx` + `buildYieldStrategies` | **Derived** | Advisory from mandate view; no deposit buttons. Add “Deploy via Investment PTB” link only. |
| `YieldTokensPage` | `pages/YieldTokensPage.tsx` + `buildYieldTokenization` | **Fake** | SDK model, not Kamo on-chain. Show `DeskUnavailablePage` or read-only badge until Kamo PTB exists. |
| `YieldHubPage` | `pages/YieldHubPage.tsx` | **Real (Move PTB)** | Create/fund/simulate/execute investment mandate via `usePtbWorkflows`. Not external DeFi deposit. |
| External protocol deposit | Navi / Scallop / Cetus buttons | **Missing** | Requires protocol-specific PTB builders + wallet sign. All such buttons must stay disabled. |
| `MarketTerminal` order book | `components/MarketTerminal.tsx` | **Derived** | Vol-derived visual model from CoinGecko; label as model not live tape. |
| `RebalancingCenter` execute | `components/RebalancingCenter.tsx` | **Disabled** | Execute button disabled; needs rebalance PTB on Move package. |
| `TreasuryAccountPage` KPIs | `pages/TreasuryAccountPage.tsx` | **Real*** | `MandateOSReader` when treasury exists; zero/empty pre-treasury. |
| `PortfolioPage` holdings | `pages/PortfolioPage.tsx` | **Real*** | Wallet RPC + mandate view; owned objects table from `getOwnedObjects`. |
| `ProofCenterPage` | `pages/ProofCenterPage.tsx` | **Real** | Wallet-scoped `txProofs`; `sui_getTransactionBlock` enrichment. |
| Shared env mandate IDs | `.env.production` | **Removed** | No `VITE_MANDATEOS_MANDATE_ID` fallbacks; per-wallet discovery only. |
| `metricSourceForDemoMode` | `lib/metricSource.ts` | **Real (prod)** | Returns live source when `demoMode=false` (default on `/app/*`). |
| `AgentsPage` simulate/execute | `pages/AgentsPage.tsx` | **Real*** | Treasury PTBs via `useMandateLifecycle`; requires treasury. |
| `GuardianActionsPage` | `pages/GuardianActionsPage.tsx` | **Real*** | `usePtbWorkflows.simulateGuardian` / execute — Move package. |
| Payroll / Subscription / Revenue | `pages/*Page.tsx` | **Real*** | Dedicated mandate PTBs per workflow graph. |
| `ScenarioLabPage` | `pages/ScenarioLabPage.tsx` | **Sandbox** | Stress scenarios with demo fixtures; keep isolated. |
| `JudgeDataAuditPage` | `pages/JudgeDataAuditPage.tsx` | **Real (meta)** | Reads `metricAuditRegistry`; marks demo when sandbox active. |
| `buildYieldTokenization` marketplace rows | `@mandateos/sdk` | **Fake** | Replace with on-chain order book or hide table. |
| `TreasuryHealthTwinPanel` | `components/TreasuryHealthTwinPanel.tsx` | **Derived** | Twin projection from mandate view; not separate chain objects. |
| `ForecastPanel` | `components/ForecastPanel.tsx` | **Derived** | Forecast object read when present; chart is advisory. |

\* **Real*** = requires connected wallet + on-chain treasury (blocked until Move upgrade + Create Treasury succeeds).

## Production routes — stub status

| Route | Stub risk | Action |
|-------|-----------|--------|
| `/app/account` | Create Treasury aborts pre-upgrade | **Blocker:** upgrade package |
| `/app/portfolio` | None when wallet connected | OK |
| `/app/yield-hub` | Investment PTB only | OK; no protocol deposit |
| `/app/yield-tokens` | Fake tokenization model | **Replace or gate** post-upgrade |
| `/yield` | Derived strategies only | OK (read-only) |
| `/hub` | Desk mockups | OK (visual, no balances) |
| `/demo`, `/scenarios` | Full fake state | OK (sandbox) |

## Removal checklist (production)

- [x] Remove shared localStorage treasury proofs
- [x] Wallet-scoped `mandateos-wallet-state:{address}`
- [x] Filter non-hex digests from proof store
- [x] Remove env mandate/vault ID fallbacks
- [x] Strip DeskMockups dollar/APR strings
- [x] Strip TitanSplash fake dollar feed lines
- [x] Disable RebalancingCenter simulated execute
- [ ] Move package upgrade on-chain
- [ ] Dual-wallet treasury audit (`npm run testnet:reality-audit`)
- [ ] Gate or replace `YieldTokensPage` synthetic marketplace
- [ ] External DeFi deposit PTBs (Navi/Scallop/Cetus)
