# TypeScript Remediation Report

Generated: 2026-06-21  
Command: `npx tsc -p packages/command-center/tsconfig.json --noEmit`  
Result: **FAIL** — **62 errors** across **35 files**  
SDK: **PASS** (`npx tsc -p packages/mandateos-sdk/tsconfig.json --noEmit`)

**Status:** Analysis only — **no code changes performed.** Awaiting approval before remediation.

---

## Executive summary

| Classification | Count | Production-reachable | Likely real bugs |
|----------------|------:|---------------------|-----------------:|
| **A. DeFi integration typing** | 9 | 9 | 2–4 |
| **B. Wallet typing** | 22 | 8 (main app wallet path) | 0–1 |
| **C. Hook signature mismatch** | 18 | 14 | 5–6 |
| **D. Route / component typing** | 7 | 3 | 0 |
| **E. Dead / hidden route code** | 3 | 0 (routes hidden) | 1 (stale SDK field names) |
| **F. Miscellaneous** | 1 | 0 (transitive dep shim) | 0 |
| **Total** | **62** | **~34** | **~8–12** |

**Current CI gap:** Vite build does not run `tsc`. Production deploy passes while strict TypeScript fails.

**Target scripts (to add during remediation):**
- Root: `"typecheck": "npm run typecheck -w @mandateos/command-center && npm run build:sdk"`
- CC package: `"typecheck": "tsc -p tsconfig.json --noEmit"`, `"lint": "tsc -p tsconfig.json --noEmit"` (or ESLint when added)

---

## Error taxonomy

| Label | Meaning |
|-------|---------|
| **Real bug** | Incorrect types likely reflect missing/wrong runtime values |
| **Type-only** | Runtime behavior OK; strict TS or library version drift |
| **Legacy / hidden** | File on `productionHidden` or simulation route |
| **Dead code** | Orphaned or superseded module |

---

## A. DeFi integration typing (9 errors)

| File | Line | Error | Severity | Production? | Classification | Fix recommendation |
|------|------|-------|----------|-------------|----------------|-------------------|
| `components/DeFiProtocolPanel.tsx` | 35 | `string` not assignable to `bigint` | Medium | **Y** (protocol desks) | Type-only / API drift | Use `BigInt(amountMist)` or align formatter with `formatMist` signature |
| `components/NaviCapitalPanel.tsx` | 32 | `string` not assignable to `bigint` | Medium | **Y** (`/app/navi-capital`) | Type-only | Pass `BigInt(...)` to mist formatter |
| `components/NaviCapitalPanel.tsx` | 180 | same | Medium | **Y** | Type-only | same |
| `components/NaviCapitalPanel.tsx` | 181 | same | Medium | **Y** | Type-only | same |
| `hooks/useDefiProtocolWorkflow.ts` | 70 | `SuiTransactionBlockResponse` vs gas helper type; `effects` may be `null` | Medium | **Y** (DeFi deploy) | Type-only | Widen gas helper to accept `SuiTransactionBlockResponse` or null-guard `res.effects` |
| `hooks/useNaviWorkflow.ts` | 49 | same as above | Medium | **Y** (Navi workflow) | Type-only | same pattern as `useBridgeWorkflow` fix |
| `hooks/useMandateTransaction.ts` | 110 | `"devnet"` not in SDK network union | Low | **Y** (all PTBs) | Type-only | Narrow `appConfig.network` or extend SDK type if devnet supported |
| `lib/proofExport.ts` | 52 | `string` not assignable to network literal union | Low | **Y** (Proof export) | Type-only | Cast via validated network enum from `appConfig` |
| `pages/PortfolioPage.tsx` | 352–353 | `string` not assignable to `bigint` | Medium | **Y** (`/app/portfolio`) | Type-only | `BigInt(position.amountMist)` or fix display helper types |

**Production impact:** DeFi panels and portfolio remain functional at runtime (Vite transpile-only). Mist formatting and gas logging need typed fixes, not suppressions.

