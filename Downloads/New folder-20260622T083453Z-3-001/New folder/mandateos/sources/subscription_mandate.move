/// Subscription Mandate — recurring payment obligations with auto-expiry objectives.
module mandateos::subscription_mandate;

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

public struct SubscriptionConfig has key {
    id: UID,
    mandate_id: ID,
    provider: address,
    amount_per_cycle: u64,
    billing_cycle_ms: u64,
    last_payment_ms: u64,
    max_cycles: u64,
    cycles_paid: u64,
    auto_renew: bool,
    obligation_id: u64,
}

public fun create<T>(
    owner: address,
    executor: address,
    provider: address,
    amount_per_cycle: u64,
    billing_cycle_ms: u64,
    max_cycles: u64,
    auto_renew: bool,
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
    SubscriptionConfig,
) {
    let total_commitment = amount_per_cycle * max_cycles;
    let objectives = objectives::preservation_objectives(total_commitment, 30, 500);
    let ownership = financial_mandate::ownership_for(owner);
    let spending = rules::spending_permissions(
        amount_per_cycle,
        amount_per_cycle * 30,
        vector[provider],
        false,
    );
    let actions = vector[types::action_subscription(), types::action_transfer()];
    let execution = rules::execution_constraints(billing_cycle_ms, 1, actions);
    let reserve = financial_mandate::standard_reserve();
    let treasury = financial_mandate::no_treasury_obligation();
    let governance = financial_mandate::default_governance(executor, ctx);
    let expiration = financial_mandate::year_expiration(clock);

    let initial_obligations = vector[
        objectives::financial_obligation(
            1,
            objectives::obligation_payment(),
            provider,
            amount_per_cycle,
            clock.timestamp_ms() + billing_cycle_ms,
            billing_cycle_ms,
            1,
        ),
    ];

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
            types::mandate_subscription(),
            objectives,
            ownership,
            spending,
            execution,
            reserve,
            treasury,
            governance,
            expiration,
            initial_obligations,
            clock,
            ctx,
        );

    let guardian = mandateos::guardian::create_policy(object::id(&mandate), 2500, ctx);

    let config = SubscriptionConfig {
        id: object::new(ctx),
        mandate_id: object::id(&mandate),
        provider,
        amount_per_cycle,
        billing_cycle_ms,
        last_payment_ms: 0,
        max_cycles,
        cycles_paid: 0,
        auto_renew,
        obligation_id: 1,
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
    config: SubscriptionConfig,
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

public fun pay_subscription<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    config: &mut SubscriptionConfig,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    approval: &mut SimulationApproval,
    executor_cap: &Option<ExecutorCap>,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    assert!(object::id(mandate) == config.mandate_id, types::evault_mismatch());
    let now = clock.timestamp_ms();
    if (config.last_payment_ms > 0) {
        assert!(now >= config.last_payment_ms + config.billing_cycle_ms, types::esubscription_not_due());
    };
    assert!(config.cycles_paid < config.max_cycles, types::emandate_expired());

    config.last_payment_ms = now;
    config.cycles_paid = config.cycles_paid + 1;

    let receipt = financial_mandate::run_authorized_settlement(
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
        types::action_subscription(),
        config.amount_per_cycle,
        config.provider,
        config.obligation_id,
        executor_cap,
        approval,
        clock,
        ctx,
    );

    if (!config.auto_renew && config.cycles_paid >= config.max_cycles) {
        financial_mandate::pause(mandate, constitution, ctx);
    };

    receipt
}

public fun fund<T>(vault: &mut MandateVault<T>, coin: Coin<T>) {
    vault::deposit(vault, coin);
}
