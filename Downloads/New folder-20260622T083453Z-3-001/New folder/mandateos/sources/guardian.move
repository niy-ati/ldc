/// Guardian System — autonomous monitoring and corrective actions through workflow.
module mandateos::guardian;

use std::option::{Self, Option};
use sui::clock::Clock;
use sui::event;
use mandateos::authority;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{Self, ObligationRegistry, FinancialObjectives};
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::{Self, LiquidityEngine};
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::simulation::{Self, SimulationApproval};
use mandateos::workflow::{Self, WorkflowSession, ExecutionAuthorization};
use mandateos::vault::{Self, MandateVault};
use mandateos::receipts::{FinancialReceipt, WorkflowCompletionReceipt};
use mandateos::types::{Self};

public struct GuardianPolicy has key {
    id: UID,
    mandate_id: ID,
    max_concentration_bps: u64,
    monitor_obligations: bool,
    monitor_liquidity: bool,
    monitor_concentration: bool,
    monitor_forecast: bool,
    monitor_constitution: bool,
    auto_pause_enabled: bool,
    auto_restrict_enabled: bool,
    auto_reallocate_enabled: bool,
    auto_escalate_enabled: bool,
    active: bool,
}

/// Constitutional remediation plan — created on detection, executed via settlement.
public struct GuardianRemediationPlan has key, store {
    id: UID,
    mandate_id: ID,
    guardian_action_id: ID,
    reason: u8,
    source_allocation: u64,
    target_allocation: u64,
    liquidity_deficit: u64,
    created_at: u64,
    execution_status: u8,
}

public struct GuardianAction has key, store {
    id: UID,
    mandate_id: ID,
    policy_id: ID,
    action_kind: u8,
    trigger_kind: u8,
    severity_bps: u64,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    workflow_action: u8,
    remediation_plan_id: Option<ID>,
    created_at_ms: u64,
    executed: bool,
}

public struct GuardianActionReceipt has key, store {
    id: UID,
    action_id: ID,
    mandate_id: ID,
    action_kind: u8,
    trigger_kind: u8,
    workflow_id: ID,
    remediation_plan_id: Option<ID>,
    executed_at: u64,
}

public struct EscalationIntent has key, store {
    id: UID,
    mandate_id: ID,
    guardian_action_id: ID,
    trigger_kind: u8,
    severity_bps: u64,
    escalated_at: u64,
    resolved: bool,
}

public struct GuardianTriggered has copy, drop {
    policy_id: ID,
    mandate_id: ID,
    action_kind: u8,
    trigger_kind: u8,
}

public(package) fun create_policy(
    mandate_id: ID,
    max_concentration_bps: u64,
    ctx: &mut TxContext,
): GuardianPolicy {
    GuardianPolicy {
        id: object::new(ctx),
        mandate_id,
        max_concentration_bps,
        monitor_obligations: true,
        monitor_liquidity: true,
        monitor_concentration: true,
        monitor_forecast: true,
        monitor_constitution: true,
        auto_pause_enabled: true,
        auto_restrict_enabled: true,
        auto_reallocate_enabled: true,
        auto_escalate_enabled: true,
        active: true,
    }
}

public fun share_policy(policy: GuardianPolicy) {
    transfer::share_object(policy);
}

public fun share_action(action: GuardianAction) {
    transfer::share_object(action);
}

public fun share_remediation_plan(plan: GuardianRemediationPlan) {
    transfer::share_object(plan);
}

public fun transfer_action_receipt(receipt: GuardianActionReceipt, holder: address) {
    transfer::public_transfer(receipt, holder);
}