---

## B. Wallet typing (22 errors)

| File | Line | Error | Severity | Production? | Classification | Fix recommendation |
|------|------|-------|----------|-------------|----------------|-------------------|
| `lib/bootstrapWalletRegistry.ts` | 73 | `wallet.id` may be `undefined` | Low | **Y** (app bootstrap) | Type-only | Filter wallets with `id` defined or use `wallet.id ?? wallet.name` |
| `lib/initWalletStandard.ts` | 9, 13 | `string \| undefined` to `string` | Low | **Y** | Type-only | Guard before `logWalletDetails` / event handlers |
| `lib/initWalletStandard.ts` | 38–39 | `Wallet` vs `WalletWithRequiredFeatures` | Medium | **Y** | Type-only | Use type guard `isWalletWithRequiredFeatures(w)` before subscribe |
| `lib/initWalletStandard.ts` | 44–45 | `string \| undefined` | Low | **Y** | Type-only | Narrow `wallet.id` before use |
| `lib/slushAccountInspector.ts` | 94 | `WalletAccount` → `Record<string, unknown>` unsafe | Low | N (probe HTML) | Type-only | Cast via `unknown` first or typed property reader |
| `lib/slushAccountInspector.ts` | 184 | `string \| undefined` | Low | N | Type-only | Default or guard |
| `lib/walletAccountProbe.ts` | 183, 215, 235, 248, 272, 305, 324 | `string \| undefined` in probe rows | Low | N (dev probes) | Type-only | Use `wallet.id ?? 'unknown'` |
| `lib/walletAccountProbe.ts` | 342 | comparison row `id` optional | Low | N | Type-only | Align `WalletComparisonRow.id` or filter |
| `lib/walletDebug.ts` | 32 | snapshot `id` optional | Low | **Y** (connect path) | Type-only | `id: wallet.id ?? ''` in snapshot type |
| `wallets/slushEnvironmentProbe.ts` | 77, 90 | `string \| undefined` | Low | **Y** (Slush restore) | Type-only | Guard `wallet.id` before map keys |
| `wallets/useSlushWalletSync.ts` | 70 | `Wallet` vs `WalletWithRequiredFeatures` | Medium | **Y** (all routes) | Type-only | Narrow wallet before `subscribeWalletEvents` |
| `wallets/WalletDiagnosticProbe.tsx` | 143, 181, 183 | `string \| undefined` | Low | N (`/dev/wallet-diagnostics`) | Legacy / hidden | Fix or exclude from `tsc` include for dev-only |

**Production impact:** Wallet connect/sync works in production; errors are strict-null and Wallet Standard generic typing. No `@ts-ignore` needed — use guards and narrowed types.

---

## C. Hook signature mismatch (18 errors)

| File | Line | Error | Severity | Production? | Classification | Fix recommendation |
|------|------|-------|----------|-------------|----------------|-------------------|
| `hooks/useProofVerification.ts` | 7 | Cannot find module `./proofExport` | **High** | **Y** (`/proof`) | **Real bug** (type import path) | Change to `import type { ProofExportDocument } from '../lib/proofExport'` |
| `hooks/usePtbWorkflows.ts` | 144 | Missing `receiptHolder` in `ExecutePayrollParams` | **High** | **Y** (`/app/payroll`) | **Real bug** | Pass `receiptHolder: account.address` (or vault governor) in all execute builders |
| `hooks/usePtbWorkflows.ts` | 209 | Missing `receiptHolder` in subscription execute | **High** | **Y** | **Real bug** | same |
| `hooks/usePtbWorkflows.ts` | 273 | Missing `receiptHolder` in revenue execute | **High** | **Y** | **Real bug** | same |
| `hooks/usePtbWorkflows.ts` | 344 | Missing `receiptHolder` in investment execute | **High** | **Y** | **Real bug** | same |
| `hooks/useMandateEvents.ts` | 49 | `'Package'` not in `SuiEventFilter` | Medium | **Y** (activity stream) | Type-only / SDK drift | Use `{ MoveEventModule: { package: ... } }` or `{ MoveEventType: ... }` per `@mysten/sui` 1.45 filter API |
| `pages/PayrollPage.tsx` | 100–106 | Workflow handlers return `SuiTransactionBlockResponse` but shell expects `Promise<void>` | Low | **Y** | Type-only | Wrap handlers: `async () => { await onExecute(); }` or widen `PtbWorkflowShell` props |
| `pages/RevenuePage.tsx` | 101–107 | same | Low | **Y** | Type-only | same |
| `pages/SubscriptionPage.tsx` | 76–77 | same | Low | **Y** | Type-only | same |
| `pages/YieldHubPage.tsx` | 85–87 | same | Low | **Y** | Type-only | same |

