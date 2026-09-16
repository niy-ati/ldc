/// The Financial Mandate Object — chartered financial purpose and obligation registry.
module mandateos::financial_mandate;

use sui::clock::Clock;
use sui::event;
use sui::vec_map;
use mandateos::authority;
use mandateos::delegation::{Self, ExecutorCap, DailyExecutionTracker, DelegationCap};
use mandateos::simulation::{Self, SimulationApproval};
use mandateos::constitutional::{Self, FinancialConstitution};
use mandateos::objectives::{Self, FinancialObjectives, FinancialObligation, ObligationRegistry};
use mandateos::operational_risk::{Self, OperationalRiskProfile};
use mandateos::adaptive_liquidity::{Self, LiquidityEngine};
use mandateos::deepbook_forecast::{Self, MarketForecast, DeepBookHook, OracleCap};
use mandateos::workflow::{Self, WorkflowSession, ExecutionAuthorization};
use mandateos::receipts::{Self, FinancialReceipt, WorkflowCompletionReceipt};
use mandateos::rules::{
    Self,
    OwnershipRules,
    SpendingPermissions,
    ExecutionConstraints,
    ReserveRequirements,
    TreasuryObligations,
    GovernanceAuthorities,
    ExpirationConditions,
};
use mandateos::types::{Self};
use mandateos::validation;
use mandateos::vault::{Self, MandateVault};

public struct MandateCreated has copy, drop {
    mandate_id: ID,
    mandate_type: u8,
    vault_id: ID,
    constitutional_id: ID,
    owner: address,
}

public struct MandateExecuted has copy, drop {
    mandate_id: ID,
    workflow_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    executor: address,
}

public struct MandateStatusChanged has copy, drop {
    mandate_id: ID,
    old_status: u8,
    new_status: u8,
}

