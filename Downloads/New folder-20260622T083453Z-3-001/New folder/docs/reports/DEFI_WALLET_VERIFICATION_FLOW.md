# DeFi Wallet Verification Flow (Slush · Production UI)

**No private keys. No CLI signing.** All transactions are wallet-signed through Slush in the production app.

**Reference wallet (verification only):** `0xa23a99091b2765ce9c07b7f6c75858518b949e27c9a22d01a754d0ad9914c749`  
**Approximate balance:** ~1.5 SUI mainnet  
**Production URL:** `https://command-center-five-eta.vercel.app` (or local build)

---

## Prerequisites

| Item | Requirement |
|------|-------------|
| Wallet | Slush connected on **Sui mainnet** |
| Network | DeFi protocols: **mainnet** · MandateOS treasury workflows: **testnet** (current deploy) |
| Minimum SUI | **~0.25 SUI** for full verification cycle including gas (see per-protocol below) |
| Browser | Same path for all users — no judge/demo routes |

After each transaction the app automatically:

1. Captures digest
2. Validates digest via RPC (`verifyProofStep`)
3. Records proof in Proof Center (explorer URL, sender, events, amount)
4. Refreshes live protocol positions
5. Updates portfolio reads

---

## Full verification sequence (8 transactions + allocation)

```
Connect Slush (mainnet)
  → Navi deposit
  → Navi withdraw
  → Scallop deposit
  → Scallop withdraw
  → Cetus add liquidity
  → Cetus remove liquidity
  → Allocation workflow (3 deposits)
  → Proof Center verify + export
```

**Total wallet-signed transactions:** 8 (5 protocol cycle + 3 allocation deposits)

---

## 1. Navi

| Field | Value |
|-------|-------|
| **Network** | Mainnet |
| **Minimum SUI** | 0.01 SUI per step + ~0.02 SUI gas for deposit+withdraw |
| **Screen** | `/app/navi-capital` |
| **Transactions** | 2 |

### Steps

1. Open app → connect **Slush** → confirm network shows **mainnet**
2. Sidebar → **Financial Workflows** → **Navi Capital**
3. Set **Deposit (SUI)** = `0.01`
4. Click **Sign · Navi Deposit** → approve in Slush
5. Wait for success → note digest link and “recorded in Proof Center”
6. Click **Refresh position** → **Navi supplied SUI** should show ~0.01
7. Set **Withdraw (SUI)** = `0.01`
8. Click **Sign · Navi Withdraw** → approve in Slush
9. **Refresh position** → supplied SUI returns to ~0

### Expected proof artifacts (Proof Center)

| Proof | protocol | naviAction | workflowType |
|-------|----------|------------|--------------|
| Navi Deposit | navi | deposit | navi |
| Navi Withdraw | navi | withdraw | navi |

Each proof includes: digest, explorer URL (`suiscan.xyz/mainnet/tx/…`), wallet sender, `rpcVerified: true`, amountMist ≈ 10_000_000.

### Expected portfolio state

| After deposit | After withdraw |
|---------------|----------------|
| Navi supplied SUI ≈ 0.01 | Navi supplied SUI ≈ 0 |
| Mainnet wallet SUI decreases by ~0.01 + gas | Wallet SUI restored (minus gas) |

**CHAIN_VERIFIED when:** both digests RPC-valid + position read reconciles deposit/withdraw cycle.

---

## 2. Scallop

| Field | Value |
|-------|-------|
| **Network** | Mainnet |
| **Minimum SUI** | 0.01 SUI per step + ~0.02 SUI gas |
| **Screen** | `/app/scallop-capital` |
| **Transactions** | 2 |

### Steps

1. Sidebar → **Scallop Capital**
2. Set **Deposit (SUI)** = `0.01` → click **Sign deposit** → approve in Slush
3. **Scallop position (SUI)** metric shows supplied amount
4. Set **Withdraw (SUI)** = `0.01` → click **Sign withdraw** → approve in Slush
5. Position returns toward zero

### Expected proof artifacts

| Proof | protocol | naviAction | workflowType |
|-------|----------|------------|--------------|
| Scallop Deposit | scallop | deposit | scallop |
| Scallop Withdraw | scallop | withdraw | scallop |

### Expected portfolio state

Same pattern as Navi — `/app/portfolio` shows Scallop row from live adapter read after deposit, cleared after withdraw.

---

## 3. Cetus

| Field | Value |
|-------|-------|
| **Network** | Mainnet |
| **Minimum SUI** | 0.01 SUI per step + ~0.03 SUI gas (CLMM LP) |
| **Screen** | `/app/cetus-capital` |
| **Transactions** | 2 |

### Steps

