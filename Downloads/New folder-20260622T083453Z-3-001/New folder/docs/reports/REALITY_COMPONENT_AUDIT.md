# TITAN Reality Component Audit

**Generated:** 2026-06-20  
**Classifications:** `REAL_ONCHAIN` · `REAL_API` · `REAL_PROTOCOL` · `SIMULATION` · `MOCK` · `DEAD_UI`  
**Source of truth:** `packages/command-center/src/lib/realityClassification.ts`

No component may remain unclassified. Production routes with `SIMULATION`, `MOCK`, or `DEAD_UI` are **hidden** via `RealityRouteGate` → `DeskUnavailablePage`.

---

## Primary blocker (treasury)

| Item | Classification | Status |
|------|----------------|--------|
| Move package upgrade (`vec_map` fix) | REAL_ONCHAIN | **BLOCKED** — governor ~0.10 SUI short of upgrade gas |
| Create Treasury UI | REAL_PROTOCOL | Blocked until upgrade |
| Dual-wallet audit | REAL_ONCHAIN | Pending `npm run testnet:reality-audit` |

---

## Production routes (visible)

| Route | Key components | Classification | Data source |
|-------|----------------|----------------|-------------|
| `/hub` | HubDeskMockup tiles | MOCK (visual only) | CSS mockups — no financial values |
| `/app/markets` | MarketTerminal | REAL_API | CoinGecko when enabled; unavailable otherwise |
| `/app/portfolio` | ChainPortfolioContent | REAL_ONCHAIN | `getBalance`, vault fields, owned objects |
| `/app/account` | TreasuryAccountPage, ActivityStream | REAL_ONCHAIN | MandateOSReader, package events |
| `/obligations` | ObligationsPage | REAL_ONCHAIN | Obligation registry object |
| `/objectives` | ObjectivesPage | REAL_ONCHAIN | Mandate objective fields |
| `/app/payroll` | PtbWorkflowShell | REAL_PROTOCOL | Payroll mandate PTB |
| `/app/subscriptions` | PtbWorkflowShell | REAL_PROTOCOL | Subscription mandate PTB |
| `/app/revenue` | PtbWorkflowShell | REAL_PROTOCOL | Revenue split PTB (**Pay→Split workflow**) |
| `/app/yield-hub` | PtbWorkflowShell | REAL_PROTOCOL | Investment mandate PTB (not external DeFi) |
| `/app/guardian-actions` | Guardian step buttons | REAL_PROTOCOL | Guardian evaluate/simulate/execute PTBs |
| `/agents` | TreasuryExecutionPanel | REAL_PROTOCOL | Delegate/simulate/execute treasury PTBs |
| `/audit` | ActivityStream, OnChainRegistry | REAL_ONCHAIN | Package events + proofs |
| `/templates` | TemplatesPage deploy | REAL_PROTOCOL | createTreasury PTB per template |
| `/proof` | ProofCenterHub, TxProofCard | REAL_ONCHAIN | `sui_getTransactionBlock`, digests, object IDs |
| `/judge-audit` | JudgeDataAuditPage | REAL_ONCHAIN | Metric registry + session metadata |
| `/demo` | DemoPage wizard | REAL_ONCHAIN | Real testnet PTBs (sandbox) |

---

## Hidden from production (gate active)

| Route | Classification | Reason |
|-------|----------------|--------|
| `/app/trade` | DEAD_UI | No swap/DeepBook PTB |
| `/app/yield-tokens` | MOCK | SDK tokenization — no Kamo objects |
| `/app/advisor` | SIMULATION | Generated recommendations |
| `/app/strategies` | SIMULATION | Historical return / Sharpe not on-chain |
| `/app/liquidity` | SIMULATION | Borrow slider — no lending PTB |
| `/overview` | SIMULATION | Derived PnL, treemap |
| `/capital` | SIMULATION | Forecasts, rebalance recommendations |
| `/routes` | SIMULATION | Advisory capital routes |
| `/guardian` | SIMULATION | Derived alert monitors |
| `/risk` | SIMULATION | Generated rebalance presentation |
| `/position` | SIMULATION | Derived position risk scores |
| `/protection` | SIMULATION | DeepBook advisory model |
| `/yield` | SIMULATION | Generated expected yield % |
| `/trace` | DEAD_UI | `selectedTrace` never wired |
| `/ecosystem` | DEAD_UI | Static marketing |
| `/welcome` | DEAD_UI | Landing copy |

---

## Component-level audit

### Treasury

| Component | Source | Class | Production |
|-----------|--------|-------|------------|
| Create Treasury | `useMandateLifecycle.createTreasury` | REAL_PROTOCOL | Enabled — blocked on-chain pre-upgrade |
| Fund vault | `fundTreasury` PTB | REAL_PROTOCOL | Enabled |
| Register obligation | `registerObligation` PTB | REAL_PROTOCOL | Enabled |
| Simulate execution | `simulateExecution` PTB | REAL_PROTOCOL | Enabled — labeled "on-chain PTB" |
| Execute mandate | `executeMandate` PTB | REAL_PROTOCOL | Enabled after SimulationApproval |
| Treasury KPIs | MandateOSReader | REAL_ONCHAIN | From vault object when mandate exists |
| CapitalFlowSankey | SDK derived | SIMULATION | Hidden with `/capital` |
| RebalancingCenter execute | — | DEAD_UI | Button disabled / page hidden |

