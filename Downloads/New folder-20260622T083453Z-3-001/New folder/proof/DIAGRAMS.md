# MandateOS — Deployed System Diagrams

## 1. Architecture (testnet)

```mermaid
flowchart TB
  subgraph Clients
    CC[Command Center React UI]
    SDK[@mandateos/sdk PTB Builder]
    CLI[testnet-proof.ts]
  end

  subgraph OnChainTestnet
    PKG["MandateOS Package\n0x96e7…3713\n26 modules"]
    SHIM["PTB Shim Package\n0x6214…a00b\nclient::simulate_and_approve"]
    GOV[Governor keystore\nkind-chrysolite]
    EXE[Executor keypair\nrole holder]
    AGT[Agent keypair\nExecutorCap]
  end

  subgraph SharedObjects
    M[FinancialMandate]
    V[MandateVault]
    C[FinancialConstitution]
    GP[GuardianPolicy]
    LE[LiquidityEngine]
  end

  CC -->|MandateOSReader RPC| M
  SDK --> PKG
  SDK --> SHIM
  CLI --> SDK
  GOV -->|simulate / create / fund| PKG
  GOV -->|simulate_and_approve| SHIM
  SHIM --> PKG
  EXE -->|treasury_disbursement| PKG
  AGT -->|delegated execute| PKG
  M --- V
  M --- C
  M --- GP
  M --- LE
```

## 2. Object graph (live treasury proof)

```mermaid
erDiagram
  FinancialMandate ||--|| MandateVault : vault_id
  FinancialMandate ||--|| FinancialConstitution : constitutional_id
  FinancialMandate ||--|| ObligationRegistry : obligation_registry_id
  FinancialMandate ||--|| OperationalRiskProfile : risk_profile_id
  FinancialMandate ||--|| LiquidityEngine : liquidity_engine_id
  FinancialMandate ||--|| MarketForecast : forecast_id
  FinancialMandate ||--|| DeepBookHook : hook_id
  FinancialMandate ||--|| GuardianPolicy : policy
  TreasuryConfig ||--|| FinancialMandate : mandate_id
  DelegationCap ||--|| FinancialMandate : owner asset
  SimulationApproval }o--|| FinancialMandate : mandate_id
  ExecutorCap }o--|| DelegationCap : issued from
  FinancialReceipt }o--|| FinancialMandate : settlement
```

**Live IDs** (from `proof/testnet-results.json`):

| Node | Object ID |
|------|-----------|
| FinancialMandate | `0x0537293ee980082cc55c2a623ce243a78b34f897b7b422e6aa83545ad556e5ed` |
| MandateVault | `0x862c4b7cfd5988e55d5f72b7dfc8ab797895831f3ec97a48268ff004a0b8594f` |
| FinancialConstitution | `0x6006d3dc8ffcecb2fa8017fdb2ede117a6f8cdcd44c8f1efa5c40a5445e53841` |
| SimulationApproval | `0xf20bc84dbff1a5b39c4b2b076c0da98572541571bca2c2db78739c44f173e318` |

## 3. PTB execution — treasury disbursement

```mermaid
sequenceDiagram
  participant G as Governor
  participant SH as PTB Shim
  participant MO as MandateOS
  participant E as Executor
  participant R as Recipient

  G->>MO: treasury_mandate::create + share_all
  G->>MO: treasury_mandate::fund(vault, coin)
  G->>SH: client::simulate_and_approve(...)
  Note over SH,MO: open_simulation → run_projection(objectives from mandate) → approve_simulation → share
  SH-->>G: SimulationApproval
  G->>E: simulation::transfer_approval
  E->>MO: workflow::open_session
  E->>MO: treasury_mandate::treasury_disbursement(approval, ...)
  MO->>R: SUI coin transfer
  MO-->>E: FinancialReceipt
```

## 4. PTB execution — agent delegation

```mermaid
sequenceDiagram
  participant O as Owner/Governor
  participant MO as MandateOS
  participant A as Agent

  O->>MO: delegation::issue_executor_cap(limits, mask)
  O->>MO: simulate_and_approve (via shim)
  A->>MO: treasury_disbursement + ExecutorCap
  Note over A,MO: Success when amount ≤ max_per_tx
  A-xMO: Abort when amount > max_per_tx
```

## 5. Guardian AUTO_RESTRICT

```mermaid
flowchart LR
  E[evaluate guardian] --> A[GuardianAction shared]
  A --> S[simulate guardian restrict]
  S --> X[execute_action]
  X --> M[mandate.status → RESTRICTED]
```

Explorer: see `GUARDIAN_DEMO.md` after full proof run.