/// Evaluate mandate health — returns corrective action and optional remediation plan.
public fun evaluate<T>(
    policy: &GuardianPolicy,
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    obligations: &ObligationRegistry,
    risk: &OperationalRiskProfile,
    engine: &LiquidityEngine,
    forecast: &MarketForecast,
    vault: &MandateVault<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): (Option<GuardianAction>, Option<GuardianRemediationPlan>) {
    assert!(policy.active, types::eguardian_action_invalid());
    assert!(policy.mandate_id == object::id(mandate), types::evault_mismatch());
    let _ = constitution;
    let _ = risk;

    let now_ms = clock.timestamp_ms();
    let balance = vault.balance_value();
    let liquid = vault.liquid_balance_after_debit(0);
    let status = mandate.status();

    if (policy.monitor_obligations && objectives::has_overdue(obligations, now_ms)) {
        if (types::allows_workflow_status(status, types::action_guardian_pause())) {
            return (option::some(create_action(
                policy, types::guardian_auto_pause(), types::trigger_obligation_violation(),
                10_000, 0, @0x0, 0, types::action_guardian_pause(), option::none(), now_ms, ctx,
            )), option::none())
        };
    };

    if (policy.monitor_liquidity && liquid < adaptive_liquidity::total_required_buffer(engine)) {
        let required = adaptive_liquidity::total_required_buffer(engine);
        let deficit = if (required > liquid) { required - liquid } else { 0 };
        let source = vault::illiquid_allocation_bps(vault);
        let target = if (source > 500) { source - 500 } else { 0 };
        let mut action = create_action(
            policy, types::guardian_auto_reallocate(), types::trigger_liquidity_failure(),
            8_000, 0, @0x0, 0, types::action_guardian_reallocate(), option::none(), now_ms, ctx,
        );
        let plan = create_remediation_plan(
            policy.mandate_id,
            object::id(&action),
            types::trigger_liquidity_failure(),
            source,
            target,
            deficit,
            now_ms,
            ctx,
        );
        action.remediation_plan_id = option::some(object::id(&plan));
        return (option::some(action), option::some(plan))
    };

    if (policy.monitor_concentration && balance > 0) {
        let concentration = (liquid * 10_000) / balance;
        if (concentration > policy.max_concentration_bps) {
            if (types::allows_workflow_status(status, types::action_guardian_restrict())) {
                return (option::some(create_action(
                    policy, types::guardian_auto_restrict(), types::trigger_concentration_breach(),
                    concentration, 0, @0x0, 0, types::action_guardian_restrict(), option::none(), now_ms, ctx,
                )), option::none())
            };
        };
    };

    if (policy.monitor_forecast && mandateos::deepbook_forecast::is_stale(forecast, now_ms)) {
        if (types::allows_workflow_status(status, types::action_guardian_escalate())) {
            return (option::some(create_action(
                policy, types::guardian_auto_escalate(), types::trigger_stale_forecast(),
                5_000, 0, @0x0, 0, types::action_guardian_escalate(), option::none(), now_ms, ctx,
            )), option::none())
        };
    };

    if (policy.monitor_constitution && status == types::status_critical()) {
        if (types::allows_workflow_status(status, types::action_guardian_pause())) {
            return (option::some(create_action(
                policy, types::guardian_auto_pause(), types::trigger_constitution_breach(),
                9_000, 0, @0x0, 0, types::action_guardian_pause(), option::none(), now_ms, ctx,
            )), option::none())
        };
    };

    (option::none(), option::none())
}

fun destroy_action(action: GuardianAction) {
    let GuardianAction {
        id,
        mandate_id: _,
        policy_id: _,
        action_kind: _,
        trigger_kind: _,
        severity_bps: _,
        amount: _,
        recipient: _,
        obligation_id: _,
        workflow_action: _,
        remediation_plan_id,
        created_at_ms: _,
        executed: _,
    } = action;
    if (option::is_some(&remediation_plan_id)) {
        option::destroy_some(remediation_plan_id);
    } else {
        option::destroy_none(remediation_plan_id);
    };
    object::delete(id);
}

fun destroy_remediation_plan(plan: GuardianRemediationPlan) {
    let GuardianRemediationPlan {
        id,
        mandate_id: _,
        guardian_action_id: _,
        reason: _,
        source_allocation: _,
        target_allocation: _,
        liquidity_deficit: _,
        created_at: _,
        execution_status: _,
    } = plan;
    object::delete(id);
}

/// PTB tail: drop evaluate() options whether empty or populated (no share).
public fun discard_evaluation(
    action: Option<GuardianAction>,
    plan: Option<GuardianRemediationPlan>,
) {
    if (option::is_some(&action)) {
        destroy_action(option::destroy_some(action));
    } else {
        option::destroy_none(action);
    };
    if (option::is_some(&plan)) {
        destroy_remediation_plan(option::destroy_some(plan));
    } else {
        option::destroy_none(plan);
    };
}

/// PTB tail for `evaluate` — share corrective objects when present, else drop empty options.
public fun share_evaluation(
    action: Option<GuardianAction>,
    plan: Option<GuardianRemediationPlan>,
) {
    if (option::is_some(&action)) {
        share_action(option::destroy_some(action));
        if (option::is_some(&plan)) {
            share_remediation_plan(option::destroy_some(plan));
        } else {
            option::destroy_none(plan);
        };
    } else {
        option::destroy_none(action);
        option::destroy_none(plan);
    };
}

