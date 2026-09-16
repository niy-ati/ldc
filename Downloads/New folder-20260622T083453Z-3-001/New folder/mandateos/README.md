# MandateOS

**A programmable financial operating system built on Sui.**

MandateOS is not a treasury app. It is a layered financial OS where every fund movement passes through constitutional validation, operational risk assessment, adaptive liquidity checks, and auditable receipt issuance — all enforced on-chain in Move.

## Architecture Review: Financial OS vs Treasury App

A treasury app stores coins and enforces spending limits. MandateOS treats finance as **governed state machines** with separated concerns:

| Layer | Object | Responsibility |
|---|---|---|
| **Mandate** | `FinancialMandate` | Financial **objectives** and **obligations** — what the entity must achieve and honor |
| **Constitution** | `FinancialConstitution` | Enforceable **limits and authorities** — how operations are constrained |
| **Operational Risk** | `OperationalRiskProfile` | Concentration, counterparty, stress-mode risk beyond static caps |
| **Adaptive Liquidity** | `LiquidityEngine` | Dynamic buffers from obligations, velocity, and market forecasts |
| **Market Forecast** | `MarketForecast` + `DeepBookHook` | DeepBook-integrated liquidity signals feeding the engine |
| **Workflow** | `WorkflowSession` | PTB-composable multi-step pipeline with witness chain |
| **Receipts** | `FinancialReceipt` + layer receipts | Immutable audit trail proving each layer cleared |

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     FINANCIAL MANDATE (Charter)                          │
│  Objectives: target balance, runway, growth, distribution, covenants    │
│  Obligations: payments, contributions, reserve covenants (registry)    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Constitution  │     │ Operational Risk │     │ Liquidity Engine │
│ (limits)      │     │ (concentration)  │     │ (adaptive)       │
└───────┬───────┘     └────────┬────────┘     └────────┬────────┘
        │                      │                       │
        └──────────────────────┼───────────────────────┘
                               ▼
                    ┌─────────────────────┐
                    │  PTB Workflow Layer  │
                    │  Intent → Constitution│
                    │  → Risk → Liquidity  │
                    │  → Authorized        │
                    └──────────┬──────────┘
                               ▼
                    ┌─────────────────────┐
                    │  MandateVault<T>     │
                    │  (funds)             │
                    └──────────┬──────────┘
                               ▼
                    ┌─────────────────────┐
                    │  Receipt Objects     │
                    │  FinancialReceipt    │
                    │  RiskReceipt         │
                    │  LiquidityReceipt    │
                    │  ObligationReceipt   │
                    └─────────────────────┘
```

## Why Sui Is Necessary

| Sui Capability | MandateOS Use |
|---|---|
| **Move Objects** | Each OS layer is a first-class object with explicit identity and linkage |
| **Shared Objects** | Multi-party mandates (DAO, payroll) coordinate through shared constitutional state |
| **PTBs** | Workflow steps compose atomically: validate → risk → liquidity → debit → receipt |
| **Witness Types** | `ExecutionAuthorization`, `RiskCleared`, `LiquidityCleared` — non-forgeable hot potatoes |
| **Object Graph** | Mandate links constitution, obligations, risk, liquidity, forecast by ID |

Account-based chains bolt policy engines onto wallets. On Sui, the **mandate graph is the policy**.

## Core Primitive: Financial Mandate Object

The mandate represents **financial purpose**, not transaction limits:

```move
public struct FinancialMandate has key {
    objectives: FinancialObjectives,      // WHAT to achieve
    obligation_registry_id: ID,         // WHAT must be honored
    constitutional_id: ID,              // HOW it's constrained
    risk_profile_id: ID,                // Operational risk state
    liquidity_engine_id: ID,            // Adaptive liquidity state
    forecast_id: ID,                    // DeepBook forecast link
    // ...
}
```

**Objectives** (charter): target balance, runway days, growth/distribution targets, reserve covenants.

**Obligations** (duties): scheduled payments, contributions, liquidity covenants — tracked in `ObligationRegistry` with fulfillment receipts.

**Constitution** (limits): spending permissions, execution constraints, governance — in separate `FinancialConstitution` object, amendable through governed process.

## PTB Financial Workflow Layer

Every governed action follows the same pipeline. Funds may **only** move via `settle`:

```move
let mut session = workflow::open_session(mandate_id, &clock, ctx);

