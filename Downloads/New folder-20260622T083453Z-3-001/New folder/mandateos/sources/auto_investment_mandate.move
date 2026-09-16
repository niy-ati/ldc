/// Auto-Investment Mandate — growth objectives with allocation obligations.
module mandateos::auto_investment_mandate;

use sui::clock::Clock;
use std::option::{Self, Option};
use sui::coin::Coin;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{Self, ObligationRegistry};
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook, OracleCap};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::rules::{Self};
use mandateos::types::{Self};
use mandateos::vault::{Self, MandateVault};
use mandateos::receipts::FinancialReceipt;
use mandateos::simulation::SimulationApproval;
use mandateos::delegation::{ExecutorCap, DelegationCap, DailyExecutionTracker};
use mandateos::workflow::WorkflowSession;

public struct InvestmentTarget has store, copy, drop {
    protocol_id: u8,
    allocation_bps: u64,
    min_investment: u64,
}

public fun new_investment_target(protocol_id: u8, allocation_bps: u64, min_investment: u64): InvestmentTarget {
    InvestmentTarget { protocol_id, allocation_bps, min_investment }
}

public struct AutoInvestmentConfig has key {
    id: UID,
    mandate_id: ID,
    rebalance_interval_ms: u64,
    last_rebalance_ms: u64,
    targets: vector<InvestmentTarget>,
}

public fun create<T>(
    owner: address,
    executor: address,
    max_per_tx: u64,
    rebalance_interval_ms: u64,
    targets: vector<InvestmentTarget>,
    clock: &Clock,
    ctx: &mut TxContext,
): (
    FinancialMandate,
    MandateVault<T>,
    FinancialConstitution,
    ObligationRegistry,
    OperationalRiskProfile,
    LiquidityEngine,
    MarketForecast,
    DeepBookHook,
    OracleCap,
    mandateos::guardian::GuardianPolicy,
    DelegationCap,
    DailyExecutionTracker,
    AutoInvestmentConfig,
) {
    let objectives = objectives::growth_objectives(max_per_tx * 10, 500, 60);
    let ownership = financial_mandate::ownership_for(owner);
    let spending = financial_mandate::permissive_spending(max_per_tx, max_per_tx * 10);
    let actions = vector[types::action_invest(), types::action_allocate()];
    let execution = rules::execution_constraints(rebalance_interval_ms, 10, actions);
    let reserve = financial_mandate::standard_reserve();
    let treasury = financial_mandate::no_treasury_obligation();
    let governance = financial_mandate::default_governance(executor, ctx);
    let expiration = financial_mandate::year_expiration(clock);

    let (
        mandate,
        vault,
        constitution,
        obligations,
        risk,
        engine,
        forecast,
        hook,
        oracle_cap,
        delegation_cap,
        execution_tracker,
    ) = financial_mandate::bootstrap_os<T>(
            types::mandate_auto_investment(),
            objectives,
            ownership,
            spending,
            execution,
            reserve,
            treasury,
            governance,
            expiration,
            vector[],
            clock,
            ctx,
        );

    let guardian = mandateos::guardian::create_policy(object::id(&mandate), 2500, ctx);

    let config = AutoInvestmentConfig {
        id: object::new(ctx),
        mandate_id: object::id(&mandate),
        rebalance_interval_ms,
        last_rebalance_ms: 0,
        targets,
    };

    (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config)
}

public fun share_all<T>(
    mandate: FinancialMandate,
    vault: MandateVault<T>,
    constitution: FinancialConstitution,
    obligations: ObligationRegistry,
    risk: OperationalRiskProfile,
    engine: LiquidityEngine,
    forecast: MarketForecast,
    hook: DeepBookHook,
    oracle_cap: OracleCap,
    guardian: mandateos::guardian::GuardianPolicy,
    delegation_cap: DelegationCap,
    execution_tracker: DailyExecutionTracker,
    config: AutoInvestmentConfig,
) {
    financial_mandate::share_os(
        mandate,
        vault,
        constitution,
        obligations,
        risk,
        engine,
        forecast,
        hook,
        oracle_cap,
        delegation_cap,
        execution_tracker,
    );
    mandateos::guardian::share_policy(guardian);
    transfer::share_object(config);
}

public fun invest<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    config: &mut AutoInvestmentConfig,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    approval: &mut SimulationApproval,
    executor_cap: &Option<ExecutorCap>,
    target_idx: u64,
    recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    assert!(object::id(mandate) == config.mandate_id, types::evault_mismatch());
    assert!(target_idx < config.targets.length(), types::einvalid_amount());

    let target = config.targets[target_idx];
    assert!(target.min_investment > 0, types::einvestment_below_minimum());

    let vault_balance = vault.balance_value();
    let amount = (vault_balance * target.allocation_bps) / 10000;
    assert!(amount >= target.min_investment, types::einvestment_below_minimum());

    vault::set_illiquid_allocation(vault, target.allocation_bps);
    config.last_rebalance_ms = clock.timestamp_ms();

    financial_mandate::run_authorized_settlement(
        mandate,
        constitution,
        risk,
        engine,
        obligations,
        forecast,
        hook,
        vault,
        session,
        execution_tracker,
        types::action_invest(),
        amount,
        recipient,
        0,
        executor_cap,
        approval,
        clock,
        ctx,
    )
}

public fun fund<T>(vault: &mut MandateVault<T>, coin: Coin<T>) {
    vault::deposit(vault, coin);
}

public fun targets(config: &AutoInvestmentConfig): &vector<InvestmentTarget> { &config.targets }