fun create_remediation_plan(
    mandate_id: ID,
    guardian_action_id: ID,
    reason: u8,
    source_allocation: u64,
    target_allocation: u64,
    liquidity_deficit: u64,
    created_at: u64,
    ctx: &mut TxContext,
): GuardianRemediationPlan {
    GuardianRemediationPlan {
        id: object::new(ctx),
        mandate_id,
        guardian_action_id,
        reason,
        source_allocation,
        target_allocation,
        liquidity_deficit,
        created_at,
        execution_status: types::remediation_pending(),
    }
}

fun create_action(
    policy: &GuardianPolicy,
    action_kind: u8,
    trigger_kind: u8,
    severity_bps: u64,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    workflow_action: u8,
    remediation_plan_id: Option<ID>,
    now_ms: u64,
    ctx: &mut TxContext,
): GuardianAction {
    event::emit(GuardianTriggered {
        policy_id: object::id(policy),
        mandate_id: policy.mandate_id,
        action_kind,
        trigger_kind,
    });

    GuardianAction {
        id: object::new(ctx),
        mandate_id: policy.mandate_id,
        policy_id: object::id(policy),
        action_kind,
        trigger_kind,
        severity_bps,
        amount,
        recipient,
        obligation_id,
        workflow_action,
        remediation_plan_id,
        created_at_ms: now_ms,
        executed: false,
    }
}

/// Execute guardian action through canonical workflow + simulation gate.
public fun execute_action<T>(
    action: &mut GuardianAction,
    plan: &mut Option<GuardianRemediationPlan>,
    policy: &GuardianPolicy,
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut mandateos::delegation::DailyExecutionTracker,
    approval: &mut SimulationApproval,
    clock: &Clock,
    ctx: &mut TxContext,
): GuardianActionReceipt {
    assert!(!action.executed, types::eguardian_action_invalid());
    assert!(action.mandate_id == policy.mandate_id, types::eguardian_action_invalid());
    assert!(action.policy_id == object::id(policy), types::eguardian_action_invalid());
    assert_action_enabled(policy, action.action_kind);

    if (action.action_kind == types::guardian_auto_reallocate()) {
        assert!(option::is_some(plan), types::eremediation_mismatch());
        let plan_ref = option::borrow_mut(plan);
        assert!(plan_ref.mandate_id == action.mandate_id, types::eremediation_mismatch());
        assert!(plan_ref.guardian_action_id == object::id(action), types::eremediation_mismatch());
        assert!(plan_ref.execution_status == types::remediation_pending(), types::eremediation_mismatch());

        let cap_opt = option::none<mandateos::delegation::ExecutorCap>();
        let receipt = run_guardian_settlement(
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
            action.workflow_action,
            action.amount,
            action.recipient,
            action.obligation_id,
            plan_ref,
            &cap_opt,
            approval,
            clock,
            ctx,
        );
        transfer::public_transfer(receipt, ctx.sender());
        option::destroy_none(cap_opt);
    } else {
        let cap_opt = option::none<mandateos::delegation::ExecutorCap>();
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
            action.workflow_action,
            action.amount,
            action.recipient,
            action.obligation_id,
            &cap_opt,
            approval,
            clock,
            ctx,
        );
        transfer::public_transfer(receipt, ctx.sender());
        option::destroy_none(cap_opt);
    };

    action.executed = true;
    let now_ms = clock.timestamp_ms();

    if (action.action_kind == types::guardian_auto_escalate()) {
        let escalation = EscalationIntent {
            id: object::new(ctx),
            mandate_id: action.mandate_id,
            guardian_action_id: object::id(action),
            trigger_kind: action.trigger_kind,
            severity_bps: action.severity_bps,
            escalated_at: now_ms,
            resolved: false,
        };
        transfer::share_object(escalation);
    };

    GuardianActionReceipt {
        id: object::new(ctx),
        action_id: object::id(action),
        mandate_id: action.mandate_id,
        action_kind: action.action_kind,
        trigger_kind: action.trigger_kind,
        workflow_id: workflow::session_id(session),
        remediation_plan_id: action.remediation_plan_id,
        executed_at: now_ms,
    }
}