**Production impact:** `receiptHolder` omissions are the highest risk — SDK PTB builder expects a receipt destination address. Missing values may cause failed transactions or incorrect object transfers. **Priority 1 fix.**

---

## D. Route / component typing (7 errors)

| File | Line | Error | Severity | Production? | Classification | Fix recommendation |
|------|------|-------|----------|-------------|----------------|-------------------|
| `components/CapitalFlowSankey.tsx` | 90 | Recharts `Formatter` — `value` may be `undefined` | Low | **Y** (Treasury Account, Proof Center) | Type-only | `(value: number \| undefined) => ...` with guard |
| `pages/OverviewPage.tsx` | 72, 121 | `"unavailable"` not in `DataSourceBadgeSource` | Low | N (`/overview` hidden) | Legacy / hidden | Add `'unavailable'` to badge union or map to `'derived'` |
| `pages/OverviewPage.tsx` | 161, 172 | Recharts formatter undefined value | Low | N | Legacy / hidden | Formatter signature fix |
| `pages/PortfolioPage.tsx` | 262 | Recharts formatter | Low | **Y** | Type-only | Formatter signature fix |
| `pages/DeepBookPage.tsx` | 180 | `view.ids` does not exist on `CommandMandateView` | Medium | N (`/protection` hidden) | Legacy / hidden | Use `view.ref.mandateId` or remove page |

**Production impact:** `CapitalFlowSankey` and `PortfolioPage` chart tooltips are production-reachable; fixes are Recharts v3 typing only.

---

## E. Dead / hidden route code (3 errors)

| File | Line | Error | Severity | Production? | Classification | Fix recommendation |
|------|------|-------|----------|-------------|----------------|-------------------|
| `hooks/useStrategies.ts` | 26 | `portfolioRiskScore` → use `portfolioScoreBps` | Medium | N (`/app/strategies` hidden) | **Real bug** (stale SDK field) | Rename property or delete hook if route removed |
| `hooks/useStrategies.ts` | 127 | `efficiency` missing on `CapitalScores` | Medium | N | Legacy / hidden | Use correct SDK score field or delete |
| `lib/treasuryAssetContext.ts` | 23 | `protocol` missing on `PortfolioHolding` | Low | N (only via hidden `/app/trade`) | Type-only | Extend SDK type or use `(h as { protocol?: string }).protocol` — prefer SDK alignment |

**Deletion candidate:** If `/app/strategies` and simulated trade terminal are removed, `useStrategies.ts`, `StrategiesPage.tsx`, `treasuryAssetContext.ts`, and `useMarketTerminal` chain can be deleted instead of fixed.

---

## F. Miscellaneous (1 error)

| File | Line | Error | Severity | Production? | Classification | Fix recommendation |
|------|------|-------|----------|-------------|----------------|-------------------|
| `shims/deepmerge.ts` | 5 | No declaration file for `deepmerge` CJS import | Low | N (Scallop SDK transitive) | Type-only | Add `src/types/deepmerge.d.ts` module declaration or import from `'deepmerge'` package entry |

---

## Classification matrix (all 62 errors)

