# PTB Shim / Chain Sync Failure Audit

## Symptom

```
Chain sync failed: MANDATEOS_PTB_SHIM_PACKAGE_ID is required for simulation PTBs (publish mandateos-ptb-shim).
```

Treasury Account cannot load; Create Mandate / Fund 0.15 SUI appear broken after template deploy.

---

## 1. Is mandateos-ptb-shim published?

**Yes — on Sui testnet.**

| Field | Value |
|-------|-------|
| **Package ID (current v2)** | `0x70cba71ba84b852a83c66f3cddad429c98d082cffdc7638fa21e98faecf26af9` |
| **Original package ID (v1)** | `0x62148461af79d28034bee14c7300fe873d878eab11cc92d3bd869eefc8c7a00b` |
| **Network** | `testnet` |
| **Publish/upgrade tx digest** | `ASNpSxHi9FCrXbSP51f8Gsv71CawqxuU4X19r27Z3HYD` |
| **Upgrade cap** | `0x0859b8c220a7610d57a7cfad886fe45a1cc62e7ce7f6d5776b9340c400d16b78` |

Sources: `mandateos-ptb-shim/Published.toml`, `proof/deployment.json`, on-chain `sui_getObject` (2026-06-21).

---

## 2. Root cause

**Two independent failures:**

### A. Code bug — read path incorrectly required PTB shim

`refreshMandate()` constructs `MandateOSReader` which called `resolveConfig()`. That function **always** requires `ptbShimPackageId`, even though the reader never builds simulation PTBs.

**Affected file:** `packages/command-center/src/store/mandateStore.ts` line ~451

```typescript
// BEFORE (broken)
new MandateOSReader(client, { packageId: appConfig.packageId });
// Missing ptbShimPackageId; browser has no process.env.MANDATEOS_PTB_SHIM_PACKAGE_ID → throw
```

**Throw site:** `packages/mandateos-sdk/src/config.ts` → `resolveConfig()`

### B. Vercel missing runtime env (only `VITE_DEMO_MODE` configured)

`vercel env ls` for `command-center-five-eta` showed **only** `VITE_DEMO_MODE`. Missing:

- `VITE_MANDATEOS_PACKAGE_ID`
- `VITE_MANDATEOS_PTB_SHIM_PACKAGE_ID`
- `VITE_SUI_NETWORK`
- `VITE_UPGRADE_VERIFIED`

`.env.production` is gitignored; Vercel remote builds do not receive those values unless set in the Vercel dashboard. Write-path PTBs (`getMandateClient()` → `MandateOSClient`) still require the shim ID at build time via `import.meta.env.VITE_MANDATEOS_PTB_SHIM_PACKAGE_ID`.

---

## 3. Why Create Mandate and Fund 0.15 SUI are blocked

| Action | Blocker |
|--------|---------|
| **Treasury Account load** | `refreshMandate()` throws → `MandateViewGate` shows error, `view` stays `null` |
| **Create Mandate** | Uses `getMandateClient()` → `resolveConfig()` throws if `VITE_MANDATEOS_PTB_SHIM_PACKAGE_ID` empty in bundle |
| **Fund 0.15 SUI** | Requires loaded `treasuryGraph` via `getGraph()`; if chain sync failed, graph may exist in localStorage but UI has no live `view` and fund fails with "No treasury mandate loaded" or same shim error |

Buttons render when `canExecute` is true (wallet + packageId ≠ 0x0 + upgrade verified). Clicks fail at runtime when SDK config resolves without shim.

---

## 4. Fix applied

| Change | File |
|--------|------|
| Split read vs write config | `packages/mandateos-sdk/src/config.ts` — `resolveReaderConfig()` (shim optional), `resolveConfig()` (shim required for PTBs) |
| Reader uses read config | `packages/mandateos-sdk/src/reader/mandate-reader.ts` |
| Pass full config to reader | `packages/command-center/src/store/mandateStore.ts` |
| Committed env template | `packages/command-center/.env.production.example` |
| Vercel env vars | Set on `command-center-five-eta` production |

---

## 5. Env source map

| Variable | Local source | Vercel source | Baked into bundle |
|----------|--------------|---------------|-------------------|
| `VITE_MANDATEOS_PACKAGE_ID` | `.env.production` | Vercel project env | `appConfig.packageId` |
| `VITE_MANDATEOS_PTB_SHIM_PACKAGE_ID` | `.env.production` | Vercel project env | `appConfig.ptbShimPackageId` |
| `VITE_SUI_NETWORK` | `.env.production` | Vercel project env | `appConfig.network` |
| `VITE_UPGRADE_VERIFIED` | `.env.production` | Vercel project env | `executionGate.ts` |

Runtime read: `packages/command-center/src/lib/config.ts`  
Write client: `packages/command-center/src/lib/mandateClient.ts`  
Chain sync: `packages/command-center/src/store/mandateStore.ts` → `refreshMandate()`

---

## 6. Stale references (do not use)

| Location | Stale ID |
|----------|----------|
| `netlify.toml` | `0x62148461...` (v1 shim) |
| `proof/testnet-results.json` | `0x62148461...` |
| `docs/SCREEN_DATA_SOURCES.md` | `0x62148461...` |

Canonical shim: **`0x70cba71ba84b852a83c66f3cddad429c98d082cffdc7638fa21e98faecf26af9`**
