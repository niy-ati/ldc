# Bridge Implementation Plan

**Scope:** Architecture and code only. No bridge verification, readiness, or acceptance reports.

## Phase 1 — SDK foundation ✅ IMPLEMENTED

| Task | File(s) | Status |
|------|---------|--------|
| Bridge types and status enums | `bridge/types.ts` | IMPLEMENTED |
| Route registry | `bridge/bridge-registry.ts` | IMPLEMENTED (routes BLOCKED) |
| Risk assessment | `bridge/bridge-risk.ts` | IMPLEMENTED |
| Proof parsing | `bridge/bridge-proof.ts` | IMPLEMENTED |
| Wormhole PTB stub | `wormhole-adapter.ts` | BLOCKED |
| Portfolio + snapshot helpers | `bridge-integration.ts` | IMPLEMENTED |
| Transfer tracking | `bridge-tracking.ts` | NOT VERIFIED |
| Public exports | `src/index.ts` | IMPLEMENTED |

## Phase 2 — Workflow layer ✅ IMPLEMENTED

| Task | File(s) | Status |
|------|---------|--------|
| Wallet-signed bridge hook | `useBridgeWorkflow.ts` | IMPLEMENTED |
| Slush sign + source RPC execute | same | IMPLEMENTED (blocked at PTB build) |
| Mandate / vault linkage on intent | same | IMPLEMENTED |
| Parent digest from allocation chain | same | IMPLEMENTED |

## Phase 3 — Proof layer ✅ IMPLEMENTED

| Task | File(s) | Status |
|------|---------|--------|
| Extend `TxProofRecord` bridge fields | `mandateStore.ts` | IMPLEMENTED |
| Bridge category inference | `txParse.ts` | IMPLEMENTED |
| Proof export fields | `proofExport.ts` | IMPLEMENTED |
| Proof Center detail UI | `ProofCenterHub.tsx`, `TxProofCard.tsx` | IMPLEMENTED |

## Phase 4 — Capital deployment UI ✅ IMPLEMENTED

| Task | File(s) | Status |
|------|---------|--------|
| Embedded bridge panel (not standalone route) | `BridgeCapitalPanel.tsx` | IMPLEMENTED |
| Allocation page integration | `CapitalAllocationPage.tsx` | IMPLEMENTED |
| Programmable chain definition | `programmable-chains.ts` | IMPLEMENTED |
| Chain orchestration | `useProgrammableChains.ts`, `ProgrammableChainsPanel.tsx` | IMPLEMENTED |

## Phase 5 — Portfolio ✅ IMPLEMENTED

| Task | File(s) | Status |
|------|---------|--------|
| Bridge holdings from proofs | `PortfolioPage.tsx` | IMPLEMENTED |
| SDK mapping | `bridgeEntriesFromProofs()` | IMPLEMENTED |

## Phase 6 — Provider wiring ⏳ BLOCKED

| Task | Status | Blocker |
|------|--------|---------|
| Wormhole Token Bridge package IDs on Sui testnet/mainnet | BLOCKED | Provider config not set |
| `buildWormholeBridgeTransaction` Move calls | BLOCKED | Depends on package IDs |
| Relayer / VAA polling for destination phase | NOT VERIFIED | No live bridge txs |
| Destination DeFi auto-deposit after bridge | NOT VERIFIED | Requires mainnet bridge + DeFi CHAIN_VERIFIED |

## Phase 7 — Verification sprint ⏳ BLOCKED

Do **not** start until upstream checklist is `CHAIN_VERIFIED`:

1. Navi mainnet deposit/withdraw
2. Scallop mainnet deposit/withdraw
3. Cetus mainnet deposit/withdraw
4. 40/40/20 allocation bundle
5. Browser wallet verification flow
6. Cross-protocol routing

Verification deliverables (future): wallet-signed testnet→mainnet transfer, destination digest in Proof Center, portfolio phase `destination_confirmed`. **No CHAIN_VERIFIED label on bridge** until sprint sign-off.

## Implementation status summary

| Component | Status |
|-----------|--------|
| SDK layer | IMPLEMENTED |
| Workflow layer | IMPLEMENTED |
| Proof layer | IMPLEMENTED |
| Portfolio integration | IMPLEMENTED |
| Risk controls | IMPLEMENTED |
| Transaction tracking | NOT VERIFIED |
| Wormhole provider PTB | BLOCKED |
| End-to-end cross-chain tx | BLOCKED |

**Artifact:** `proof/bridge-implementation-status.json` (machine-readable snapshot).
