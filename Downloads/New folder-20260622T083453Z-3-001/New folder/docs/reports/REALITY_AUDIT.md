# TITAN Reality Audit

**Audited:** 2026-06-20  
**Network:** Sui testnet  
**Package:** `0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713`  
**Production:** https://command-center-five-eta.vercel.app  

## Executive summary

| Phase | Status | Blocker |
|-------|--------|---------|
| 1 — Move upgrade | **BLOCKED** | Governor `0xd0de6a0…` has **0.546 SUI**; upgrade needs **0.646 SUI** (~**0.10 SUI** short). Slush wallet has **~5.5 SUI** available to fund. |
| 2 — Wallet isolation | **DONE (code)** | Pending on-chain Create Treasury + Vercel env cleanup |
| 3 — Treasury engine | **DONE (code)** | Metrics from `MandateOSReader` when treasury exists |
| 4 — Portfolio | **PARTIAL** | Wallet RPC fallback works; full engine needs synced mandate view |
| 5 — Proof system | **DONE (code)** | Real digests via `sui_getTransactionBlock`; chain timestamps |
| 6 — Obligations | **PARTIAL** | Register via PTB; read from obligation registry on-chain |
| 7 — Programmable payments | **PARTIAL** | Treasury simulate/execute + workflow PTBs exist |
| 8 — Flagship PTB flow | **PARTIAL** | Revenue / Investment / Payroll pages have real PTB builders |
| 9 — DeFi integrations | **PARTIAL** | DefiLlama/CoinGecko only; no on-chain deposit without protocol PTB |
| 10 — Agents | **PARTIAL** | Agents page wired to simulate/execute/delegate PTBs |
| 11 — Analytics | **PARTIAL** | Scores derived from mandate view when loaded; no demo on prod routes |
| 12 — Markets | **PARTIAL** | CoinGecko catalog; shows unavailable when API fails (no seed catalog) |
| 13 — UI audit | **PARTIAL** | Dark theme tokens applied; recharts use CSS vars |
| 14 — This document | **DONE** | — |

### Immediate action (Phase 1)

Send **~0.15 SUI** from Slush (`0xf6472…`) to governor:

```
0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b
```

Then run:

```powershell
npm run testnet:reality-audit
```

---

## Page-by-page audit

| Page / Route | Feature | Real? | Source | RPC / API | Tx Proof | Fallback Exists? |
|--------------|---------|-------|--------|-----------|----------|------------------|
| `/app/account` | Create Treasury | **Pending upgrade** | Move PTB | Wallet sign | Yes | NO (blocked on-chain) |
| `/app/account` | KPIs (assets, liquidity, runway) | Yes* | MandateOSReader | multiGetObjects | N/A | NO* |
| `/app/account` | Obligations table | Yes* | Obligation registry | on-chain fields | N/A | NO* |
| `/app/account` | Execution receipts | Yes | Package events + txProofs | sui_getTransactionBlock | Yes | NO |
| `/app/portfolio` | Wallet SUI / owned counts | Yes | useAuth | getBalance, getOwnedObjects | N/A | NO |
| `/app/portfolio` | Holdings / PnL / Sharpe | Yes* | buildPortfolioView | vault + wallet + CoinGecko | N/A | NO* |
| `/app/portfolio` | Pre-treasury state | Yes | Wallet RPC only | getBalance | N/A | NO |
| `/proof` | Verified transactions | Yes | txProofs store | sui_getTransactionBlock | Yes | NO |
| `/proof` | Mandate / vault refs | Yes | Wallet treasuryGraph | discoverWalletTreasury | N/A | NO |
| `/app/payroll` | Create / simulate / execute | Yes* | usePtbWorkflows | PTB + wallet | Yes | NO* |
| `/app/subscriptions` | Create / charge | Yes* | usePtbWorkflows | PTB + wallet | Yes | NO* |
| `/app/revenue` | Allocate / distribute | Yes* | usePtbWorkflows | PTB + wallet | Yes | NO* |
| `/app/yield-hub` | Investment mandate | Yes* | usePtbWorkflows | PTB + wallet | Yes | NO* |
| `/app/yield-hub` | Protocol deposit buttons | **No** | Advisory only | DefiLlama read | N/A | Disabled (no simulate) |
| `/app/guardian-actions` | Guardian PTB | Yes* | usePtbWorkflows | PTB + wallet | Yes | NO* |
| `/app/markets` | Asset catalog | Yes** | CoinGecko | /api/coingecko | N/A | NO** |
| `/agents` | Agent cards | Yes* | buildAgentOperationsView | audit events | N/A | NO* |
| `/agents` | Execute / simulate | Yes* | TreasuryExecutionPanel | PTB | Yes | NO* |
| `/capital`, `/risk`, `/position` | Scores | Yes* | SDK derived | mandate view | N/A | NO* |
| `/protection` | DeepBook intel | Partial | SDK + forecast objects | on-chain + API | N/A | Partial |
| `/demo`, `/scenarios` | Full judge flow | **Sandbox** | demoState fixtures | N/A | Fake digests | **YES (isolated)** |
| `/hub` | Desk mockups | **No** | DeskMockups.tsx | N/A | N/A | **YES (visual only)** |