let intent = workflow::begin_intent(&mut session, ACTION_TREASURY, amount, recipient, 0, &clock);
let constitutional = workflow::validate_constitution(&mut session, intent, &constitution, STATUS_ACTIVE, &vault, executor, &clock);
let risk_v = workflow::assess_risk(&mut session, constitutional, &mut risk, &obligations, &objectives, &vault, &clock);
let liq_v = workflow::check_adaptive_liquidity(&mut session, risk_v, &engine, &objectives, &obligations, &forecast, &hook, &vault, &clock);
let auth = workflow::authorize_execution(&mut session, liq_v, &clock);

let (receipt, completion) = financial_mandate::settle(
    &mut mandate, &mut constitution, &mut engine, &mut obligations,
    &session, auth, &mut vault, &clock, ctx,
);
```

`ExecutionAuthorization` is a **hot-potato capability** (no `copy`, `drop`, or `store`) — only `workflow::authorize_execution` can create it. `vault::debit_authorized` is package-private and requires it.

## DeepBook Forecast Hooks

`MarketForecast` objects receive oracle-submitted snapshots (mid price, spread, depth, volatility, slippage). `DeepBookHook` enforces pre-execution market conditions and feeds the Adaptive Liquidity Engine with volatility/slippage multipliers.

```move
deepbook_forecast::submit_forecast(&mut forecast, &hook, &oracle_cap, mid, spread, depth, vol, slip, now);
financial_mandate::rebalance_liquidity(&mandate, &constitution, &mut engine, &obligations, &forecast, &hook, &vault, &clock, ctx);
```

## Mandate Types

All types bootstrap the full OS object graph via `financial_mandate::bootstrap_os`:

| Module | Charter Focus |
|---|---|
| `treasury_mandate` | Preservation objectives + contribution obligations |
| `payroll_mandate` | Distribution objectives + employee payment obligations |
| `auto_investment_mandate` | Growth objectives + allocation execution |
| `subscription_mandate` | Preservation objectives + recurring payment obligations |
| `revenue_allocation_mandate` | Distribution objectives + split obligations |
| `dao_treasury_mandate` | Preservation objectives + proposal-gated execution |

## Project Structure

```
mandateos/sources/
├── mandateos.move              # Package init
├── types.move                  # Constants, witnesses, errors
├── rules.move                  # Constitutional rule structs
├── objectives.move             # Objectives + ObligationRegistry
├── constitutional.move         # FinancialConstitution objects
├── operational_risk.move       # Operational Risk Layer
├── adaptive_liquidity.move     # Adaptive Liquidity Engine
├── deepbook_forecast.move      # DeepBook Forecast Hooks
├── workflow.move               # PTB Financial Workflow Layer
├── receipts.move               # Receipt Objects
├── financial_mandate.move      # Mandate charter + orchestration
├── validation.move             # Constitutional validation gate
├── vault.move                  # Mandate-controlled funds
└── *_mandate.move              # Specialized mandate charters
```

## Build & Deploy

```bash
cd mandateos
sui move build
sui move test
sui client publish --gas-budget 200000000 -e testnet
```

## On-Chain Enforcement

All critical controls are enforced in Move — no off-chain policy engine required:

- Constitutional spending limits and governance roles
- Operational risk concentration and counterparty scores
- Adaptive liquidity buffers from obligations + forecasts
- DeepBook pre-execution market condition hooks
- Obligation fulfillment tracking with receipts
- Vault debits require full workflow authorization witness

## License

MIT
