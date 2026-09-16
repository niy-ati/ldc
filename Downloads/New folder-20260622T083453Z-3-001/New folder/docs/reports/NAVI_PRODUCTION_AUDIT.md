# NAVI PRODUCTION AUDIT

**Generated:** 2026-06-21  
**Classification:** NOT VERIFIED

Allowed states: **CHAIN_VERIFIED** | **NOT VERIFIED** only.

---

## Executive summary

Navi integration is wired for **wallet-native production verification**. CLI scripts and `MANDATEOS_MAINNET_KEY` are **internal testing only** — they are not the canonical verification path.

**Current deployment:** Option B (External Capital) — MandateOS treasury on **testnet**, Navi on **mainnet**.

**Overall status:** NOT VERIFIED — no wallet-signed deposit/withdraw has been recorded in Proof Center in this environment.

---

## Network architecture evaluation

### Option A — Unified programmable money (preferred)

Deploy MandateOS to Sui **mainnet**. Then:

Treasury → Obligation → Investment → Navi Deposit

occurs on the **same network** with treasury-controlled capital.

| Requirement | Status |
|-------------|--------|
| MandateOS package on mainnet | NOT VERIFIED — not published in current production config |
| `VITE_SUI_NETWORK=mainnet` | NOT VERIFIED — production uses testnet |
| End-to-end judge flow without cross-network split | NOT VERIFIED |

**To enable Option A:** publish MandateOS to mainnet, set `VITE_MANDATEOS_PACKAGE_ID` to mainnet package, set `VITE_SUI_NETWORK=mainnet`, redeploy TITAN.

### Option B — External Capital Deployment (current)

Treasury workflows on **testnet**. Navi on **mainnet**. Navi deposits use **mainnet wallet SUI**, not testnet vault balances.

| Requirement | Status |
|-------------|--------|
| Clearly labeled as external (not treasury-controlled) | CHAIN_VERIFIED (UI copy) |
| Wallet-native Navi desk | CHAIN_VERIFIED (wired) |
| Presented as end-to-end programmable money | NOT VERIFIED — intentionally not claimed |

---

## Canonical production flow (wallet-native)

```
Connect Slush
  → /app/navi-capital
  → Sign · Navi Deposit (sui:mainnet)
  → Proof Center (digest, explorer, protocol=Navi, action=Deposit)
  → Portfolio (live Navi lending state)
  → Sign · Navi Withdraw
  → Proof Center + Portfolio update
```

No private keys. No CLI. No admin signer. No synthetic proof records.

---

## Verification checklist

| Item | Source | Status |
|------|--------|--------|
| Deposit verified (wallet-signed) | Proof Center `naviAction=deposit` + mainnet digest | NOT VERIFIED |
| Withdrawal verified (wallet-signed) | Proof Center `naviAction=withdraw` + mainnet digest | NOT VERIFIED |
| Portfolio live Navi read | `fetchNaviPositions` → Navi `getLendingState` | NOT VERIFIED — no position in session |
| Proof Center auto-record | `useNaviWorkflow` → `addTxProof` from tx response | NOT VERIFIED — no live tx |
| Wallet-native flow end-to-end | Slush sign on `/app/navi-capital` | NOT VERIFIED |
| Treasury → Navi same capital (Option A) | Requires mainnet MandateOS | NOT VERIFIED |

---

## Production routes

| Route | Purpose |
|-------|---------|
| `/app/navi-capital` | Canonical Navi desk — deposit, withdraw, position read |
| `/app/portfolio` | Navi positions from protocol state |
| `/proof` | All Navi txs with digest, explorer URL, timestamp |
| `/app/yield-hub` | Investment mandate (testnet); links to Navi Capital with mode banner |

---

## Internal testing only (not production verification)

```bash
# Internal — requires MANDATEOS_MAINNET_KEY, not for judges
npm run internal:navi-verify
```

Judges must use the production UI only.

---

## Path to CHAIN_VERIFIED

1. **Option B (current network):** Judge connects Slush → `/app/navi-capital` → deposit → withdraw → confirm Proof Center + Portfolio.
2. **Option A (full programmable money):** Publish MandateOS mainnet → switch production to mainnet → judge runs Treasury → Investment → Navi on one network.

Do not mark CHAIN_VERIFIED until all five wallet-native checks in the checklist pass with real mainnet digests visible in Proof Center.