\* Requires connected wallet + created treasury mandate (post-upgrade).  
\** Shows "unavailable" when CoinGecko fails; no synthetic seed catalog.

---

## Shared-state remediation (completed)

| Issue | Fix |
|-------|-----|
| Global `localStorage` treasury copied to all wallets | Purged `mandateos-tx-proofs`, `mandateos-workflow-graphs` on sync |
| Wallet-scoped storage | `mandateos-wallet-state:{address}` |
| Env mandate ID fallbacks | Removed from `config.ts` and `.env.production` |
| NetworkStatusBar / ProofCenter env IDs | Use `treasuryGraph` / `view` only |
| Chain discovery | `discoverWalletTreasury()` per wallet on connect |
| Fake activity digests | Filter `isRealTxDigest()` |
| Cross-wallet tx proofs | Filter by `proof.wallet === activeWallet` |

---

## Remaining demo / mock inventory (must stay isolated or be removed)

| Component | Location | Production impact |
|-----------|----------|---------------------|
| `demoState.ts`, `demoScenario.ts` | `/demo`, `/scenarios` only | Isolated — OK if routes labeled Sandbox |
| `DeskMockups.tsx` | `/hub` landing | Visual only — not financial data |
| `buildDemoExecutionTrace` | SDK | Used only in demo routes |
| `metricSourceForDemoMode` | All pages | Inert when `demoMode=false` |
| `CapitalDeploymentPanel` simulation rows | Yield Hub | Marked simulation — not executed |
| `ScenarioLabPage` | `/scenarios` | Isolated sandbox |

**Remove from production path:** Any use of `loadDemo()` outside `/demo` and `/scenarios` — already enforced in `useMandateBootstrap.ts`.

---

## Final acceptance test (12 steps)

| # | Step | Status |
|---|------|--------|
| 1 | Connect Slush | Ready |
| 2 | Create Treasury | **Blocked** — Move upgrade + ~0.10 SUI |
| 3 | Fund Treasury | Ready after #2 |
| 4 | Create Obligation | Ready after #2 |
| 5 | Execute Payment | Ready after #2 |
| 6 | Execute Payroll | PTB page ready after #2 |
| 7 | Generate Receipt | txProofs + Proof Center |
| 8 | Explorer proof | ObjectLink + explorerUrl |
| 9 | Updated Treasury | refreshMandate after tx |
| 10 | Updated Portfolio | buildPortfolioView after sync |
| 11 | Programmable money flow | Revenue / Investment PTBs |
| 12 | Verify object changes on-chain | TxProofCard affectedObjects |

---

## Verification commands

```powershell
# After governor >= 0.646 SUI
npm run testnet:reality-audit

# Manual upgrade
npm run testnet:upgrade
```

Outputs: `proof/deployment.json`, `proof/reality-audit.json`, `proof/upgrade-result.json`.