### Payments / programmable money

| Workflow | PTB path | Class | Single-PTB note |
|----------|----------|-------|-----------------|
| Revenue Split | `/app/revenue` simulate → execute | REAL_PROTOCOL | Split + distribute via mandate package |
| Payroll | `/app/payroll` | REAL_PROTOCOL | Simulate approval then execute disbursement |
| Treasury simulate/execute | TreasuryExecutionPanel | REAL_PROTOCOL | Obligation + payment flow |
| External DeFi deposit | — | DEAD_UI | No protocol PTB — all actions disabled |

### Portfolio

| Metric | Source | Class | Display rule |
|--------|--------|-------|--------------|
| Wallet SUI | `getBalance` | REAL_ONCHAIN | Shown |
| Vault balance | `view.vault.balanceMist` | REAL_ONCHAIN | Shown |
| Realized yield | `obligation.fulfilledMist` sum | REAL_ONCHAIN | Shown if > 0, else "Not available" |
| Unrealized yield | — | — | Always **"Not available"** |
| PnL / Sharpe / returns | buildPortfolioView | SIMULATION | **Removed** from production portfolio |
| Risk / liquidity scores | SDK derived | SIMULATION | **Removed** from holdings table |

### Yield

| Action | Class | Production |
|--------|-------|------------|
| Investment mandate create/fund/simulate/execute | REAL_PROTOCOL | Enabled on `/app/yield-hub` |
| Navi/Scallop/Cetus deposit | DEAD_UI | Not in nav; no PTB |
| Yield tokenization marketplace | MOCK | Route hidden |

### Markets

| Feature | Class | Rule |
|---------|-------|------|
| CoinGecko catalog | REAL_API | Shown when enabled |
| CoinGecko disabled | — | Full terminal unavailable |
| Stale cache | REAL_API | Shown with cache age + provenance banner |
| Seeded/fallback prices | — | **Never** — empty catalog if fetch fails |
| Order book / depth / tape | DEAD_UI | Removed or DataUnavailable |
| Trade execution | DEAD_UI | `/app/trade` hidden |

### Trading

| Control | Class | Production |
|---------|-------|------------|
| Buy / sell | DEAD_UI | Route hidden |
| Order book | DEAD_UI | Not rendered |

### Agents

| Action | Class | Label |
|--------|-------|-------|
| Delegate | REAL_PROTOCOL | Enabled |
| Simulate | REAL_PROTOCOL | "Simulate (on-chain PTB)" |
| Execute | REAL_PROTOCOL | "Execute (on-chain PTB)" |

### Proof Center

| Field | Source | Class |
|-------|--------|-------|
| Digest | txProofs | REAL_ONCHAIN |
| Timestamp | `sui_getTransactionBlock` | REAL_ONCHAIN |
| Owner | wallet-scoped proofs | REAL_ONCHAIN |
| Object IDs | tx objectChanges | REAL_ONCHAIN |
| Explorer links | suiscan.xyz | REAL_ONCHAIN |
| Simulations vs executions | proof.category | REAL_ONCHAIN — counts separated |

### Sandbox only

| Component | Class | Routes |
|-----------|-------|--------|
| demoState fixtures | MOCK | `/scenarios`, optional `/judge-audit` |
| TX_* digests | MOCK | Filtered from production proofs |
| ScenarioLab stress | SIMULATION | `/scenarios` |
| DemoPage PTBs | REAL_ONCHAIN | `/demo` |

---

## Final acceptance checklist

| Step | Requirement | Status |
|------|-------------|--------|
| 1 | Connect wallet | REAL_ONCHAIN — Slush/dapp-kit |
| 2 | Create treasury | **Blocked** — Move upgrade |
| 3 | Deposit funds | REAL_PROTOCOL — fund PTB ready |
| 4 | Create obligation | REAL_PROTOCOL — register PTB ready |
| 5 | Execute programmable payment | REAL_PROTOCOL — simulate + execute |
| 6 | Execute PTB workflow | REAL_PROTOCOL — revenue/payroll/etc. |
| 7 | Verify on explorer | REAL_ONCHAIN — TxProofCard links |
| 8 | Updated treasury | REAL_ONCHAIN — MandateOSReader refresh |
| 9 | Updated portfolio | REAL_ONCHAIN — chain-only view |
| 10 | Proof record | REAL_ONCHAIN — wallet-scoped store |

**Next action:** Fund governor `0xd0de6a0…` with ~0.15 SUI → `npm run testnet:reality-audit` → verify Create Treasury on production.

---

## Related docs

- `STUB_AUDIT.md` — stub inventory and removal checklist  
- `docs/SCREEN_DATA_SOURCES.md` — RPC endpoints, refresh, cache per screen  
- `FINAL_REALITY_REPORT.md` — post-audit digests and object IDs (updated after upgrade)
