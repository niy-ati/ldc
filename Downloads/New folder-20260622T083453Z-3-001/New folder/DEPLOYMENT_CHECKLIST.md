# MandateOS — Deployment Checklist (Phase 7.1)

Pre-flight verification before testnet funding arrives. No protocol, SDK, or frontend changes required.

---

## Prerequisites

| Requirement | How to verify |
|-------------|---------------|
| Node.js ≥ 18 | `node --version` |
| npm workspaces installed | `npm install` from repo root |
| Sui CLI present | `mandateos/.tools/sui/sui.exe --version` |
| Sui CLI protocol **≥ 126** (testnet) | `npm run testnet:publish:dry` — must not report protocol mismatch |
| Keystore address `kind-chrysolite` | `sui client addresses` |
| Deployer on testnet | `0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b` |
| Testnet gas ≥ 0.5 SUI | `sui client gas` (after funding) |
| Move build passes | `npm run testnet:publish:dry` |
| 38/38 Move tests pass | included in dry-run above |

### Current environment (verified 2026-06-19)

| Item | Status |
|------|--------|
| Bundled CLI | `sui 1.66.2` — **protocol 113** |
| Testnet protocol | **126** |
| Compatibility | **UPGRADE REQUIRED** before publish |
| Move build | PASS |
| Move tests | PASS (38/38) |
| Testnet gas | 0 SUI (awaiting faucet) |

---

## Sui CLI Upgrade (required)

The bundled CLI (`1.66.2`, protocol 113) is behind testnet (protocol 126). Upgrade **before** publishing.

### Option A — suiup (recommended)

```powershell
# Install suiup: https://github.com/MystenLabs/suiup
suiup install sui@testnet-1.73.1
suiup default set sui@testnet-1.73.1

# Point MandateOS scripts at the new binary
$env:SUI_BIN = "$env:USERPROFILE\.local\share\suiup\bin\sui.exe"
sui --version   # expect testnet-v1.73.1, protocol 126
```

### Option B — Windows binary (replace bundled)

```powershell
# Download: https://github.com/MystenLabs/sui/releases/tag/testnet-v1.73.1
# Asset: sui-testnet-v1.73.1-windows-x86_64.tgz
# Extract sui.exe over mandateos/.tools/sui/sui.exe

$env:SUI_BIN = "c:\Users\niyat\New folder\mandateos\.tools\sui\sui.exe"
& $env:SUI_BIN --version
```

### Option C — cargo (from source)

```powershell
cargo install --locked --git https://github.com/MystenLabs/sui.git --tag testnet-v1.73.1 sui
$env:SUI_BIN = "$env:USERPROFILE\.cargo\bin\sui.exe"
```

After upgrade, re-run:

```powershell
npm run testnet:publish:dry
```

Expected: `[PASS] No protocol version mismatch` or CLI protocol ≥ 126.

---

## Pre-funding dry-run (run now)

```powershell
cd "c:\Users\niyat\New folder"

# Full readiness check (build, test, schema, docs dry-run)
npm run testnet:readiness

# Or individually:
npm run testnet:publish:dry          # build + 38 tests, no publish
npm run testnet:proof                # must exit 1 with "Set MANDATEOS_PACKAGE_ID"
node scripts/validate-proof-artifacts.mjs --fixture
```

### Expected dry-run outputs

| Command | Expected exit | Expected output |
|---------|---------------|-----------------|
| `testnet:publish:dry` | 0 (build/test) or 3 (protocol mismatch until CLI upgraded) | `[PASS] move build`, `[PASS] move test (38/38)` |
| `testnet:proof` (no env) | 1 | `Set MANDATEOS_PACKAGE_ID to the published package ID.` |
| `validate-proof-artifacts --fixture` | 0 | `All validations passed.` |
| `testnet:readiness` | 0 | `Summary: 0 failure(s)` |

---

## Live deployment (after funding)

Execute in order. Do not skip steps.

### Step 1 — Fund deployer

```powershell
# Web (preferred when API rate-limited):
# https://faucet.sui.io/?address=0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b

# Or automated poller:
npm run testnet:fund
```

**Expected:** `sui client gas` shows ≥ 1 SUI (10,000,000,000 MIST).

### Step 2 — Publish package

```powershell
npm run testnet:publish
```

**Expected outputs:**

- Console: `Package ID: 0x...` and `Digest: ...`
- File: `proof/deployment.json`
- File: `proof/publish-result.json`

**`deployment.json` schema:**

```json
{
  "packageId": "0x<64-hex>",
  "digest": "<tx-digest>",
  "governor": "0xd0de6a0c...e5e10b",
  "network": "testnet",
  "publishedAt": "<ISO-8601>",
  "cliVersion": "1.73.1",
  "protocolVersion": 126
}
```

**Explorer links:**

- Publish tx: `https://suiscan.xyz/testnet/tx/{digest}`
- Package: `https://suiscan.xyz/testnet/object/{packageId}`

### Step 3 — Run on-chain proofs

```powershell
$env:MANDATEOS_PACKAGE_ID = (Get-Content proof/deployment.json | ConvertFrom-Json).packageId
$env:MANDATEOS_GOVERNOR_ADDRESS = "0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b"
npm run testnet:proof
```

