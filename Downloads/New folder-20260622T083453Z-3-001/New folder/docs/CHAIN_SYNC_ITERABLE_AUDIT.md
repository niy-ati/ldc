# Chain Sync "r is not iterable" Audit

## Symptom

```
Chain sync failed: r is not iterable
```

(`r` is the minified name for `authorities` in production bundles.)

## Trace path

```
Treasury Account
  → MandateViewGate (requires view)
    → refreshMandate()                     [mandateStore.ts:440]
      → MandateOSReader.fetchMandateView() [mandate-reader.ts:49]
        → fetchMandateBundle()             [fetch.ts:16] — RPC: sui_multiGetObjects
        → parseObjectives()                [fetch.ts:78]
        → parseObligations()               [fetch.ts:90]
        → parseGovernance()                [fetch.ts:112] ← FAILURE
        → buildCapitalAllocationView()     [capital-engine.ts] (never reached)
```

## Root cause

| Field | File | Function | Line | Variable | Expected | Actual |
|-------|------|----------|------|----------|----------|--------|
| `governance.authorities` | `fetch.ts` | `parseGovernance` | ~118 | `authorities` | `Iterable` (array) | **`VecMap` object** `{ type: "0x2::vec_map::VecMap<address, u8>", fields: { contents: [...] } }` |

**Failure line (before fix):**

```typescript
for (const entry of authorities) {  // authorities is NOT iterable
```

**RPC:** `sui_multiGetObjects` on `constitutionId` — data is valid; parser shape was wrong.

**Example mandate:** `0x25f5942ae242acfe4ec7987e5878dd84a8039a604608221ce8d61ff404b348f8`  
**Constitution:** `0xbcd14e389cf9a1ff6b333b9452badb181bc4d8ce12fc288b45873673871599b3`

## Secondary issues fixed

1. **`moveVectorItems`** — Move `vector` fields may be arrays OR numeric-key objects (`{0: ..., 1: ...}`).
2. **`fetchMandateBundle`** — skip invalid/empty object IDs in `multiGetObjects` (prevent `Invalid Sui Object id` when `guardianPolicyId` missing).

## Fix

- `decode.ts`: `moveVectorItems`, `vecMapEntries`, `moveStructFields`
- `fetch.ts`: `parseGovernance` uses `vecMapEntries`; `parseObligations` uses `moveVectorItems`
- `mandateSyncTrace.ts` + logging in `refreshMandate`

## Why Create Mandate / Fund were blocked

`MandateViewGate` requires `view !== null`. Sync threw before view hydration → panel showed chain error → Fund could not resolve graph.
