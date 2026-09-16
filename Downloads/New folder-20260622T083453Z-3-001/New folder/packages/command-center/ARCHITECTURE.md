# MandateOS Phase 5 — Product Architecture

Programmable Capital Operating System. Protocol frozen; product layer in SDK + Command Center.

## Stack

| Layer | Package | Role |
|-------|---------|------|
| Protocol | `mandateos/` (Move) | Immutable infrastructure — **not modified** |
| SDK Write | `@mandateos/sdk` → `MandateOSClient` | PTB transaction builders |
| SDK Read | `@mandateos/sdk` → `MandateOSReader` | `CommandMandateView` aggregation |
| SDK Product | `@mandateos/sdk` → `product/*` | Position NFT, ALMM buckets, router, risk, trace, templates |
| Frontend | `@mandateos/command-center` | Financial Command Center UI |

## Page Hierarchy

```
/                     Overview (dashboard + demo flows)
/objectives           Objectives + compliance
/obligations          Obligation registry
/capital              Adaptive Capital Engine (6 buckets)
/routes               Capital Router (orchestration paths)
/agents               Delegated agents + risk budget caps
/guardian             Guardian policy + pending actions
/risk                 Dynamic Risk Budget (live simulation)
/audit                Audit trail (on-chain events)
/trace                Execution Route Explorer
/position             MandatePositionNFT (Sui Display)
/templates            Template marketplace
/templates/:slug      Template detail + create CTA
```

## Component Hierarchy

```
Layout
├── Sidebar (nav)
├── DemoBanner
└── Page
    ├── StatCard / OverviewStats
    ├── BucketChart          (WS2: Adaptive Capital Engine)
    ├── CapitalRouteViz      (WS3: Capital Router)
    ├── RiskBudgetPanel      (WS4: Dynamic Risk Budget)
    ├── ExecutionTrace       (WS5: Route Explorer)
    ├── PositionNftCard      (WS1: Position NFT)
    └── TemplateGrid         (WS6: Template Marketplace)
```

## SDK Integration Map

| Workstream | SDK Module | Frontend Consumer |
|------------|------------|-------------------|
| Position NFT | `product/position-nft.ts` | `PositionPage`, `OverviewPage` |
| Adaptive Capital | `product/capital-engine.ts` | `CapitalPage`, `BucketChart` |
| Capital Router | `product/capital-router.ts` | `RoutesPage`, `CapitalRouteViz` |
| Risk Budget | `product/risk-budget.ts` | `RiskPage`, `AgentsPage` |
| Route Explorer | `product/execution-trace.ts` | `TracePage`, `ExecutionTrace` |
| Templates | `product/templates.ts` | `TemplatesPage`, `TemplateGrid` |
| Read Model | `reader/mandate-reader.ts` | `useMandateStore` → all pages |
| Write Model | `client.ts` | Template create CTAs, future wallet flows |

## State Management

**Zustand** (`store/mandateStore.ts`):

- `view: CommandMandateView | null` — single source of truth from `MandateOSReader` or demo
- `demoMode: boolean` — switches between demo data and on-chain fetch
- `selectedTrace: ExecutionRouteTrace` — route explorer selection
- `guardianReallocating: boolean` — capital page animation state

**Future on-chain path:**

```typescript
const reader = new MandateOSReader(suiClient, { packageId });
const view = await reader.fetchMandateView(graph);
useMandateStore.getState().setView(view);
```

## Demo Flow Support

| Demo | SDK Methods | UI Entry |
|------|-------------|----------|
| Startup Treasury | `buildCreateTreasuryTx`, `buildFundVaultTx`, `buildSimulateTreasuryDisbursementTx`, `buildExecuteTreasuryDisbursementTx` | Overview demo list + Templates → Startup Treasury |
| Payroll | `buildCreatePayrollTx`, `buildExecutePayrollTx` | Templates → Payroll |
| Agent Delegation | `buildIssueExecutorCapTx`, `computeRiskBudget` | Agents + Risk pages |
| Guardian Remediation | `buildEvaluateAndShareGuardianTx`, `buildSimulateAndApproveTx`, `buildExecuteGuardianActionTx` | Guardian + Capital reallocation preview |

## Run

```bash
npm install
npm run build
npm run dev:cc    # http://localhost:5173
```

Set `VITE_MANDATEOS_PACKAGE_ID` after publishing Move package for live reads.