| # | File:Line | Category | Real bug? | Production? | Hidden route? |
|---|-----------|----------|-----------|-------------|---------------|
| 1 | CapitalFlowSankey.tsx:90 | D | No | Y | No |
| 2 | DeFiProtocolPanel.tsx:35 | A | No | Y | No |
| 3–5 | NaviCapitalPanel.tsx:32,180,181 | A | No | Y | No |
| 6 | useDefiProtocolWorkflow.ts:70 | A | No | Y | No |
| 7 | useMandateEvents.ts:49 | C | Maybe | Y | No |
| 8 | useMandateTransaction.ts:110 | A | No | Y | No |
| 9 | useNaviWorkflow.ts:49 | A | No | Y | No |
| 10 | useProofVerification.ts:7 | C | **Yes** | Y | No |
| 11–14 | usePtbWorkflows.ts:144,209,273,344 | C | **Yes** | Y | No |
| 15–16 | useStrategies.ts:26,127 | E | Yes | N | Y (`/app/strategies`) |
| 17 | bootstrapWalletRegistry.ts:73 | B | No | Y | No |
| 18–22 | initWalletStandard.ts:9,13,38,39,44,45 | B | No | Y | No |
| 23 | proofExport.ts:52 | A | No | Y | No |
| 24–25 | slushAccountInspector.ts:94,184 | B | No | N | probe |
| 26 | treasuryAssetContext.ts:23 | E | No | N | Y (trade only) |
| 27–34 | walletAccountProbe.ts (8 sites) | B | No | N | probe |
| 35 | walletDebug.ts:32 | B | No | Y | No |
| 36 | DeepBookPage.tsx:180 | D | No | N | Y (`/protection`) |
| 37–40 | OverviewPage.tsx:72,121,161,172 | D | No | N | Y (`/overview`) |
| 41–43 | PayrollPage.tsx:100,101,106 | C | No | Y | No |
| 44–46 | PortfolioPage.tsx:262,352,353 | A/D | No | Y | No |
| 47–49 | RevenuePage.tsx:101,102,107 | C | No | Y | No |
| 50–51 | SubscriptionPage.tsx:76,77 | C | No | Y | No |
| 52–54 | YieldHubPage.tsx:85,86,87 | C | No | Y | No |
| 55 | shims/deepmerge.ts:5 | F | No | N | No |
| 56–57 | slushEnvironmentProbe.ts:77,90 | B | No | Y | No |
| 58 | useSlushWalletSync.ts:70 | B | No | Y | No |
| 59–61 | WalletDiagnosticProbe.tsx:143,181,183 | B | No | N | Y (dev route) |

---

## Prioritized remediation plan

### Priority 1 — Runtime behavior risk (fix first)

1. **`usePtbWorkflows.ts`** — Add `receiptHolder` to all four `buildExecute*Tx` calls (payroll, subscription, revenue, investment). Source: connected wallet address or mandate governor from graph.
2. **`useProofVerification.ts`** — Fix import path to `../lib/proofExport`.
3. **`useMandateEvents.ts`** — Update event filter to current `@mysten/sui` `SuiEventFilter` shape (verify subscription still receives package events).

**Estimated effort:** 1–2 hours · **Files:** 3 · **Risk if skipped:** PTB execute failures; Proof Center type import breaks strict CI.

### Priority 2 — DeFi workflows

4. **`useNaviWorkflow.ts` / `useDefiProtocolWorkflow.ts`** — Align gas-used helper with `SuiTransactionBlockResponse | null effects`.
5. **`NaviCapitalPanel.tsx`, `DeFiProtocolPanel.tsx`, `PortfolioPage.tsx`** — Fix `bigint` vs `string` formatters (consistent `BigInt` at boundary).
6. **`proofExport.ts`, `useMandateTransaction.ts`** — Network literal narrowing.

**Estimated effort:** 2–3 hours · **Files:** 7

### Priority 3 — Wallet interactions