/// Apply remediation during guardian settlement (no direct asset mutation).
public(package) fun execute_remediation_plan<T>(
    plan: &mut GuardianRemediationPlan,
    mandate: &mut FinancialMandate,
    engine: &mut LiquidityEngine,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &mut MandateVault<T>,
    now_ms: u64,
    ctx: &mut TxContext,
) {
    assert!(plan.execution_status == types::remediation_pending(), types::eremediation_mismatch());
    vault::set_illiquid_allocation(vault, plan.target_allocation);
    let objectives = mandate.objectives();
    adaptive_liquidity::rebalance_from_settlement(
        engine,
        objectives,
        obligations,
        forecast,
        hook,
        vault,
        now_ms,
    );
    plan.execution_status = types::remediation_executed();
    financial_mandate::apply_guardian_status_transition(mandate, types::action_guardian_reallocate());
    let receipt = mandateos::receipts::issue_remediation_receipt(
        object::id(plan),
        object::id(mandate),
        plan.reason,
        plan.source_allocation,
        plan.target_allocation,
        plan.liquidity_deficit,
        now_ms,
        ctx,
    );
    transfer::public_transfer(receipt, ctx.sender());
}

fun assert_action_enabled(policy: &GuardianPolicy, action_kind: u8) {
    if (action_kind == types::guardian_auto_pause()) {
        assert!(policy.auto_pause_enabled, types::eguardian_action_invalid());
    } else if (action_kind == types::guardian_auto_restrict()) {
        assert!(policy.auto_restrict_enabled, types::eguardian_action_invalid());
    } else if (action_kind == types::guardian_auto_reallocate()) {
        assert!(policy.auto_reallocate_enabled, types::eguardian_action_invalid());
    } else {
        assert!(policy.auto_escalate_enabled, types::eguardian_action_invalid());
    };
}

public fun policy_mandate_id(p: &GuardianPolicy): ID { p.mandate_id }
public fun action_kind(a: &GuardianAction): u8 { a.action_kind }
public fun plan_mandate_id(p: &GuardianRemediationPlan): ID { p.mandate_id }

/// Guardian settlement with remediation plan — REALLOCATE rebalance path.
public(package) fun settle_guardian<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    session: &WorkflowSession,
    execution_tracker: &mut mandateos::delegation::DailyExecutionTracker,
    executor_cap: &Option<mandateos::delegation::ExecutorCap>,
    remediation_plan: &mut GuardianRemediationPlan,
    auth: ExecutionAuthorization,
    vault: &mut MandateVault<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): (FinancialReceipt, WorkflowCompletionReceipt) {
    financial_mandate::assert_linkage_for_settlement(
        mandate,
        constitution,
        obligations,
        engine,
        vault,
        session,
        &auth,
    );

    let action = workflow::auth_action(&auth);
    assert!(action == types::action_guardian_reallocate(), types::eremediation_mismatch());

    let amount = workflow::auth_amount(&auth);
    let recipient = workflow::auth_recipient(&auth);
    let _obligation_id = workflow::auth_obligation_id(&auth);
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
        mandateos::authority::assert_executor(constitution, ctx.sender());
    };

    execute_remediation_plan(
        remediation_plan,
        mandate,
        engine,
        obligations,
        forecast,
        hook,
        vault,
        now_ms,
        ctx,
    );

    financial_mandate::emit_mandate_executed(
        mandate,
        session,
        action,
        amount,
        recipient,
        ctx.sender(),
    );

    let (risk_receipt, liquidity_receipt) = mandateos::receipts::issue_layer_receipts(&auth, ctx);
    transfer::public_transfer(risk_receipt, ctx.sender());
    transfer::public_transfer(liquidity_receipt, ctx.sender());

    let financial_receipt = mandateos::receipts::issue_financial_receipt(
        session,
        &auth,
        vault.balance_value(),
        ctx,
    );
    let completion = mandateos::receipts::issue_workflow_completion(session, now_ms, ctx);

    workflow::destroy_authorization(auth);

    (financial_receipt, completion)
}

/// Guardian settlement — same pipeline with remediation plan for REALLOCATE.
public(package) fun run_guardian_settlement<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk_profile: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut mandateos::delegation::DailyExecutionTracker,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    remediation_plan: &mut GuardianRemediationPlan,
    executor_cap: &Option<mandateos::delegation::ExecutorCap>,
    approval: &mut SimulationApproval,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    financial_mandate::assert_linkage(
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
    let constitutional = workflow::validate_constitution(
        session,
        intent,
        constitution,
        mandate.status(),
        vault,
        ctx.sender(),
        clock,
        false,
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

    let (receipt, completion) = settle_guardian(
        mandate,
        constitution,
        engine,
        obligations,
        forecast,
        hook,
        session,
        execution_tracker,
        executor_cap,
        remediation_plan,
        auth,
        vault,
        clock,
        ctx,
    );
    transfer::public_transfer(completion, ctx.sender());
    receipt
}
