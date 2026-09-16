# Screen Data Sources — Command Center

**Network RPC:** `https://fullnode.testnet.sui.io:443` (via `@mysten/sui/client` `getFullnodeUrl('testnet')`)  
**Package ID:** `VITE_MANDATEOS_PACKAGE_ID` → `0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713`  
**PTB shim:** `VITE_MANDATEOS_PTB_SHIM_PACKAGE_ID` → `0x62148461af79d28034bee14c7300fe873d878eab11cc92d3bd869eefc8c7a00b`  
**Cache:** Wallet state in `localStorage` key `mandateos-wallet-state:{address}`; DefiLlama yields in `sessionStorage` (`mandateos-sui-yields`, 5 min); CoinGecko proxied via app `/api/coingecko` when enabled.

Object IDs are **per wallet** after Create Treasury — discovered by `discoverWalletTreasury()` (`getOwnedObjects` + type filter). No shared mandate env IDs in production.

---

## `/app/account` — Treasury Account

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Mandate / vault graph | `discoverWalletTreasury` + store | `sui_getOwnedObjects`, `sui_multiGetObjects` | `FinancialMandate`, `TreasuryConfig`, vault shared object | On wallet connect; `refreshMandate()` after tx | Wallet-scoped Zustand + localStorage |
| Balances, runway | `MandateOSReader.loadView` | `multiGetObjects` on graph IDs | `vaultId`, obligation registry | 30s poll via `useLiveMandate` / post-tx | In-memory `view` |
| Obligations | Obligation registry object | `multiGetObjects` | `obligationsId` | Same as mandate | `view.obligations` |
| Execution receipts | Package events + proofs | `sui_getTransactionBlock`, event query | mandate package events | On tx + event subscription | `txProofs` in wallet storage |
| Create Treasury | `useMandateLifecycle.createTreasury` | Wallet-signed PTB | Creates new mandate/vault IDs | N/A | Updates store after RPC verify |

---

## `/app/portfolio` — Portfolio

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Wallet SUI balance | `useAuth` | `sui_getBalance` | Owner address | On connect | React state |
| Owned objects table | `useAuth.getOwnedObjects` | `sui_getOwnedObjects` (limit 100) | All owned | On connect | React state |
| Receipt / obligation counts | `useAuth` filtered types | `getOwnedObjects` + type parse | Receipt, obligation types | On connect | React state |
| Holdings / PnL / Sharpe | `buildPortfolioView(view, wallet, prices)` | Mandate objects + CoinGecko | `vaultId`, wallet coins | Mandate refresh + market hook | `view` + `useMarketData` |
| Pre-treasury | Wallet RPC only | `getBalance`, `getOwnedObjects` | — | On connect | — |

---

## `/proof` — Proof Center

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Transaction proofs | `mandateStore.txProofs` | `sui_getTransactionBlock` | — | On new tx; manual open | Wallet localStorage |
| Mandate / vault refs | `treasuryGraph` | Discovery RPC | Per-wallet IDs | On connect | Store |

---

## `/app/yield-hub` — Investment Workflow

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Create / fund / simulate / execute | `usePtbWorkflows` | Wallet PTB → fullnode execute | `investmentGraph.*` after create | After each tx | `investmentGraph` in store |
| Protocol deposits (Navi etc.) | **Not implemented** | — | — | — | Actions disabled |

---

## `/app/payroll`, `/app/subscriptions`, `/app/revenue`

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Workflow graph | `usePtbWorkflows` + store | PTB create + `multiGetObjects` | Per-workflow mandate/vault/config | Post-create tx | `payrollGraph`, etc. |
| Simulate / execute | Move package simulation approval | PTB + wallet sign | `SimulationApproval` object | Per action | `pendingApprovals` in store |

---

## `/app/guardian-actions`

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Guardian evaluate/simulate/execute | `usePtbWorkflows` | PTB | Treasury `guardianPolicyId` | Per action | Store |

---

## `/app/markets` — Market Terminal

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Asset catalog | `useMarketCatalog` | CoinGecko `/api/coingecko` | — | 120s | In-memory |
| Order book / tape | Derived model | Built from catalog price/vol | — | 120s | Not live exchange |
| DeepBook routes | Advisory | SDK routing helpers | — | On catalog load | — |

---

## `/agents`, `/capital`, `/risk`, `/position`, `/guardian`

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Scores / agents / risk budget | SDK builders on `view` | `MandateOSReader` | Full treasury graph | 30s + post-tx | `view` |
| Execute / simulate panel | `useMandateLifecycle` | PTB | mandate, vault, approval IDs | Per click | Proofs store |

---

## `/overview`, `/obligations`, `/objectives`

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| All metrics | `view` from mandate reader | `multiGetObjects` | Graph IDs | 30s | Store |

---

## `/app/yield-tokens`, `/yield`

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Tokenization / strategies | `buildYieldTokenization`, `buildYieldStrategies` | **SDK derived — not on-chain Kamo** | — | On `view` load | **Stub — see STUB_AUDIT.md** |

---

## `/demo`, `/scenarios`, `/judge-audit`

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Demo fixtures | `demoState.ts` | None | `0xDEMO_*` | Static | `demoMode=true` |
| Judge audit table | `metricAuditRegistry.ts` | Meta (documents other screens) | — | On mount | — |

---

## `/hub` — Command Hub

| Field | Data source | RPC / API | Object IDs | Refresh | Cache |
|-------|-------------|-----------|------------|---------|-------|
| Desk tiles | `DeskMockups.tsx` | None (CSS mockups) | — | Static | — |

---

## Global hooks

| Hook | Purpose | Refresh |
|------|---------|---------|
| `useWalletMandateSync` | Discover treasury on connect | Connect + manual refresh |
| `useMandateEvents` | Subscribe package events for activity | WebSocket/poll when `view` set |
| `useMandateBootstrap` | Sandbox demo load/unload by route | Route change |
| `NetworkStatusBar` | RPC latency, package ID display | Periodic ping |

---

## Post-upgrade verification commands

```powershell
npm run testnet:reality-audit    # upgrade + dual-wallet treasury + FINAL_REALITY_REPORT.md
npm run testnet:watch-upgrade    # poll governor until funded, then audit
```

Governor (upgrade signer): `0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b`  
Slush test wallet: `0xf6472cc0e5ce9f56e22619c0bc12b8c789fe2fe0c8d2be3f7f0f13eadd91e768`