7. **`useSlushWalletSync.ts`, `initWalletStandard.ts`** — Wallet Standard type guards.
8. **`bootstrapWalletRegistry.ts`, `walletDebug.ts`, `slushEnvironmentProbe.ts`** — Optional `id` guards.
9. **Probe-only files** — Fix or move under `src/dev/` excluded from production typecheck if desired.

**Estimated effort:** 2–4 hours · **Files:** 10+

### Priority 4 — Type-only cleanup

10. **`PtbWorkflowShell` + workflow pages** — Align callback return types (`Promise<void>` vs typed responses).
11. **Recharts formatters** — `CapitalFlowSankey`, `PortfolioPage`, `OverviewPage`.
12. **`shims/deepmerge.ts`** — Add ambient module declaration.
13. **Hidden routes** — Fix or delete `useStrategies`, `OverviewPage`, `DeepBookPage`, `treasuryAssetContext` chain.

**Estimated effort:** 3–5 hours · **Files:** 12+

### Infrastructure (required for PASS lint/typecheck)

14. Add to `packages/command-center/package.json`:
    ```json
    "typecheck": "tsc -p tsconfig.json --noEmit",
    "lint": "tsc -p tsconfig.json --noEmit"
    ```
15. Add to root `package.json`:
    ```json
    "typecheck": "npm run typecheck -w @mandateos/command-center",
    "lint": "npm run lint -w @mandateos/command-center"
    ```
16. (Optional) Add ESLint later; until then **`lint` = strict TypeScript pass**.

**Policy:** No `@ts-ignore`, `@ts-nocheck`, or blanket `any` unless documented exception (none identified).

---

## Updated deletion recommendations (post-typecheck strategy)

After typecheck passes, prefer **deletion over repair** for files that are hidden and failing:

| Path | Errors | Route | Recommendation |
|------|--------|-------|------------------|
| `hooks/useStrategies.ts` + `pages/StrategiesPage.tsx` | 2 | `/app/strategies` (SIMULATION, hidden) | **Delete** with route removal |
| `pages/OverviewPage.tsx` | 4 | `/overview` (hidden) | **Delete** or keep gated |
| `pages/DeepBookPage.tsx` | 1 | `/protection` (hidden) | **Delete** or fix one line |
| `lib/treasuryAssetContext.ts` | 1 | Only `useMarketTerminal` | **Delete** with trade terminal chain |
| `hooks/useSuiMarketTerminal.ts` | 0 | Orphan | **Delete** (unchanged) |
| `hooks/useMarketTerminal.ts`, `MarketTerminal.tsx`, `TradePage.tsx` | 0 | `/app/trade` (hidden) | **Delete** after route removal |
| `data/marketSeedCatalog.ts` | 0 | Orphan | **Delete** |
| `wallets/WalletDiagnosticProbe.tsx` + probe libs | 11+ | Dev / HTML probes | **Keep** but fix types OR exclude via separate `tsconfig.dev.json` |

**Do NOT delete (production + errors must be fixed):**

- `usePtbWorkflows.ts`, `useProofVerification.ts`, `useMandateEvents.ts`
- `NaviCapitalPanel`, `DeFiProtocolPanel`, `useNaviWorkflow`, `useDefiProtocolWorkflow`
- `CapitalFlowSankey`, `PortfolioPage`, wallet sync path (`useSlushWalletSync`, `initWalletStandard`)

---

## Validation gate (after remediation — not yet run)

| Command | Current | Target |
|---------|---------|--------|
| `npm run build` | PASS | PASS |
| `npm run lint` | N/A (missing script) | PASS |
| `npm run typecheck` | N/A (missing script) | PASS |

---

## Approval requested

Before implementing fixes, confirm:

1. **Proceed with Priority 1–2** (production PTB + DeFi + Proof Center)?
2. **Delete hidden simulation routes** instead of fixing (`useStrategies`, `OverviewPage`, trade terminal chain)?
3. **Add `typecheck`/`lint` scripts** to workspace `package.json` files?

**No production behavior will change until you approve the remediation plan.**
