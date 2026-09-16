# MAINNET READINESS REPORT

**Generated:** 2026-06-21  
**Overall status:** NOT MAINNET READY  
**Allowed classifications:** CHAIN_VERIFIED | CODE_EXISTS | NOT VERIFIED only — no manual overrides

---

## Executive summary

TITAN operates as a **real programmable money platform** on testnet for MandateOS core workflows. Production UI exposes only chain-backed routes; simulation, mock, and derived-market desks are gated.

**Mainnet readiness is blocked by:**

1. MandateOS package not published/verified on mainnet
2. DeFi integrations (Navi, Scallop, Cetus, Allocation) at **CODE_EXISTS** — no RPC-validated mainnet digests
3. Allocation **treasury split digest** — no single on-chain MandateOS PTB for 40/40/20 split
4. Cross-network deployment: production `.env.production` targets **testnet** MandateOS while DeFi protocols require **mainnet** wallet capital

Bridge: **NOT STARTED** — blocked until `proof/defi-chain-verified.json` shows **CHAIN_VERIFIED** for all four DeFi integrations. `BRIDGE_READINESS_REPORT.md` will be produced only after that gate clears.

---

## Verified on testnet (protocol-side MandateOS)

| Capability | Status | Evidence |
|------------|--------|----------|
| Treasury Creation | CHAIN_VERIFIED | `proof/evidence-sprint.json` digest `8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL` |
| Treasury Funding | CHAIN_VERIFIED | Same |
| Obligations | CHAIN_VERIFIED | Same |
| Programmable Money | CHAIN_VERIFIED | Same |
| Payroll | CHAIN_VERIFIED | Same |
| Revenue | CHAIN_VERIFIED | Same |
| Investment | CHAIN_VERIFIED | Same |
| Guardian | CHAIN_VERIFIED | Same |
| Risk Enforcement | CHAIN_VERIFIED | `riskEngineValidation.classification` in evidence sprint |
| Smart Wallet Rules | CHAIN_VERIFIED | `proof/smart-wallet-rules-verification.json` |
| Proof Center | CHAIN_VERIFIED | `verifyProofDocument` RPC validation |

**Testnet package:** `0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13`  
**Rules satellite package:** `0x9c97a6e3ba609f114b8069334cf88f467217893f2a9c44301a8227f66b57b5ed`

---

## Treasury architecture

| Item | Testnet | Mainnet |
|------|---------|---------|
| Mandate graph (mandate, vault, constitution) | CHAIN_VERIFIED | NOT VERIFIED |
| Wallet-scoped state isolation | CHAIN_VERIFIED (two-wallet sprint) | NOT VERIFIED |
| Vault fund / withdraw PTBs | CHAIN_VERIFIED | NOT VERIFIED |
| Obligation registry lifecycle | CHAIN_VERIFIED | NOT VERIFIED |
| Capital bucket constitution | CHAIN_VERIFIED | NOT VERIFIED |

**Production UI:** `/app/account`, `/obligations`, `/objectives` — `MandateOSReader` only; no demo fixtures.

---

## Workflow architecture

| Workflow | PTB module | Testnet | Mainnet | Production route |
|----------|------------|---------|---------|------------------|
| Payroll | `payroll_mandate` | CHAIN_VERIFIED | NOT VERIFIED | `/app/payroll` |
| Subscriptions | `subscription_mandate` | CHAIN_VERIFIED | NOT VERIFIED | `/app/subscriptions` |
| Revenue split | `revenue_mandate` | CHAIN_VERIFIED | NOT VERIFIED | `/app/revenue` |
| Investment | `investment_mandate` | CHAIN_VERIFIED | NOT VERIFIED | `/app/yield-hub` |
| Guardian actions | `guardian_policy` | CHAIN_VERIFIED | NOT VERIFIED | `/app/guardian-actions` |

**Pattern:** Simulate (on-chain approval object) → user approve → execute → Proof Center records digest.

Programmable chains (`programmable-chains.ts`) run as **sequential** wallet-signed PTBs — not atomic multi-step PTBs.

---

## Smart wallet rules

| Item | Status |
|------|--------|
| Move module deployed | CHAIN_VERIFIED (satellite package on testnet) |
| Rule create digest | `7AT2EGgGxvUQ9qDQRCWThjqkYtivrhh2wUJxZ4jkxSXk` |
| Rule execute (proof-linked) | `CjLHsD9hGy1SMw7NfJFxkkMWVkNzmLqVc1qZYEu4gke6` |
| Monolithic MandateOS upgrade with rules | Blocked — `InsufficientGas` on full package upgrade |
| Production UI | `/app/smart-wallet-rules` — REAL_PROTOCOL |

---

## DeFi integrations (mainnet-only protocols)

