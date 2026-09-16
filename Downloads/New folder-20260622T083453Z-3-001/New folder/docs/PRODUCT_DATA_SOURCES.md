# Product Data Sources & Provenance

Judging risk: **synthetic metrics without badges** — not wallet integration.

## Badge legend

| Badge | Meaning |
|-------|---------|
| **On-chain** | Read directly from Sui objects (vault, obligations, RiskProfile, guardian policy) |
| **Derived** | Computed from on-chain view + audit events (runway, risk budget, capital scores) |
| **Market feed** | CoinGecko / DefiLlama |
| **Simulation** | UI sliders, estimated protocol splits, advisory recommendations |
| **Offline mandate** | Demo mode (`VITE_DEMO_MODE=true`) |

## Live read model (`MandateOSReader`)

On-chain bundle (8 objects):

- Mandate, Vault, Constitution, Obligations, **OperationalRiskProfile**, Liquidity Engine, Guardian Policy, Market Forecast

Recent improvements:

- **Runway** — computed from liquid vault / 30-day obligation burn (not objective target)
- **Guardian actions** — from `GuardianTriggered` events
- **Agents** — from `delegation_issued` audit events
- **RiskProfile** — `portfolio_risk_score`, optional `volatility_score` / `liquidity_score` fields
- **Forecast object** — wired into liquidity forecast buffer when present

## Page-level provenance

| Page | On-chain | Derived | Simulation | Market |
|------|----------|---------|------------|--------|
| Treasury Account | Vault, obligations, balances | Runway | — | — |
| Portfolio | Wallet SUI, treasury liquid/reserved | PnL, Sharpe, returns | Protocol/LP/yield token rows | SUI USD price |
| Capital Analytics | Mandate inputs | 6-factor health scores | Rebalance advisories | Forecast inputs |
| Risk Budget | RiskProfile + guardian | `computeRiskBudget` | Alert slider | — |
| Yield Hub | Yield budget from vault | — | Allocation sliders | DefiLlama protocols |
| Market Terminal | Treasury context | — | Order book depth | CoinGecko |

## Remaining gaps (honest)

1. **Protocol positions** — illiquid vault split is estimated, not per-protocol on-chain reads
2. **Yield deployment verification** — allocation plan not yet checked against vault debits
3. **Executor caps** — agent list from events only; live cap object polling not implemented
4. **Forecast** — object fetched; MAGMA panels still use product-layer projection

Each gap is labeled **Simulation** or **Derived** in UI until replaced.
