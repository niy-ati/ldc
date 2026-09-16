/// Revenue Allocation Mandate — distribution objectives with split obligations.
module mandateos::revenue_allocation_mandate;

use sui::clock::Clock;
use std::option::{Self, Option};
use sui::coin::Coin;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{Self, ObligationRegistry};
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook, OracleCap};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::rules;
use mandateos::types::{Self};
use mandateos::vault::{Self, MandateVault};
use mandateos::receipts::FinancialReceipt;
use mandateos::simulation::SimulationApproval;
use mandateos::delegation::{ExecutorCap, DelegationCap, DailyExecutionTracker};
use mandateos::workflow::WorkflowSession;

public struct AllocationRecipient has store, copy, drop {
    recipient: address,
    share_bps: u64,
}

public fun new_allocation_recipient(recipient: address, share_bps: u64): AllocationRecipient {
    AllocationRecipient { recipient, share_bps }
}

public struct RevenueAllocationConfig has key {
    id: UID,
    mandate_id: ID,
    recipients: vector<AllocationRecipient>,
    total_allocated_bps: u64,
    min_distribution_amount: u64,
}

public fun create<T>(
    owner: address,
    executor: address,
    recipients: vector<AllocationRecipient>,
    min_distribution_amount: u64,
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
    RevenueAllocationConfig,
) {
    let total_bps = sum_shares(&recipients);
    assert!(total_bps <= 10000, types::eallocation_exceeds100());

    let objectives = objectives::distribution_objectives(
        min_distribution_amount * 100,
        total_bps,
        14,
    );
    let ownership = financial_mandate::ownership_for(owner);
    let spending = financial_mandate::permissive_spending(
        min_distribution_amount * 10,
        min_distribution_amount * 100,
    );
    let actions = vector[types::action_revenue_split(), types::action_allocate(), types::action_transfer()];
    let execution = financial_mandate::actions_only(actions);
    let reserve = financial_mandate::standard_reserve();
    let treasury = financial_mandate::no_treasury_obligation();
    let governance = financial_mandate::default_governance(executor, ctx);
    let expiration = financial_mandate::year_expiration(clock);

    let mut initial_obligations = vector[];
    let mut i = 0;
    while (i < recipients.length()) {
        let r = recipients[i];
        initial_obligations.push_back(objectives::financial_obligation(
            (i as u64) + 1,
            objectives::obligation_payment(),
            r.recipient,
            min_distribution_amount,
            clock.timestamp_ms() + 86_400_000,
            86_400_000,
            2,
        ));
        i = i + 1;
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
            types::mandate_revenue_allocation(),
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

    let config = RevenueAllocationConfig {
        id: object::new(ctx),
        mandate_id: object::id(&mandate),
        recipients,
        total_allocated_bps: total_bps,
        min_distribution_amount,
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
    config: RevenueAllocationConfig,
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

public fun distribute<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    config: &RevenueAllocationConfig,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    approval: &mut SimulationApproval,
    executor_cap: &Option<ExecutorCap>,
    recipient_idx: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    assert!(object::id(mandate) == config.mandate_id, types::evault_mismatch());
    assert!(recipient_idx < config.recipients.length(), types::einvalid_amount());

    let recipient = config.recipients[recipient_idx];
    let vault_balance = vault.balance_value();
    assert!(vault_balance >= config.min_distribution_amount, types::einsufficient_liquidity());

    let amount = (vault_balance * recipient.share_bps) / 10000;
    assert!(amount >= config.min_distribution_amount, types::einvalid_amount());

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
        types::action_revenue_split(),
        amount,
        recipient.recipient,
        recipient_idx + 1,
        executor_cap,
        approval,
        clock,
        ctx,
    )
}

public fun fund<T>(vault: &mut MandateVault<T>, coin: Coin<T>) {
    vault::deposit(vault, coin);
}

fun sum_shares(recipients: &vector<AllocationRecipient>): u64 {
    let mut total = 0u64;
    let mut i = 0;
    while (i < recipients.length()) {
        total = total + recipients[i].share_bps;
        i = i + 1;
    };
    total
}

public fun allocation_recipient(r: &AllocationRecipient): (address, u64) {
    (r.recipient, r.share_bps)
}