| Integration | Adapter | Position read | Deposit/withdraw | Status |
|-------------|---------|---------------|------------------|--------|
| Navi | `@naviprotocol/lending` | `getLendingState` | Wallet PTB `/app/navi-capital` | **CODE_EXISTS** |
| Scallop | `@scallop-io/sui-scallop-sdk` | `getLendings` | Wallet PTB `/app/scallop-capital` | **CODE_EXISTS** |
| Cetus | `@cetusprotocol/cetus-sui-clmm-sdk` | `getPositionList` | LP add/remove `/app/cetus-capital` | **CODE_EXISTS** |
| Allocation 40/40/20 | Sequential deposits | Multi-protocol snapshot | `/app/allocation` | **CODE_EXISTS** |

**Navi mainnet package:** `0x1e4a13a0494d5facdbe8473e74127b838c2d446ecec0ce262e2eddafa77259cb`

### Required evidence per integration (all missing)

- Real wallet-signed transaction
- RPC-confirmed success digest
- Live position retrieval after deposit
- Portfolio reconciliation (before / after deposit / after withdraw)
- Proof Center export + `verifyProofDocument` **CHAIN_VERIFIED**

**Verification:** Slush wallet-signed transactions via production UI. Export `proof.json`, then:

```bash
npm run defi:chain-verify -- --wallet=0xYOUR_WALLET --proof=proof/proof.json
```

See `DEFI_WALLET_VERIFICATION_FLOW.md`. **No private keys required.**

**Blocker:** No DeFi digests exported from Proof Center yet for reference wallet.

**Allocation additional blocker:** Treasury split requires MandateOS treasury→multi-protocol PTB — sequential wallet deposits do not satisfy `treasurySplitDigest` requirement.

---

## Proof verification

| Check | Implementation |
|-------|----------------|
| Digest exists on RPC | `sui_getTransactionBlock` |
| Success status | `effects.status.status === 'success'` |
| Sender match | `transaction.data.sender` vs proof wallet |
| Events | Count + optional type validation |
| Object IDs | Expected IDs must appear in object changes |
| Explorer URL | Recorded per proof step |
| Timestamp | From transaction timestamp |
| Export | Proof Center → `proof.json` |
| CLI | `npm run verify-proof` |

Mismatch → **INVALID** — no fallback success states.

---

## Production reality (UI hardening)

See `PRODUCTION_REALITY_AUDIT.md` for full route inventory.

| Change | Rationale |
|--------|-----------|
| Market Terminal hidden | Derived bid/ask, technicals — fake exchange data |
| Judge/demo landing links removed | Single user path via `/hub` |
| DeFi routes registered in `REALITY_ROUTES` | Complete classification coverage |
| Simulation routes gated | Overview, capital, strategies, etc. unavailable |

**Env:** `VITE_DEMO_MODE=false`, `VITE_SUI_NETWORK=testnet`, MandateOS testnet package IDs in `.env.production`.

---

## Failure recovery

| Failure | Behavior |
|---------|----------|
| RPC unavailable | **Unavailable** — no fabricated values |
| Wallet disconnected | Actions disabled |
| Tx revert | Failed proof recorded; error shown |
| Proof RPC mismatch | INVALID in Proof Center; CLI exit 1 |
| DeFi position read fail | Unavailable badge on portfolio/desk |
| Cross-network (testnet treasury + mainnet DeFi) | Documented — external capital path only until unified mainnet deploy |

**Recovery:** Reconnect wallet → refresh mandate → re-execute workflow → export and re-verify proofs.

---

## Gas estimation

| Operation | Network | Status |
|-----------|---------|--------|
| Treasury create/fund | testnet | Observed in evidence sprint |
| Workflow execute | testnet | Observed per workflow |
| Rules package publish | testnet | Observed |
| Full MandateOS upgrade | testnet | Failed — InsufficientGas |
| Navi/Scallop/Cetus deposit/withdraw | mainnet | NOT VERIFIED |
| Multi-protocol allocation | mainnet | NOT VERIFIED |

No hardcoded gas estimates in production UI. Users see wallet simulation before execute.

---

## Mainnet deployment checklist

| Step | Status |
|------|--------|
| Publish MandateOS on mainnet | NOT VERIFIED |
| Publish PTB shim on mainnet | NOT VERIFIED |
| Deploy smart wallet rules (monolithic or satellite) | NOT VERIFIED |
| Update `VITE_SUI_NETWORK=mainnet` + package IDs | NOT VERIFIED |
| CHAIN_VERIFY all DeFi integrations | NOT VERIFIED |
| Browser acceptance path end-to-end | NOT VERIFIED |
| Produce `BRIDGE_READINESS_REPORT.md` | **Blocked** — waiting on DeFi CHAIN_VERIFIED |

---

## Path to REAL WORLD PROGRAMMABLE MONEY PLATFORM

1. Publish MandateOS + shim on mainnet (Option A unified network)
2. Execute Navi, Scallop, Cetus deposit+withdraw via wallet; capture digests in Proof Center
3. Implement treasury→40/40/20 split PTB for Allocation
4. Run `npm run defi:chain-verify` → overall **CHAIN_VERIFIED** in `proof/defi-chain-verified.json`
5. Complete browser verification path with zero INVALID proof steps
6. Produce and approve `BRIDGE_READINESS_REPORT.md` before any bridge code

**Do not mark any step complete without on-chain evidence.**
