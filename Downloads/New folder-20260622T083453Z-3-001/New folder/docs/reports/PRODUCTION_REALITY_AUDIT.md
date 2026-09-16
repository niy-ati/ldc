# PRODUCTION REALITY AUDIT

**Generated:** 2026-06-21  
**Scope:** `packages/command-center` production routes (`RealityRouteGate` + sidebar/hub navigation)  
**Policy:** Unavailable is acceptable. Fake data is not.

---

## Executive summary

| Classification | Accessible routes | Action |
|----------------|-------------------|--------|
| **REAL** | 21 | No change — chain/API/protocol backed |
| **UNAVAILABLE** | 19+ | Blocked via `RealityRouteGate` or redirect |
| **MIXED / FAKE** | 0 accessible | Market Terminal hidden (derived bid/ask, simulated depth helpers) |

MandateOS protocol workflows (treasury, obligations, payroll, revenue, investment, guardian, smart wallet rules, proof center) are **CHAIN_VERIFIED** on testnet per `proof/evidence-sprint.json` and `proof/smart-wallet-rules-verification.json`.

DeFi integrations (Navi, Scallop, Cetus, Allocation) remain **CODE_EXISTS** — no mainnet digests yet. See `DEFI_CHAIN_VERIFIED_REPORT.md`.

Bridge development: **BLOCKED** until all four DeFi integrations are **CHAIN_VERIFIED**.

---

## Global data plumbing

| Concern | Source | Refresh | Cache | Fallback |
|---------|--------|---------|-------|----------|
| Treasury / mandate view | `MandateOSReader` → Sui RPC (`VITE_SUI_NETWORK`) | WS events + 30s poll + manual refresh | Wallet-scoped graphs in `localStorage` | `MandateViewGate` blocks page — no fixture injection |
| Wallet balance | dapp-kit `getBalance` | On connect / query invalidation | None | Disabled actions + message |
| DeFi positions | `@mandateos/sdk` adapters → **mainnet** fullnode | `refetchOnMount: 'always'`, `staleTime: 0` | None | **Unavailable** badge — no seeded balances |
| Tx proofs | Wallet-signed PTB results | On execute | Wallet-scoped `localStorage` | Empty Proof Center |
| Proof verification | `verifyProofDocument` → `sui_getTransactionBlock` | On user click | Session state only | INVALID status — no override |
| Demo mode | `VITE_DEMO_MODE` | — | — | Bootstrap always calls `setDemoMode(false)` |

**RPC:** `getFullnodeUrl(appConfig.network)` for MandateOS; `getFullnodeUrl('mainnet')` for Navi/Scallop/Cetus regardless of treasury network.

---

## Production-accessible routes

### Command & proof

| Route | Page | Reality | Data source | RPC | Protocol | Refresh | Cache | Fallback |
|-------|------|---------|-------------|-----|----------|---------|-------|----------|
| `/hub` | HubPage | REAL | Static tiles + onboarding email | — | — | Static | localStorage email | Empty greeting |
| `/proof` | ProofCenterPage | REAL | Wallet tx proofs + audit events | Per-proof network fullnode | MandateOS events | On tx + event stream | Wallet proofs localStorage | Empty tabs |

**Proof Center validates:** digest existence, tx success status, sender match, event count, object change count, expected object IDs (when recorded), explorer URL, timestamp. Export → `proof.json` → `npm run verify-proof` for CLI cross-check.

### Treasury

| Route | Page | Reality | Data source | RPC | Protocol | Refresh | Cache | Fallback |
|-------|------|---------|-------------|-----|----------|---------|-------|----------|
| `/app/account` | TreasuryAccountPage | REAL | MandateOSReader vault, obligations, events | Configured network | MandateOS package | Live + manual | Wallet bundle | Gate until chain load |
| `/obligations` | ObligationsPage | REAL | On-chain obligation registry | Configured network | MandateOS | Mandate refresh | localStorage | Blank if no view |
| `/objectives` | ObjectivesPage | REAL | Mandate objective fields | Configured network | MandateOS | Mandate refresh | localStorage | Blank if no view |
| `/templates` | TemplatesPage | REAL | SDK template metadata; deploy PTB | Configured network | MandateOS | Static cards | — | Wallet required |

### Financial workflows (testnet MandateOS)

| Route | Page | Reality | Data source | RPC | Protocol | Refresh | Cache | Fallback |
|-------|------|---------|-------------|-----|----------|---------|-------|----------|
| `/app/payroll` | PayrollPage | REAL | Payroll PTB simulate/execute | Configured network | MandateOS payroll | On user action | Workflow graphs localStorage | Wallet + graph required |
| `/app/subscriptions` | SubscriptionPage | REAL | Subscription PTB | Configured network | MandateOS | On user action | localStorage | Same |
| `/app/revenue` | RevenuePage | REAL | Revenue split PTB | Configured network | MandateOS revenue | On user action | localStorage | Same |
| `/app/yield-hub` | YieldHubPage | REAL | Investment mandate PTB | Configured network | MandateOS investment | On user action | localStorage | Same |
| `/app/guardian-actions` | GuardianActionsPage | REAL | Guardian evaluate/simulate/execute | Configured network | MandateOS guardian | On user action | localStorage | Needs mandate graph |
| `/app/smart-wallet-rules` | SmartWalletRulesPage | REAL | Rule create/execute PTBs | Configured network | Satellite rules package | On user action | Proofs localStorage | Prior workflow digest required |

### DeFi (mainnet protocols — NOT CHAIN_VERIFIED)

