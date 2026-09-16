# TITAN / MandateOS — Repository Feature Inventory

> Source of truth for README generation. Generated from full repository scan (routes, Move modules, SDK, proof, integrations).

## Product Identity

| Name | Role |
|------|------|
| **TITAN** | Command Center product — institutional programmable money terminal |
| **MandateOS** | On-chain Move protocol + TypeScript SDK |
| **Production URL** | https://command-center-five-eta-sandy.vercel.app |

---

## On-Chain Packages (Sui Testnet)

| Package | ID | Version |
|---------|-----|---------|
| MandateOS core | `0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13` | v5 |
| PTB Shim | `0x70cba71ba84b852a83c66f3cddad429c98d082cffdc7638fa21e98faecf26af9` | v2 |
| Smart Wallet Rules | `0x9c97a6e3ba609f114b8069334cf88f467217893f2a9c44301a8227f66b57b5ed` | v1 |

DeFi protocol integrations target **Sui mainnet** (Navi, Scallop, Cetus). Treasury MandateOS PTBs run on **testnet** in current deployment.

---

## Production Routes (21 sidebar + redirects)

### Liquidity Terminal
- `/app/markets` — Liquidity Terminal (DeepBook, DefiLlama, protocol-specific tables, deploy workflow)

### Portfolio
- `/app/portfolio` — Wallet, vault, DeFi positions, bridge panel

### Capital Deployment
- `/app/allocation` — Multi-protocol allocation (Navi → Scallop → Cetus)
- `/app/navi-capital` — Navi lending desk
- `/app/scallop-capital` — Scallop lending desk
- `/app/cetus-capital` — Cetus LP desk

### Financial Workflows
- `/app/payroll` — Payroll mandate PTB
- `/app/subscriptions` — Subscription mandate PTB
- `/app/revenue` — Revenue split PTB
- `/app/yield-hub` — Investment mandate PTB
- `/app/smart-wallet-rules` — On-chain automation rules (satellite package)
- `/app/guardian-actions` — Guardian evaluate / simulate / execute

### Treasury
- `/app/account` — Treasury account, registry, Sankey, activity
- `/obligations` — Obligation registry, waterfall, timeline
- `/objectives` — Charter objectives, covenant parameters

### Operations
- `/agents` — Agent delegation operations center
- `/audit` — Audit trail, on-chain registry, report export
- `/proof` — Proof Center (export, RPC verification)

### Hub & Templates
- `/hub` — Command Hub desk launcher
- `/templates` — Mandate template marketplace

---

## Move Modules (26 on-chain in core v5)

`mandateos`, `types`, `rules`, `objectives`, `constitutional`, `operational_risk`, `adaptive_liquidity`, `deepbook_forecast`, `workflow`, `simulation`, `validation`, `authority`, `financial_mandate`, `vault`, `receipts`, `delegation`, `guardian`, `intent`, `intent_compiler`, `templates`, `treasury_mandate`, `payroll_mandate`, `subscription_mandate`, `revenue_allocation_mandate`, `auto_investment_mandate`, `dao_treasury_mandate`

Satellite: `smart_wallet_rules` (mandateos-rules package)

---

## SDK (`@mandateos/sdk`)

- **Write**: `MandateOSClient` — all PTB builders
- **Read**: `MandateOSReader` — mandate decode, audit history
- **Product**: treasury intelligence, capital engine, obligation engine, templates, DeepBook intelligence (derived)
- **DeFi**: Navi, Scallop, Cetus adapters + position fetch
- **Proof**: `verifyProofDocument`, `verifyProofStep`
- **Smart wallet**: rules PTB builders (satellite package)

---

## Hooks (35) — grouped

| Domain | Hooks |
|--------|-------|
| Liquidity | `useLiquidityTerminal`, `useSuiMarketTerminal`, `useMarketTerminal`, `useMarketCatalog`, `useMarketData` |
| Portfolio | `usePortfolioEngine`, `useAllProtocolPositions`, `useExternalProtocolPositions`, `useMainnetWalletBalance` |
| Capital / DeFi | `useDefiProtocolWorkflow`, `useNaviWorkflow`, `useCapitalAllocator`, `useUnifiedAllocationPtb`, `useBridgeWorkflow`, `useProgrammableChains`, `useCapitalDeployment`, `useYieldAllocation`, `useSuiProtocolAdapters` |
| Mandate / PTB | `usePtbWorkflows`, `useMandateLifecycle`, `useMandateTransaction`, `useMandateBootstrap`, `useWalletMandateSync`, `useLiveMandate`, `useMandateEvents` |
| Proof | `useProofVerification` |
| Auth / Wallet | `useAuth`, `useSlushAuthorizationState` |
| Intelligence (derived) | `useTreasuryIntelligence`, `useGuardianIntelligence`, `usePositionIntelligence`, `useStrategies`, `useTradeImpact` |

---

## External Integrations

| Integration | Status | Code location |
|-------------|--------|---------------|
| DeepBook indexer | Live reads | `lib/deepbookIndexer.ts`, Vercel proxy `/api/deepbook` |
| DefiLlama yields | Live reads | `lib/liquidityTerminalData.ts` |
| Navi mainnet | Code complete, wallet-signed | `mandateos-sdk/defi/navi-integration.ts` |
| Scallop mainnet | Code complete | `mandateos-sdk/defi/scallop-integration.ts` |
| Cetus mainnet | Code complete | `mandateos-sdk/defi/cetus-integration.ts` |
| Slush wallet | Production connect | `SlushConnectButton`, dapp-kit |
| Sui RPC | Live | dapp-kit + SDK readers |
| Suiscan explorer | Links | `lib/explorer.ts` |
| Bridge (Wormhole) | Blocked / not verified | `mandateos-sdk/bridge/` |

---

## Proof Artifacts (`proof/`)

`deployment.json`, `judge-verification.json`, `smart-wallet-rules-verification.json`, `defi-verification.json`, `entrypoint-verification.json`, `upgrade-result.json`, schemas, fixtures

---

## Verification Scripts (`scripts/`)

`run-judge-verification.ts`, `verify-proof.mjs`, `verify-on-chain-entrypoints.mjs`, `run-defi-chain-verified.ts`, `deploy-vercel.ps1`, `push-vercel-env.ps1`

---

## Hidden in Production (analytics / simulation routes)

`/overview`, `/capital`, `/protection`, `/guardian`, `/risk`, `/position`, `/trace`, `/yield`, `/ecosystem`, `/app/trade`, `/app/advisor`, `/app/strategies`, `/app/liquidity`, `/app/yield-tokens`
