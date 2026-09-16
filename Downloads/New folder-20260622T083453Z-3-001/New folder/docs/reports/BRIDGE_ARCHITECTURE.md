# Bridge Architecture — TITAN Programmable Money

**Classification policy:** Bridge features use `IMPLEMENTED`, `NOT VERIFIED`, or `BLOCKED` only. Bridge is **never** `CHAIN_VERIFIED` until a formal cross-chain verification sprint completes after upstream DeFi and routing dependencies.

## Purpose

Cross-network capital movement is a **programmable financial action** inside MandateOS capital deployment—not a standalone product surface. Bridge steps sit between Treasury release, multi-protocol Allocation, destination-network settlement, and DeFi protocol deposit.

```
Treasury → Allocation → Bridge → Destination Network → DeFi Protocol → Portfolio Reconciliation
```

## Layer model

| Layer | Location | Responsibility | Status |
|-------|----------|----------------|--------|
| SDK | `packages/mandateos-sdk/src/bridge/` | Routes, risk policy, proof parsing, Wormhole PTB stub, portfolio mapping, tracking | IMPLEMENTED |
| Workflow | `packages/command-center/src/hooks/useBridgeWorkflow.ts` | Wallet-signed Slush execution, mandate linkage, Proof Center writes | IMPLEMENTED |
| Proof | `bridge-proof.ts` + `mandateStore` + `proofExport.ts` | Digest, route, phase, parent workflow digest, `NOT VERIFIED` classification | IMPLEMENTED |
| Portfolio | `bridge-integration.ts` + `PortfolioPage` | Bridge entries from Proof Center only—no simulated balances | IMPLEMENTED |
| Risk | `bridge-risk.ts` | Mandate link, amount caps, route blockers | IMPLEMENTED |
| Tracking | `bridge-tracking.ts` | Phase map from stored proofs (source → relay → destination) | NOT VERIFIED |

## SDK modules

- **`types.ts`** — Shared types; all bridge proofs carry `classification: 'NOT VERIFIED'`.
- **`bridge-registry.ts`** — Route catalog (Wormhole-first). All provider PTBs currently **BLOCKED**.
- **`bridge-risk.ts`** — Pre-flight gate; rejects unknown routes, blocked providers, missing mandate link, over-limit amounts.
- **`bridge-proof.ts`** — Parses wallet-signed source transaction into `BridgeTxProof`.
- **`wormhole-adapter.ts`** — `buildWormholeBridgeTransaction()`; throws until Wormhole package IDs are configured.
- **`bridge-integration.ts`** — `bridgeEntriesFromProofs()`, `buildBridgeImplementationSnapshot()`.
- **`bridge-tracking.ts`** — `trackBridgeTransfers()` from Proof Center records.

## Workflow integration

Bridge is embedded in capital flows—not routed as its own app page:

1. **Capital Allocation page** — `BridgeCapitalPanel` after allocation weights; links to prior allocation digest when present.
2. **Programmable chain** — `treasury-allocate-bridge-defi` in `programmable-chains.ts` orchestrates Investment → Allocation → Bridge → Navi deposit via `useProgrammableChains`.
3. **Treasury mandate** — Risk policy requires `mandateId` / `vaultId` on transfer intent.

## Proof Center evidence

Each successful bridge source PTB produces a `TxProofRecord` with:

- `category: 'bridge'`
- `workflowType: 'bridge'`
- `bridgeRouteId`, `bridgePhase`, `bridgeProvider`
- `parentWorkflowDigest` (allocation or investment proof when chained)
- `bridgeClassification: 'NOT VERIFIED'`

Exported `proof.json` includes the same fields for offline verification scripts.

## Portfolio reconciliation

`bridgeEntriesFromProofs()` maps wallet-scoped proofs into `BridgePortfolioEntry` rows shown on Portfolio when bridge proofs exist. Amounts and phases come from Proof Center only; destination balances are not fabricated.

## Risk controls

Default policy (`DEFAULT_BRIDGE_RISK_POLICY`):

- Max single transfer: 500 SUI (mist)
- Daily limit field reserved for future aggregation
- `requireMandateLink: true` — ties bridge to programmable treasury
- Blocked routes fail closed before wallet prompt

## Transaction tracking

Phases: `initiated` → `source_confirmed` → `relaying` → `destination_confirmed` | `failed`.

Today only **source_confirmed** is writable when a source PTB succeeds. Relayer and destination updates require provider integration (**NOT VERIFIED**).

## Dependency gate (verification sprint)

Bridge verification is **blocked** until these are `CHAIN_VERIFIED`:

- Navi
- Scallop
- Cetus
- Allocation
- Browser Verification
- Cross Protocol Routing

Until then: implementation may proceed; no bridge readiness or acceptance claims.

## Network context

Production treasury runs on **testnet**; DeFi adapters target **mainnet**. Primary route `sui-testnet-to-mainnet-sui` closes the treasury→DeFi network gap once Wormhole PTB builder is wired.
