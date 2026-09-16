/// Payroll Mandate — recurring compensation obligations chartered on objectives.
module mandateos::payroll_mandate;

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

public struct PayrollEntry has store, copy, drop {
    employee: address,
    amount: u64,
}

public fun new_payroll_entry(employee: address, amount: u64): PayrollEntry {
    PayrollEntry { employee, amount }
}

public struct PayrollConfig has key {
    id: UID,
    mandate_id: ID,
    pay_cycle_ms: u64,
    last_payroll_ms: u64,
    employees: vector<PayrollEntry>,
}

public fun create<T>(
    owner: address,
    executor: address,
    max_per_tx: u64,
    pay_cycle_ms: u64,
    employees: vector<PayrollEntry>,
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
    PayrollConfig,
) {
    let mut initial_obligations = vector[];
    let mut i = 0;
    while (i < employees.length()) {
        let e = employees[i];
        initial_obligations.push_back(objectives::financial_obligation(
            (i as u64) + 1,
            objectives::obligation_payment(),
            e.employee,
            e.amount,
            clock.timestamp_ms() + pay_cycle_ms,
            pay_cycle_ms,
            1,
        ));
        i = i + 1;
    };

    let objectives = objectives::distribution_objectives(max_per_tx * 100, 8000, 30);
    let ownership = financial_mandate::ownership_for(owner);
    let spending = financial_mandate::permissive_spending(max_per_tx, max_per_tx * 100);
    let actions = vector[types::action_payroll(), types::action_transfer()];
    let execution = financial_mandate::actions_only(actions);
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
            types::mandate_payroll(),
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

    let config = PayrollConfig {
        id: object::new(ctx),
        mandate_id: object::id(&mandate),
        pay_cycle_ms,
        last_payroll_ms: 0,
        employees,
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
    config: PayrollConfig,
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

public fun run_payroll<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    config: &mut PayrollConfig,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    approval: &mut SimulationApproval,
    executor_cap: &Option<ExecutorCap>,
    employee_idx: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    assert!(object::id(mandate) == config.mandate_id, types::evault_mismatch());
    let now = clock.timestamp_ms();
    assert!(now >= config.last_payroll_ms + config.pay_cycle_ms, types::epayroll_cycle_violation());
    assert!(employee_idx < config.employees.length(), types::einvalid_amount());

    let entry = config.employees[employee_idx];
    let obligation_id = employee_idx + 1;
    config.last_payroll_ms = now;

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
        types::action_payroll(),
        entry.amount,
        entry.employee,
        obligation_id,
        executor_cap,
        approval,
        clock,
        ctx,
    )
}

public fun fund<T>(vault: &mut MandateVault<T>, coin: Coin<T>) {
    vault::deposit(vault, coin);
}

public fun employees(config: &PayrollConfig): &vector<PayrollEntry> { &config.employees }

public fun payroll_entry(entry: &PayrollEntry): (address, u64) {
    (entry.employee, entry.amount)
}
