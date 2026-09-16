# JUDGE READINESS REPORT

**Generated:** 2026-06-21  
**MandateOS package (testnet):** `0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13`  
**Navi package (mainnet):** `0x1e4a13a0494d5facdbe8473e74127b838c2d446ecec0ce262e2eddafa77259cb`

Statuses allowed: **CHAIN_VERIFIED** | **NOT VERIFIED** only.

---

## Executive summary

| Layer | Status |
|-------|--------|
| MandateOS protocol workflows (testnet CLI) | **CHAIN_VERIFIED** |
| Investment workflow (create → fund → simulate → execute → settlement/receipt) | **CHAIN_VERIFIED** |
| Browser judge flow | **NOT VERIFIED** |
| External DeFi (Navi deposit/withdraw) | **NOT VERIFIED** |
| Cross-network Treasury → Navi PTB | **NOT VERIFIED** |
| Auto-investment conditional rules (balance thresholds) | **NOT VERIFIED** |
| Canonical single-PTB programmable money demo (revenue → payroll → DeFi) | **NOT VERIFIED** |

**Protocol-side MandateOS verification is complete on Sui testnet.**  
**Programmable money platform (external capital deployment) requires mainnet Navi proof + browser judge artifact.**

---

## Priority 1 — Investment workflow

| Step | Move / PTB | Digest | Status |
|------|------------|--------|--------|
| Create Investment Mandate | `auto_investment_mandate::create + share_all` | [`EBY5LNhB6zvgV6bPFgcmqAqE31YF17d5CSB4zbGMF462`](https://suiscan.xyz/testnet/tx/EBY5LNhB6zvgV6bPFgcmqAqE31YF17d5CSB4zbGMF462) | CHAIN_VERIFIED |
| Fund Investment Vault | `auto_investment_mandate::fund` | [`DSaHaxfuiyvj2nMjLwXaJtGYyZ1rtJyPJQRqu6BsVuAf`](https://suiscan.xyz/testnet/tx/DSaHaxfuiyvj2nMjLwXaJtGYyZ1rtJyPJQRqu6BsVuAf) | CHAIN_VERIFIED |
| Simulate Investment | `financial_mandate::simulate_and_approve` | [`91pA73NfZY6r97mvaJuZwncFJq2yhjdDYyVxt6ziJ8ap`](https://suiscan.xyz/testnet/tx/91pA73NfZY6r97mvaJuZwncFJq2yhjdDYyVxt6ziJ8ap) | CHAIN_VERIFIED |
| Execute + Settlement | `auto_investment_mandate::invest` → `run_authorized_settlement` | [`8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo`](https://suiscan.xyz/testnet/tx/8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo) | CHAIN_VERIFIED |
| Settlement digest | Same tx as execute (settlement is in-PTB) | `8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo` | CHAIN_VERIFIED |
| FinancialReceipt | Created in execute tx | RPC object change in execute digest | CHAIN_VERIFIED |
| Portfolio update | Vault `0x77653ad0…` balance 6M MIST post-execute | RPC `getObject` | CHAIN_VERIFIED |

**Note:** `invest` transfers SUI to a recipient address — it does not yet call Navi/Scallop contracts. External deployment is Priority 3.

---

## Priority 2 — Browser judge flow (production UI only)

| Step | Route | Status |
|------|-------|--------|
| Connect Wallet | Slush on any production page | NOT VERIFIED |
| Create Treasury | `/app/account` → Treasury Execution Panel | NOT VERIFIED |
| Fund Treasury | `/app/account` | NOT VERIFIED |
| Create Obligations | `/obligations` | NOT VERIFIED |
| Execute workflows | `/app/payroll`, `/app/revenue`, `/app/yield-hub`, etc. | NOT VERIFIED |
| View Portfolio / Proof | `/app/portfolio`, `/proof` | NOT VERIFIED |
| Export proof JSON | Proof Center → Export | NOT VERIFIED |
| Artifact | `proof/ui-judge-demo.json` | **Missing** |

**Action:** New user opens TITAN → connect Slush → complete treasury + workflow steps via production routes only → export from Proof Center → save to `proof/ui-judge-demo.json` → run `npm run testnet:ui-judge-validate`.

**Removed:** `/demo`, `/judge-audit`, `/scenarios` — no judge-only routes or sandbox fixtures.

---

## Priority 3 — External DeFi (Navi)

**Production verification:** wallet-native only — `/app/navi-capital` with Slush. No CLI. No `MANDATEOS_MAINNET_KEY` for judges.

**Network mode (current production):** Option B — External Capital (treasury testnet, Navi mainnet). Not end-to-end programmable money.

| Item | Detail | Status |
|------|--------|--------|
| Canonical UI desk | `/app/navi-capital` — Connect → Sign → Deposit/Withdraw | Wired — **NOT VERIFIED** until live txs |
| Proof Center | Auto-record from tx result (digest, explorer, protocol, action) | Wired — **NOT VERIFIED** |
| Portfolio | Live `fetchNaviPositions` from Navi protocol | Wired — **NOT VERIFIED** |
| Option A (unified mainnet) | MandateOS on mainnet + `VITE_SUI_NETWORK=mainnet` | **NOT VERIFIED** — package not on mainnet |
| Audit artifact | `NAVI_PRODUCTION_AUDIT.md` | **NOT VERIFIED** |

**Judge path:** Connect Slush → `/app/navi-capital` → Sign Deposit → Proof Center → Portfolio → Sign Withdraw.

**Internal testing only:** `npm run internal:navi-verify` (requires `MANDATEOS_MAINNET_KEY` — not for production judges).

---

## Priority 4 — Auto-investment wallet rules

| Rule type | On-chain | Status |
|-----------|----------|--------|
| `rebalance_interval_ms`, `allocation_bps`, `min_investment` | `AutoInvestmentConfig` | CHAIN_VERIFIED |
| Conditional rules (if balance > X then Y%) | Not in Move | NOT VERIFIED |
| Autonomous keeper / cron execution | Not implemented | NOT VERIFIED |

---

## Priority 5 — Portfolio allocator

| Source | UI | Status |
|--------|-----|--------|
| Wallet balances | Portfolio (chain mode) | CHAIN_VERIFIED |
| Treasury vault fields | Portfolio (chain mode) | CHAIN_VERIFIED |
| Obligation fulfilled amounts | Portfolio (chain mode) | CHAIN_VERIFIED |
| Navi positions | Portfolio external section | NOT VERIFIED (mainnet query only) |
| Estimated APY when API missing | Removed — shows "Not available" | CHAIN_VERIFIED |

---

## Priority 6 — Programmable money demonstration

| Flow | Status |
|------|--------|
| Revenue → split → treasury reserve (testnet) | CHAIN_VERIFIED (separate mandate txs) |
| Payroll + investment (testnet) | CHAIN_VERIFIED |
| External protocol deposit in same PTB chain | NOT VERIFIED |
| Yield → withdrawal → settlement proof | NOT VERIFIED |

---

## Priority 7 — Feature matrix

| Requirement | Move module | Package | Verification |
|-------------|-------------|---------|--------------|
| Wallet Isolation | `treasury_mandate` | v5 testnet | CHAIN_VERIFIED |
| Treasury Creation | `treasury_mandate` | v5 testnet | CHAIN_VERIFIED |
| Treasury Funding | `treasury_mandate::fund` | v5 testnet | CHAIN_VERIFIED |
| Obligation Lifecycle | `financial_mandate` | v5 testnet | CHAIN_VERIFIED |
| Programmable Money Flow | `treasury_mandate` + `workflow` | v5 testnet | CHAIN_VERIFIED |
| Payroll Workflow | `payroll_mandate` | v5 testnet | CHAIN_VERIFIED |
| Revenue Workflow | `revenue_allocation_mandate` | v5 testnet | CHAIN_VERIFIED |
| Investment Workflow | `auto_investment_mandate` | v5 testnet | CHAIN_VERIFIED |
| Guardian Workflow | `guardian` | v5 testnet | CHAIN_VERIFIED |
| Risk Enforcement | `operational_risk` | v5 testnet | CHAIN_VERIFIED |
| Browser Judge Flow | UI + Slush | testnet | NOT VERIFIED |
| Navi Deposit/Withdraw | Navi `lending_core` | mainnet | NOT VERIFIED |
| Scallop / Cetus / Bucket / Turbos | — | — | NOT VERIFIED |

---

## Commands

```bash
# Refresh all testnet CLI evidence
npm run testnet:evidence-sprint

# Mainnet Navi deposit → position → withdraw proof
MANDATEOS_MAINNET_KEY=<suiprivkey> npm run mainnet:navi-verify

# Validate browser judge artifact after UI export
npm run testnet:ui-judge-validate
```

---

## Path to "Programmable Money Platform"

1. Run **mainnet Navi verification** (`npm run testnet:external-defi`) → `proof/external-defi-verification.json` with real digests.
2. Complete **browser judge** → `proof/ui-judge-demo.json`.
3. **Publish MandateOS on mainnet** OR build a composed PTB that chains `invest` output coin into `Navi depositCoinPTB` in one transaction.
4. Add **conditional auto-investment rules** as new on-chain objects (requires package upgrade).

Until steps 1–3 have digest evidence, TITAN remains a **verified Treasury OS on testnet** with **read-only DeFi intelligence**, not yet a **cross-protocol programmable money platform**.