| Route | Page | Reality | Data source | RPC | Protocol | Refresh | Cache | Fallback |
|-------|------|---------|-------------|-----|----------|---------|-------|----------|
| `/app/navi-capital` | NaviCapitalPage | REAL (unverified) | Wallet-signed deposit/withdraw | **Mainnet** | Navi `@naviprotocol/lending` | Positions always refetch | None | Unavailable for missing APY/position |
| `/app/scallop-capital` | ScallopCapitalPage | REAL (unverified) | Same pattern | **Mainnet** | Scallop SDK | Same | None | Same |
| `/app/cetus-capital` | CetusCapitalPage | REAL (unverified) | LP add/remove | **Mainnet** | Cetus CLMM SDK | Same | None | Same |
| `/app/allocation` | CapitalAllocationPage | REAL (unverified) | Sequential mainnet deposits 40/40/20 | **Mainnet** | All three | On execute | Component state | Skip below 0.001 SUI |

**Status:** Integration code and live position reads exist. **CHAIN_VERIFIED** requires wallet-signed digests + RPC confirmation + portfolio reconciliation in `proof/defi-chain-verified.json`.

### Portfolio & operations

| Route | Page | Reality | Data source | RPC | Protocol | Refresh | Cache | Fallback |
|-------|------|---------|-------------|-----|----------|---------|-------|----------|
| `/app/portfolio` | PortfolioPage | REAL | Wallet + vault + protocol positions | Configured + mainnet | MandateOS + DeFi adapters | dapp-kit + refetch | Wallet state | `WalletPortfolioFallback` — no synthetic PnL |
| `/agents` | AgentsPage | REAL | Delegation view from chain | Configured network | MandateOS | Mandate refresh | localStorage | MandateViewGate |
| `/audit` | AuditPage | REAL | Package events + proofs | Configured network | MandateOS | Event stream | localStorage | Empty if no events |

---

## Blocked / unavailable routes

Direct navigation shows `DeskUnavailablePage` via `RealityRouteGate`:

| Route | Classification | Reason |
|-------|----------------|--------|
| `/app/markets` | SIMULATION | Derived bid/ask, technicals, order-book helpers — not live exchange data |
| `/overview`, `/capital`, `/routes`, `/guardian`, `/risk`, `/position`, `/protection`, `/yield` | SIMULATION | Derived PnL, MAGMA intel, advisory routing, generated yields |
| `/app/advisor`, `/app/strategies`, `/app/liquidity` | SIMULATION | Generated forecasts, hardcoded strategy Sharpe, borrow slider without PTB |
| `/app/yield-tokens` | MOCK | No Kamo on-chain objects |
| `/app/trade` | DEAD_UI | No swap/DeepBook PTB |
| `/trace`, `/ecosystem`, `/welcome` | DEAD_UI | Blank or static marketing |
| `/demo`, `/judge-audit`, `/scenarios` | DEAD_UI | Redirect to `/app/account`, `/proof`, `/hub` |

---

## Removed / disabled fake data (this audit)

| Item | Prior state | Action |
|------|-------------|--------|
| Market Terminal `/app/markets` | MIXED — CoinGecko + derived bid/ask/technicals | **Hidden** from production nav and hub |
| Landing "Judge Demo" → `/demo` | Separate judge entry | **Removed** — Launch App → `/hub` |
| Landing "Mission Control" → `/overview` | Blocked simulation route | **Removed** — Proof Center link instead |
| Sidebar "Market Terminal" | Linked to hidden route | **Removed** — Portfolio section only |
| Unregistered DeFi routes | Accessible but not in `REALITY_ROUTES` | **Registered** as REAL_PROTOCOL |

---

## Browser verification path (single user journey)

No judge routes. No demo routes. Same path for all users:

1. **Connect Wallet** (Slush / Sui Wallet)
2. **Create Treasury** — `/templates` or Treasury Account deploy
3. **Fund Treasury** — Treasury Account fund PTB
4. **Create Obligation** — `/obligations`
5. **Execute Workflow** — Payroll / Revenue / Investment
6. **DeFi (when verified)** — Navi → Scallop → Cetus → Allocation (mainnet wallet SUI required)
7. **Portfolio** — `/app/portfolio` — live position reads
8. **Proof Center** — `/proof` — Verify session proofs
9. **Export proof.json**
10. **CLI verify** — `npm run verify-proof`

**Current gap:** Steps 6 DeFi workflows not **CHAIN_VERIFIED** — blockers in `DEFI_CHAIN_VERIFIED_REPORT.md`.

---

## Protocol verification cross-reference

| Domain | Status | Evidence |
|--------|--------|----------|
| Treasury Creation | CHAIN_VERIFIED | `proof/evidence-sprint.json` |
| Treasury Funding | CHAIN_VERIFIED | Same |
| Obligations | CHAIN_VERIFIED | Same |
| Programmable Money | CHAIN_VERIFIED | Same |
| Payroll / Revenue / Investment | CHAIN_VERIFIED | Same |
| Guardian | CHAIN_VERIFIED | Same |
| Risk Enforcement | CHAIN_VERIFIED | Same |
| Smart Wallet Rules | CHAIN_VERIFIED | `proof/smart-wallet-rules-verification.json` |
| Proof Center | CHAIN_VERIFIED | SDK `verifyProofDocument` + testnet digests |
| Navi / Scallop / Cetus / Allocation | CODE_EXISTS | `proof/defi-chain-verified.json` |

---

## Next actions (verification only — no new features)

1. Connect Slush (mainnet) and complete `DEFI_WALLET_VERIFICATION_FLOW.md` in production UI
2. Export Proof Center `proof.json`; run `npm run defi:chain-verify -- --wallet=0x... --proof=proof/proof.json`
3. Implement on-chain treasury→multi-protocol split PTB for Allocation **treasury split digest**
4. After all four DeFi integrations **CHAIN_VERIFIED**, produce `BRIDGE_READINESS_REPORT.md` (bridge code remains blocked until then)
