# Template Deployment Audit

End-to-end trace of the marketplace template deployment pipeline (post-fix).

## Failure point (before fix)

| Step | File | Function | Result | Failure |
|------|------|----------|--------|---------|
| Button click | `TemplatesPage.tsx` | `deploy()` | OK | Real handler calls `deployTemplate(slug)` |
| Wallet | `useTemplateDeployment.ts` | `deployTemplate` | OK | Requires `auth.address` + `auth.dappKitConnected` |
| PTB build | `template-deployment.ts` | `buildTemplateCreateTx` | OK | Real Move PTB via `MandateOSClient` |
| Sign + execute | `useMandateTransaction.ts` | `executeTx` → `signAndExecute` | OK | First Slush approval creates mandate on-chain |
| Parse treasury | `parsers.ts` | `parseCreatedTreasury` / `parseCreated*` | OK | Reads `objectChanges` from RPC |
| **Obligations** | `useTemplateDeployment.ts` | `for` loop + `executeTx` | **FAIL** | **One separate PTB per obligation (2–4 extra Slush prompts). Flow stopped after first approval when subsequent signatures were not completed; `setDeployedTemplate`, proof, and redirect never ran.** |
| Graph refresh | `mandateStore.ts` | `refreshMandate` | PARTIAL | Stale `treasuryGraph` could shadow new payroll/revenue/investment mandates |
| Proof | `mandateStore.ts` | `addTxProof` | NEVER REACHED | Blocked by obligation loop |
| Redirect | `TemplatesPage.tsx` | `navigate` | NEVER REACHED | Blocked by obligation loop |

## Fix applied

1. **Batch obligations** — `MandateOSClient.buildRegisterObligationsBatchTx` registers all template obligations in **one PTB** (one additional Slush approval).
2. **Persist graph immediately** after create — `applyTemplateDeploymentGraph` clears stale graphs and writes to `localStorage` before obligations.
3. **Refresh mandate** after create so Treasury Account / Objectives / Obligations gates load chain view.
4. **Obligation batch is best-effort** — treasury + proof + redirect complete even if obligation batch fails.
5. **`refreshMandate` prefers `deployedTemplate.mandateId`** so specialized mandates are not shadowed by an old treasury graph.

## Pipeline (after fix)

| Step | File | Function | On-chain? |
|------|------|----------|-----------|
| 1 Button | `TemplatesPage.tsx` | `deploy(slug)` | — |
| 2 Wallet | `useAuth.ts` | `useEffectiveWalletAddress` | — |
| 3 Plan | `template-deployment.ts` | `buildTemplateDeploymentPlan` | — |
| 4 PTB | `template-deployment.ts` | `buildTemplateCreateTx` | Move `create` + `share_all` |
| 5 Sign | `useMandateTransaction.ts` | `signAndExecute` | Wallet signature |
| 6 Execute | `useMandateTransaction.ts` | `waitForTransaction` | Sui testnet |
| 7 Parse | `parsers.ts` | `parseCreated*` | Object IDs from effects |
| 8 Persist | `mandateStore.ts` | `applyTemplateDeploymentGraph` | `localStorage` `mandateos-wallet-state:{wallet}` |
| 9 Refresh | `mandateStore.ts` | `refreshMandate` | `MandateOSReader.fetchMandateView` |
| 10 Obligations PTB | `template-deployment.ts` | `buildTemplateObligationBatchTx` | `register_obligation` × N in one tx |
| 11 Guardian | `template-deployment.ts` | `GUARDIAN_BY_SLUG` + on-chain `GuardianPolicy` at bootstrap | Metadata + chain policy object |
| 12 Proof | `mandateStore.ts` | `addTxProof` | `txProofs` in wallet bundle |
| 13 Redirect | `TemplatesPage.tsx` | `navigate(templateWorkflowRoute(slug))` | React router |

## Storage locations

| Data | Location |
|------|----------|
| Mandate graph | `localStorage` → `mandateos-wallet-state:{wallet}` → `treasuryGraph` / `payroll` / etc. |
| Template metadata | Same bundle → `deployedTemplate` |
| Proofs | Same bundle → `txProofs[]` |
| Live mandate view | Zustand `mandateStore.view` (refreshed from chain) |

## Per-template deployment spec

| Template | Slug | Objectives (persisted) | Obligations (batch PTB) | Guardian | Redirect |
|----------|------|------------------------|-------------------------|----------|----------|
| Startup Treasury | `startup-treasury` | 3 objectives | 3 obligations | standard | `/app/account` |
| DAO Treasury | `dao-treasury` | 3 objectives | 3 obligations | governance weighted | `/app/account` |
| Payroll Treasury | `payroll` | 3 objectives | 2 obligations | payroll protection | `/app/payroll` |
| Creator Treasury | `creator-treasury` | 3 objectives | 3 obligations | subscriber revenue monitoring | `/app/subscriptions` |
| Protocol Treasury | `protocol-treasury` | 4 objectives | 4 obligations | strict reserve enforcement | `/app/account` |
| Investment Treasury | `investment-treasury` | 3 objectives | 3 obligations | risk-budget gated | `/app/yield-hub` |
| Revenue Routing | `revenue-routing` | 3 objectives | 2 obligations | distribution monitoring | `/app/revenue` |
| Treasury Preservation | `treasury-preservation` | 4 objectives | 2 obligations | strict | `/app/account` |

Proof ID format: `{createDigest}-template-{slug}`