public struct FinancialMandate has key {
    id: UID,
    mandate_type: u8,
    status: u8,
    vault_id: ID,
    constitutional_id: ID,
    obligation_registry_id: ID,
    risk_profile_id: ID,
    liquidity_engine_id: ID,
    forecast_id: ID,
    hook_id: ID,
    objectives: FinancialObjectives,
    total_executions: u64,
    total_volume: u64,
    created_at_ms: u64,
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

public(package) fun bootstrap_os<T>(
    mandate_type: u8,
    objectives: FinancialObjectives,
    ownership: OwnershipRules,
    spending: SpendingPermissions,
    execution: ExecutionConstraints,
    reserve: ReserveRequirements,
    treasury: TreasuryObligations,
    governance: GovernanceAuthorities,
    expiration: ExpirationConditions,
    initial_obligations: vector<FinancialObligation>,
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
    DelegationCap,
    DailyExecutionTracker,
) {
    let mandate_uid = object::new(ctx);
    let mandate_id = object::uid_to_inner(&mandate_uid);
    let now_ms = clock.timestamp_ms();

    let owner = rules::primary_owner(&ownership);
    let vault = vault::create_vault<T>(mandate_id, ctx);
    let constitution = constitutional::ratify(
        mandate_id,
        ownership,
        spending,
        execution,
        reserve,
        treasury,
        governance,
        expiration,
        now_ms,
        ctx,
    );
    let obligations = objectives::create_registry(mandate_id, initial_obligations, ctx);
    let risk = operational_risk::standard_profile(mandate_id, ctx);
    let engine = adaptive_liquidity::standard_engine(mandate_id, ctx);
    let (forecast, oracle_cap) = deepbook_forecast::neutral_forecast(mandate_id, now_ms, ctx);
    let hook = deepbook_forecast::neutral_hook(mandate_id, object::id(&forecast), ctx);
    let delegation_cap = delegation::create_delegation_cap(mandate_id, ctx);
    let execution_tracker = delegation::create_daily_tracker(mandate_id, ctx);

    let mandate = FinancialMandate {
        id: mandate_uid,
        mandate_type,
        status: types::status_active(),
        vault_id: object::id(&vault),
        constitutional_id: object::id(&constitution),
        obligation_registry_id: object::id(&obligations),
        risk_profile_id: object::id(&risk),
        liquidity_engine_id: object::id(&engine),
        forecast_id: object::id(&forecast),
        hook_id: object::id(&hook),
        objectives,
        total_executions: 0,
        total_volume: 0,
        created_at_ms: now_ms,
    };

    event::emit(MandateCreated {
        mandate_id,
        mandate_type,
        vault_id: object::id(&vault),
        constitutional_id: object::id(&constitution),
        owner,
    });

    (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, delegation_cap, execution_tracker)
}

public(package) fun share_os<T>(
    mandate: FinancialMandate,
    vault: MandateVault<T>,
    constitution: FinancialConstitution,
    obligations: ObligationRegistry,
    risk: OperationalRiskProfile,
    engine: LiquidityEngine,
    forecast: MarketForecast,
    hook: DeepBookHook,
    oracle_cap: OracleCap,
    delegation_cap: DelegationCap,
    execution_tracker: DailyExecutionTracker,
) {
    let owner = constitution.ownership().primary_owner();
    transfer::share_object(mandate);
    vault::share_vault(vault);
    constitutional::share_constitution(constitution);
    objectives::share_registry(obligations);
    operational_risk::share_profile(risk);
    adaptive_liquidity::share_engine(engine);
    deepbook_forecast::share_forecast(forecast);
    deepbook_forecast::share_hook(hook);
    delegation::share_tracker(execution_tracker);
    deepbook_forecast::transfer_oracle_cap(oracle_cap, owner);
    delegation::transfer_delegation_cap(delegation_cap, owner);
}

// ── Accessors ─────────────────────────────────────────────────────────────────

public fun mandate_type(m: &FinancialMandate): u8 { m.mandate_type }
public fun status(m: &FinancialMandate): u8 { m.status }
public fun vault_id(m: &FinancialMandate): ID { m.vault_id }
public fun constitutional_id(m: &FinancialMandate): ID { m.constitutional_id }
public fun obligation_registry_id(m: &FinancialMandate): ID { m.obligation_registry_id }
public fun risk_profile_id(m: &FinancialMandate): ID { m.risk_profile_id }
public fun liquidity_engine_id(m: &FinancialMandate): ID { m.liquidity_engine_id }
public fun forecast_id(m: &FinancialMandate): ID { m.forecast_id }
public fun hook_id(m: &FinancialMandate): ID { m.hook_id }
public fun objectives(m: &FinancialMandate): &FinancialObjectives { &m.objectives }
public fun total_executions(m: &FinancialMandate): u64 { m.total_executions }
public fun total_volume(m: &FinancialMandate): u64 { m.total_volume }

// ── Canonical execution path ──────────────────────────────────────────────────
//
// Funds may ONLY move via:
//   workflow (authorize) → settle (debit_authorized)
//
// PTB integrators compose workflow steps, then call settle with ExecutionAuthorization.
// Specialized mandate modules use run_authorized_settlement (same path).

/// Sole settlement entry — consumes non-forgeable ExecutionAuthorization and debits vault.
public fun settle<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    session: &WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    executor_cap: &Option<ExecutorCap>,
    auth: ExecutionAuthorization,
    vault: &mut MandateVault<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): (FinancialReceipt, WorkflowCompletionReceipt) {
    assert_linkage_for_settlement(
        mandate,
        constitution,
        obligations,
        engine,
        vault,
        session,
        &auth,
    );

    let action = workflow::auth_action(&auth);
    let amount = workflow::auth_amount(&auth);
    let recipient = workflow::auth_recipient(&auth);
    let obligation_id = workflow::auth_obligation_id(&auth);
    let now_ms = clock.timestamp_ms();
    let day = now_ms / 86_400_000;

    if (option::is_some(executor_cap)) {
        authority::assert_agent_executor(
            option::borrow(executor_cap),
            execution_tracker,
            object::id(mandate),
            action,
            amount,
            day,
            now_ms,
            ctx.sender(),
        );
    } else {
        authority::assert_executor(constitution, ctx.sender());
    };

    if (types::is_guardian_action(action)) {
        assert!(action != types::action_guardian_reallocate(), types::eremediation_mismatch());
        apply_guardian_status_transition(mandate, action);
    } else {
        let coin = vault::debit_authorized(
            vault,
            workflow::auth_mandate_id(&auth),
            amount,
            recipient,
            ctx,
        );
        transfer::public_transfer(coin, recipient);

        validation::record_constitutional_execution(constitution, amount, now_ms);
        adaptive_liquidity::record_outflow(engine, amount);

        let mut obligation_remaining = 0u64;
        if (obligation_id > 0) {
            obligation_remaining = objectives::fulfill_obligation(
                obligations,
                obligation_id,
                amount,
            );
        };

        mandate.total_executions = mandate.total_executions + 1;
        mandate.total_volume = mandate.total_volume + amount;

        if (obligation_id > 0) {
            let obligation_receipt = receipts::issue_obligation_receipt(&auth, obligation_remaining, ctx);
            transfer::public_transfer(obligation_receipt, ctx.sender());
        };
    };

    emit_mandate_executed(mandate, session, action, amount, recipient, ctx.sender());

    let (risk_receipt, liquidity_receipt) = receipts::issue_layer_receipts(&auth, ctx);
    transfer::public_transfer(risk_receipt, ctx.sender());
    transfer::public_transfer(liquidity_receipt, ctx.sender());

    let financial_receipt = receipts::issue_financial_receipt(
        session,
        &auth,
        vault.balance_value(),
        ctx,
    );
    let completion = receipts::issue_workflow_completion(session, now_ms, ctx);

    workflow::destroy_authorization(auth);

    (financial_receipt, completion)
}

