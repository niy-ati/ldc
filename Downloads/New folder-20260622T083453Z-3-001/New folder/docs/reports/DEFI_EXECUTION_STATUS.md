# DeFi Execution Status

**Updated:** 2026-06-21  
**Reference wallet:** `0xa23a99091b2765ce9c07b7f6c75858518b949e27c9a22d01a754d0ad9914c749`

---

## Blocker: mainnet SUI required

| Network | Balance | DeFi usable? |
|---------|---------|--------------|
| **Mainnet** | **0 SUI** | **No** — Navi, Scallop, Cetus are mainnet-only |
| Testnet | ~1.5 SUI | MandateOS treasury workflows only — not DeFi protocols |

The 8 DeFi transactions **cannot execute** until this wallet holds mainnet SUI (~0.25 SUI minimum for verification cycle + gas).

Testnet balance does not transfer to mainnet automatically.

---

## What cannot be done from CLI

Steps 1–5 require **Slush wallet approval in the production UI**. No private keys. No automated signing from this environment.

---

## Current verification status

| Integration | Status |
|-------------|--------|
| Navi | CODE_EXISTS |
| Scallop | CODE_EXISTS |
| Cetus | CODE_EXISTS |
| Allocation | CODE_EXISTS |
| Bridge | BLOCKED |

**On-chain txs for reference wallet:** 0  
**proof.json exported:** none

---

## Your next actions (in order)

### 1. Fund mainnet wallet

Send **≥ 0.3 SUI** to `0xa23a99091b2765ce9c07b7f6c75858518b949e27c9a22d01a754d0ad9914c749` on **Sui mainnet**.

### 2. Execute 8 transactions in production UI

Follow **`DEFI_WALLET_VERIFICATION_FLOW.md`**:

| Step | Route | Action |
|------|-------|--------|
| 1–2 | `/app/navi-capital` | Deposit 0.01 → Withdraw 0.01 |
| 3–4 | `/app/scallop-capital` | Deposit 0.01 → Withdraw 0.01 |
| 5–6 | `/app/cetus-capital` | Sign deposit → Sign withdraw |
| 7 | `/app/allocation` | **Sign unified allocation PTB** (0.015 SUI, 40/40/20) |

Unified allocation = **one digest** for treasury-split + multi-protocol deployment evidence.

### 3. Proof Center

`/proof` → **Verify session proofs** → **Export proof.json** → save to `proof/proof.json`

### 4. Run export verification

```bash
npm run defi:chain-verify -- --wallet=0xa23a99091b2765ce9c07b7f6c75858518b949e27c9a22d01a754d0ad9914c749 --proof=proof/proof.json
```

Target outcome:

```
Navi         CHAIN_VERIFIED
Scallop      CHAIN_VERIFIED
Cetus        CHAIN_VERIFIED
Allocation   CHAIN_VERIFIED
```

---

## What was built (ready when mainnet is funded)

| Item | Location |
|------|----------|
| Unified multi-protocol PTB | `@mandateos/sdk` → `buildMultiProtocolAllocationPtb` |
| Slush single-sign allocation | `/app/allocation` → **Sign unified allocation PTB** |
| Wallet-only verification script | `npm run defi:chain-verify -- --wallet=... --proof=...` |
| RPC proof after each DeFi tx | `useDefiProtocolWorkflow` |

---

## After CHAIN_VERIFIED (not before bridge)

1. **Treasury → Allocation PTB from vault** — requires **unified-network mainnet MandateOS** (treasury vault pulls SUI, then composes Navi/Scallop/Cetus in one PTB)
2. **Unified deployment** — `VITE_SUI_NETWORK=mainnet` + published MandateOS package IDs
3. **Bridge readiness report** — only after all four DeFi integrations CHAIN_VERIFIED

**Do not start bridge work until DeFi CHAIN_VERIFIED.**