**Expected:**

- File: `proof/testnet-results.json`
- Console: 9+ steps with `✓` and suiscan URLs
- Treasury, agent (success + rejection), guardian flows complete

**`testnet-results.json` required fields:**

- `network`, `packageId`, `governor`, `steps[]`, `objects{}`
- Core objects: `FinancialMandate`, `FinancialConstitution`, `MandateVault`, `ObligationRegistry`, `GuardianPolicy`, `LiquidityEngine`
- Each step: `name`, `digest`, `explorer` (must match `https://suiscan.xyz/testnet/tx/...`)

Validate:

```powershell
npm run testnet:verify
```

### Step 4 — Regenerate demo docs

```powershell
npm run testnet:docs
```

**Expected:** Updates `DEPLOYMENT.md`, `TREASURY_DEMO.md`, `AGENT_DEMO.md`, `GUARDIAN_DEMO.md`, `LIVE_UI.md`.

### Step 5 — Command Center live mode

Copy env block from `LIVE_UI.md` into `packages/command-center/.env.local`:

```env
VITE_DEMO_MODE=false
VITE_SUI_NETWORK=testnet
VITE_MANDATEOS_PACKAGE_ID=<packageId>
VITE_MANDATEOS_MANDATE_ID=<FinancialMandate>
VITE_MANDATEOS_VAULT_ID=<MandateVault>
VITE_MANDATEOS_CONSTITUTION_ID=<FinancialConstitution>
VITE_MANDATEOS_OBLIGATIONS_ID=<ObligationRegistry>
VITE_MANDATEOS_RISK_PROFILE_ID=<from on-chain graph if available>
VITE_MANDATEOS_LIQUIDITY_ENGINE_ID=<LiquidityEngine>
VITE_MANDATEOS_FORECAST_ID=<MarketForecast>
VITE_MANDATEOS_HOOK_ID=<DeepBookHook>
VITE_MANDATEOS_GUARDIAN_POLICY_ID=<GuardianPolicy>
VITE_MANDATEOS_EXECUTION_TRACKER_ID=<DailyExecutionTracker>
VITE_MANDATEOS_TREASURY_CONFIG_ID=<TreasuryConfig>
VITE_MANDATEOS_TRACE_TX=<Execute Treasury Payment digest>
```

```powershell
npm run dev:cc
```

**Expected:** Green **LIVE TESTNET** banner; Overview shows real mandate ID and vault balance.

### Step 6 — Screenshots

Save to `proof/screenshots/`:

- `treasury-explorer.png` — execute payment tx on suiscan
- `agent-success.png` / `agent-rejected.png`
- `guardian-restrict.png`
- `command-center-overview.png`

---

## Common failures & recovery

| Failure | Cause | Recovery |
|---------|-------|----------|
| `protocol version is 113, network is 126` | Outdated CLI | Upgrade CLI (see above), set `$env:SUI_BIN`, re-run dry-run |
| `Cannot find gas coin` | Unfunded deployer | Fund via [faucet.sui.io](https://faucet.sui.io/?address=0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b) |
| `FaucetRateLimitError` | API rate limit | Use web faucet or Discord `!faucet`; wait 1–24h for API |
| `Set MANDATEOS_PACKAGE_ID` | Proof run before publish | Complete Step 2 first |
| `deployment.json` parse error | Warnings mixed into JSON | Re-run publish; check `proof/publish-stderr.log` |
| `dependency verification error` on publish | CLI/network mismatch | Upgrade to testnet-v1.73.1 |
| `Governor balance too low` during proof | Insufficient gas for multi-tx demo | Fund deployer with ≥ 2 SUI |
| Command Center shows demo data | Missing `.env.local` or `VITE_DEMO_MODE` not `false` | Copy env from `LIVE_UI.md` |
| `keytool sign` fails | Wrong active address | `sui client switch --address kind-chrysolite` |
| Agent tx fails | Agent not funded | Proof script transfers 0.2 SUI to agent automatically |

---

## Artifact map

| File | Purpose |
|------|---------|
| `proof/deployment.json` | Package ID + publish digest |
| `proof/publish-result.json` | Raw Sui CLI publish JSON |
| `proof/publish-stderr.log` | CLI warnings during publish |
| `proof/testnet-results.json` | All demo tx digests + object IDs |
| `proof/schemas/*.json` | JSON schema reference |
| `proof/fixtures/*.json` | Dry-run validation samples |
| `scripts/validate-proof-artifacts.mjs` | Schema + explorer + env validation |

---

## One-command readiness (before funding)

```powershell
npm run testnet:readiness
```

Exit code `0` = safe to publish immediately once gas arrives.

---

## Post-deployment judge verification

1. Open `proof/deployment.json` → confirm package on suiscan
2. Open `proof/testnet-results.json` → click each `explorer` URL
3. Confirm vault balance decreased after treasury disbursement
4. Confirm agent rejection tx shows abort (not success)
5. Confirm guardian mandate status = Restricted
6. Open Command Center live mode → mandate ID matches `testnet-results.json`

---

_Phase 7.1 — deployment readiness only. Protocol, SDK, and Command Center code frozen._