/// Package helper: full workflow authorization + settlement (canonical path for mandate modules).
public(package) fun run_authorized_settlement<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk_profile: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    executor_cap: &Option<ExecutorCap>,
    approval: &mut SimulationApproval,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    assert_linkage(
        mandate,
        constitution,
        obligations,
        risk_profile,
        engine,
        forecast,
        hook,
        vault,
    );

    let intent = workflow::begin_intent(session, action, amount, recipient, obligation_id, clock);
    let delegated = option::is_some(executor_cap);
    let constitutional = workflow::validate_constitution(
        session,
        intent,
        constitution,
        mandate.status,
        vault,
        ctx.sender(),
        clock,
        delegated,
    );
    let risk_validated = workflow::assess_risk(
        session,
        constitutional,
        risk_profile,
        obligations,
        mandate.objectives(),
        vault,
        clock,
    );
    let liquidity_validated = workflow::check_adaptive_liquidity(
        session,
        risk_validated,
        engine,
        mandate.objectives(),
        obligations,
        forecast,
        hook,
        vault,
        clock,
    );
    simulation::assert_approval_matches(
        approval,
        object::id(mandate),
        action,
        amount,
        recipient,
        obligation_id,
        clock.timestamp_ms(),
    );
    let auth = workflow::authorize_execution(session, liquidity_validated, clock);

    let (receipt, completion) = settle(
        mandate,
        constitution,
        engine,
        obligations,
        forecast,
        hook,
        session,
        execution_tracker,
        executor_cap,
        auth,
        vault,
        clock,
        ctx,
    );
    transfer::public_transfer(completion, ctx.sender());
    receipt
}

/// PTB-safe governor simulation + approval (objectives read from mandate in-package).
public fun simulate_and_approve<T>(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &LiquidityEngine,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    executor: address,
    clock: &Clock,
    ctx: &mut TxContext,
): SimulationApproval {
    let mut sim = simulation::open_simulation(
        object::id(mandate),
        action,
        amount,
        recipient,
        obligation_id,
        clock,
        ctx,
    );
    let mut outcome = simulation::run_projection(
        &mut sim,
        object::id(mandate),
        mandate.status,
        constitution,
        risk,
        engine,
        obligations,
        mandate.objectives(),
        forecast,
        hook,
        vault,
        executor,
        clock,
        ctx,
    );
    let approval = simulation::approve_simulation(&mut outcome, constitution, clock, ctx);
    simulation::share_outcome(outcome);
    simulation::share_session(sim);
    approval
}

public(package) fun apply_guardian_status_transition(mandate: &mut FinancialMandate, action: u8) {
    types::assert_guardian_source_status(action, mandate.status);
    let old = mandate.status;
    let new_status = types::guardian_target_status(action, mandate.status);
    mandate.status = new_status;
    emit_status_change(mandate, old, new_status);
}

// ── Governance ────────────────────────────────────────────────────────────────

public fun pause(
    mandate: &mut FinancialMandate,
    constitution: &FinancialConstitution,
    ctx: &TxContext,
) {
    assert!(object::id(mandate) == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());
    let old = mandate.status;
    mandate.status = types::status_paused();
    emit_status_change(mandate, old, mandate.status);
}

public fun resume(
    mandate: &mut FinancialMandate,
    constitution: &FinancialConstitution,
    ctx: &TxContext,
) {
    assert!(object::id(mandate) == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());
    let old = mandate.status;
    mandate.status = types::status_active();
    emit_status_change(mandate, old, mandate.status);
}

