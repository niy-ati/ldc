/// Treasury Mandate — organizational treasury chartered by objectives and obligations.
module mandateos::treasury_mandate;

use std::option::{Self, Option};
use sui::clock::Clock;
use sui::coin::Coin;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{Self, ObligationRegistry};
use mandateos::operational_risk::{Self, OperationalRiskProfile};
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook, OracleCap};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::rules::{Self};
use mandateos::types::{Self};
use mandateos::vault::{Self, MandateVault};
use mandateos::receipts::FinancialReceipt;
use mandateos::simulation::SimulationApproval;
use mandateos::delegation::{ExecutorCap, DelegationCap, DailyExecutionTracker};
use mandateos::workflow::{Self, WorkflowSession};

public struct TreasuryConfig has key {
    id: UID,
    mandate_id: ID,
    multisig_threshold: u64,
    approved_spend_categories: vector<u8>,
}

public fun create<T>(
    owner: address,
    executor: address,
    target_balance: u64,
    max_per_tx: u64,
    max_daily: u64,
    min_reserve_bps: u64,
    contribution_bps: u64,
    contribution_recipient: address,
    multisig_threshold: u64,
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
    TreasuryConfig,
) {
    let objectives = objectives::preservation_objectives(target_balance, 90, min_reserve_bps);
    let ownership = financial_mandate::ownership_for(owner);
    let spending = financial_mandate::permissive_spending(max_per_tx, max_daily);
    let actions = vector[types::action_treasury(), types::action_transfer(), types::action_allocate()];
    let execution = financial_mandate::actions_only(actions);
    let reserve = rules::reserve_requirements(min_reserve_bps, 0);
    let treasury = rules::treasury_obligations(contribution_bps, contribution_recipient, 2_592_000_000);
    let governance = financial_mandate::default_governance(executor, ctx);
    let expiration = financial_mandate::year_expiration(clock);

    let mut initial_obligations = vector[];
    if (contribution_bps > 0) {
        initial_obligations.push_back(objectives::financial_obligation(
            1,
            objectives::obligation_contribution(),
            contribution_recipient,
            max_per_tx,
            clock.timestamp_ms() + 2_592_000_000,
            2_592_000_000,
            1,
        ));
    };

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
            types::mandate_treasury(),
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

    let config = TreasuryConfig {
        id: object::new(ctx),
        mandate_id: object::id(&mandate),
        multisig_threshold,
        approved_spend_categories: vector[1, 2, 3],
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
    config: TreasuryConfig,
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

public fun treasury_disbursement<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    config: &TreasuryConfig,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    approval: &mut SimulationApproval,
    executor_cap: &Option<ExecutorCap>,
    amount: u64,
    recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    assert_mandate_type(mandate, config);
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
        types::action_treasury(),
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

fun assert_mandate_type(mandate: &FinancialMandate, config: &TreasuryConfig) {
    assert!(financial_mandate::mandate_type(mandate) == types::mandate_treasury(), types::einvalid_mandate_type());
    assert!(object::id(mandate) == config.mandate_id, types::evault_mismatch());
}

public fun mandate_id(config: &TreasuryConfig): ID { config.mandate_id }