1. Sidebar → **Cetus Capital**
2. Set **Deposit (SUI)** = `0.01` → click **Sign deposit** (add liquidity) → approve in Slush
3. **Cetus position (SUI)** or LP position count increases
4. Set **Withdraw (SUI)** = `0.01` → click **Sign withdraw** (remove liquidity) → approve in Slush
5. LP position count returns to prior baseline

### Expected proof artifacts

| Proof | action label | protocol | naviAction |
|-------|--------------|----------|------------|
| Cetus Add Liquidity | Cetus Add Liquidity | cetus | deposit |
| Cetus Remove Liquidity | Cetus Remove Liquidity | cetus | withdraw |

### Expected portfolio state

Cetus LP positions visible in `/app/portfolio` during open LP; removed after withdraw.

---

## 4. Multi-Protocol Allocation Engine

| Field | Value |
|-------|-------|
| **Network** | Mainnet (wallet-signed deposits) |
| **Minimum SUI** | **0.015 SUI** total deploy + ~0.03 SUI gas (3 txs) |
| **Screen** | `/app/allocation` |
| **Transactions** | 3 (sequential Slush approvals) |
| **Default split** | Navi 40% · Scallop 40% · Cetus 20% |

### Steps

1. Sidebar → **Multi-Protocol Allocation**
2. Set **Total SUI** = `0.015` (fits ~1.5 SUI wallet after prior cycles)
3. Confirm sliders: Navi 40% · Scallop 40% · Cetus 20%
4. Click **Execute allocation** → approve **3 separate** Slush prompts (Navi → Scallop → Cetus)
5. **Allocation results** table shows digest per protocol
6. Open **Verify in Proof Center →**

### Expected proof artifacts

| Proof | workflowType | naviAction | Approx amount |
|-------|--------------|------------|---------------|
| Allocation · Navi Deposit | allocation | deposit | 0.006 SUI |
| Allocation · Scallop Deposit | allocation | deposit | 0.006 SUI |
| Allocation · Cetus Add Liquidity | allocation | deposit | 0.003 SUI |

### Expected portfolio state (after allocation)

| Protocol | Expected deployed |
|----------|-------------------|
| Navi | ~0.006 SUI supplied |
| Scallop | ~0.006 SUI supplied |
| Cetus | LP position from ~0.003 SUI |

`/app/portfolio` aggregates all three live positions.

### Allocation CHAIN_VERIFIED note

**Protocol deposit digests + final portfolio snapshot** are satisfied by this workflow.

**Treasury split digest** requires a MandateOS treasury→multi-protocol PTB (not yet on-chain). Allocation remains **NOT VERIFIED** for full CHAIN_VERIFIED until treasury split exists — deposits and portfolio proof can still be RPC-verified.

---

## Proof Center completion

| Step | Screen | Action |
|------|--------|--------|
| 1 | `/proof` | Review **Executions** tab — 8+ external-defi proofs |
| 2 | `/proof` | Click **Verify session proofs** — all steps **CHAIN_VERIFIED** |
| 3 | `/proof` | Click **Export proof.json** |
| 4 | Save | `proof/proof.json` in repo (or upload path for CI) |

### Proof Center validates each digest

- Digest exists on RPC
- Transaction status = success
- Sender = connected wallet
- Events and object changes recorded
- Explorer URL present
- Timestamp from chain

### Export verification (no private key)

```bash
npm run defi:chain-verify -- --wallet=0xa23a99091b2765ce9c07b7f6c75858518b949e27c9a22d01a754d0ad9914c749 --proof=proof/proof.json
```

Writes:

- `DEFI_CHAIN_VERIFIED_REPORT.md`
- `proof/defi-chain-verified.json`

---

## Budget for reference wallet (~1.5 SUI)

| Phase | SUI used (approx) |
|-------|-------------------|
| Navi cycle (0.01 dep/wd) | ~0.025 gas |
| Scallop cycle | ~0.025 gas |
| Cetus cycle | ~0.035 gas |
| Allocation 0.015 deploy | 0.015 locked in protocols + ~0.03 gas |
| **Remaining in wallet** | ~1.35 SUI (after allocation positions deployed) |

Use **0.01 SUI** per protocol verification step. Use **0.015 SUI** for allocation total.

---

## CHAIN_VERIFIED criteria summary

| Integration | Required | Satisfied by UI flow |
|-------------|----------|----------------------|
| Navi | deposit + withdraw + position + reconcile | Yes (2 txs) |
| Scallop | deposit + withdraw + position + reconcile | Yes (2 txs) |
| Cetus | add + remove + LP proof + reconcile | Yes (2 txs) |
| Allocation | treasury split + 3 deposits + portfolio | Partial — treasury split PTB pending |

**Bridge:** blocked until all four integrations = **CHAIN_VERIFIED**.