public fun revoke(
    mandate: &mut FinancialMandate,
    constitution: &FinancialConstitution,
    ctx: &TxContext,
) {
    assert!(object::id(mandate) == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_owner(constitution, ctx.sender());
    let old = mandate.status;
    mandate.status = types::status_revoked();
    emit_status_change(mandate, old, mandate.status);
}

public fun register_obligation(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    obligations: &mut ObligationRegistry,
    obligation_type: u8,
    counterparty: address,
    principal: u64,
    due_at_ms: u64,
    recurrence_ms: u64,
    priority: u8,
    ctx: &TxContext,
): u64 {
    assert!(object::id(mandate) == obligations.registry_mandate_id(), types::evault_mismatch());
    objectives::register_obligation(
        obligations,
        constitution,
        obligation_type,
        counterparty,
        principal,
        due_at_ms,
        recurrence_ms,
        priority,
        ctx,
    )
}

public fun rebalance_liquidity<T>(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    engine: &mut LiquidityEngine,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert!(object::id(mandate) == engine.engine_mandate_id(), types::evault_mismatch());
    adaptive_liquidity::rebalance(
        engine,
        constitution,
        mandate.objectives(),
        obligations,
        forecast,
        hook,
        vault,
        clock.timestamp_ms(),
        ctx,
    );
}

public(package) fun assert_linkage_for_settlement<T>(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    obligations: &ObligationRegistry,
    engine: &LiquidityEngine,
    vault: &MandateVault<T>,
    session: &WorkflowSession,
    auth: &ExecutionAuthorization,
) {
    assert_linkage_mandate_objects(mandate, constitution, obligations, engine, vault);
    assert!(workflow::session_mandate_id(session) == object::id(mandate), types::eworkflow_mismatch());
    assert!(workflow::auth_mandate_id(auth) == object::id(mandate), types::eunauthorized_settlement());
    assert!(workflow::auth_workflow_id(auth) == workflow::session_id(session), types::eunauthorized_settlement());
    assert!(workflow::steps_completed(session) == workflow::step_authorized(), types::eunauthorized_settlement());
}

public(package) fun assert_linkage<T>(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    obligations: &ObligationRegistry,
    risk: &OperationalRiskProfile,
    engine: &LiquidityEngine,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
) {
    assert_linkage_mandate_objects(mandate, constitution, obligations, engine, vault);
    let mid = object::id(mandate);
    assert!(mandate.risk_profile_id == object::id(risk), types::evault_mismatch());
    assert!(mandate.forecast_id == object::id(forecast), types::evault_mismatch());
    assert!(mandate.hook_id == object::id(hook), types::evault_mismatch());
    assert!(risk.profile_mandate_id() == mid, types::evault_mismatch());
    assert!(forecast.forecast_mandate_id() == mid, types::evault_mismatch());
    assert!(hook.hook_mandate_id() == mid, types::evault_mismatch());
}

fun assert_linkage_mandate_objects<T>(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    obligations: &ObligationRegistry,
    engine: &LiquidityEngine,
    vault: &MandateVault<T>,
) {
    let mid = object::id(mandate);
    assert!(mandate.constitutional_id == object::id(constitution), types::evault_mismatch());
    assert!(mandate.obligation_registry_id == object::id(obligations), types::evault_mismatch());
    assert!(mandate.liquidity_engine_id == object::id(engine), types::evault_mismatch());
    assert!(mandate.vault_id == object::id(vault), types::evault_mismatch());
    assert!(constitution.mandate_id() == mid, types::evault_mismatch());
    assert!(obligations.registry_mandate_id() == mid, types::evault_mismatch());
    assert!(engine.engine_mandate_id() == mid, types::evault_mismatch());
}

public(package) fun emit_mandate_executed(
    mandate: &FinancialMandate,
    session: &WorkflowSession,
    action: u8,
    amount: u64,
    recipient: address,
    executor: address,
) {
    event::emit(MandateExecuted {
        mandate_id: object::id(mandate),
        workflow_id: workflow::session_id(session),
        action,
        amount,
        recipient,
        executor,
    });
}

fun emit_status_change(mandate: &FinancialMandate, old_status: u8, new_status: u8) {
    event::emit(MandateStatusChanged {
        mandate_id: object::id(mandate),
        old_status,
        new_status,
    });
}

// ── Bootstrap templates ───────────────────────────────────────────────────────

public fun default_governance(executor: address, ctx: &TxContext): GovernanceAuthorities {
    let mut authorities = vec_map::empty<address, u8>();
    let governor = ctx.sender();
    authorities.insert(governor, types::role_governor());
    if (executor != governor) {
        authorities.insert(executor, types::role_executor());
    };
    rules::governance_authorities(authorities, 1)
}

public fun permissive_spending(max_per_tx: u64, max_daily: u64): SpendingPermissions {
    rules::spending_permissions(max_per_tx, max_daily, vector[], true)
}

public fun standard_reserve(): ReserveRequirements {
    rules::reserve_requirements(1000, 0)
}

public fun no_expiration(): ExpirationConditions {
    rules::expiration_conditions(0xFFFFFFFFFFFFFFFF, false, 0)
}

public fun year_expiration(clock: &Clock): ExpirationConditions {
    let now = clock.timestamp_ms();
    rules::expiration_conditions(now + 31_536_000_000, true, 31_536_000_000)
}

public fun no_treasury_obligation(): TreasuryObligations {
    rules::treasury_obligations(0, @0x0, 0)
}

public fun ownership_for(owner: address): OwnershipRules {
    rules::ownership_rules(owner, vector[], false)
}

public fun actions_only(allowed: vector<u8>): ExecutionConstraints {
    rules::execution_constraints(0, 1000, allowed)
}
