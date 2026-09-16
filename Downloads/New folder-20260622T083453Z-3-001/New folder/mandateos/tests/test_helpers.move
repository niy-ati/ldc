#[test_only]
module mandateos::test_helpers;

use std::option;
use sui::test_scenario::{Self as ts, Scenario};
use sui::clock::{Self, Clock};
use sui::coin;
use sui::sui::SUI;
use mandateos::mandateos;
use mandateos::treasury_mandate::{Self, TreasuryConfig};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::ObligationRegistry;
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::vault::{Self, MandateVault};
use mandateos::simulation::{Self, SimulationSession, ProjectedOutcome, SimulationApproval};
use mandateos::guardian::{Self, GuardianPolicy, GuardianAction, GuardianRemediationPlan, GuardianActionReceipt};
use mandateos::workflow::{Self, WorkflowSession};
use mandateos::delegation::{Self, DelegationCap, DailyExecutionTracker, ExecutorCap};
use mandateos::receipts::FinancialReceipt;
use mandateos::types;

const OWNER: address = @0xA11CE;
const EXECUTOR: address = @0xB0B;
const RECIPIENT: address = @0xCAFE;
const AGENT: address = @0xDEAD;
const INTRUDER: address = @0xBAD;

public fun owner(): address { OWNER }
public fun executor(): address { EXECUTOR }
public fun recipient(): address { RECIPIENT }
public fun agent(): address { AGENT }
public fun intruder(): address { INTRUDER }

/// Bootstrap treasury mandate with canonical OS graph and share on-chain.
public fun init_treasury_scenario(
    scenario: &mut Scenario,
    min_reserve_bps: u64,
) {
    mandateos::init_for_testing(ts::ctx(scenario));
    ts::next_tx(scenario, OWNER);
    {
        let clock = clock::create_for_testing(ts::ctx(scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                OWNER,
                EXECUTOR,
                10_000_000_000,
                5_000_000_000,
                10_000_000_000,
                min_reserve_bps,
                0,
                RECIPIENT,
                1,
                &clock,
                ts::ctx(scenario),
            );
        treasury_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, execution_tracker, config,
        );
        clock::share_for_testing(clock);
    };
}

public fun fund_treasury(scenario: &mut Scenario, amount: u64) {
    ts::next_tx(scenario, OWNER);
    {
        let coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
        let mut vault = ts::take_shared<MandateVault<SUI>>(scenario);
        treasury_mandate::fund(&mut vault, coin);
        ts::return_shared(vault);
    };
}

public fun simulate_and_approve(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &LiquidityEngine,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<SUI>,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
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
        financial_mandate::status(mandate),
        constitution,
        risk,
        engine,
        obligations,
        financial_mandate::objectives(mandate),
        forecast,
        hook,
        vault,
        EXECUTOR,
        clock,
        ctx,
    );
    let approval = simulation::approve_simulation(&mut outcome, constitution, clock, ctx);
    simulation::share_outcome(outcome);
    simulation::share_session(sim);
    approval
}

public fun simulate_and_approve_guardian(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &LiquidityEngine,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<SUI>,
    guardian_action: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): SimulationApproval {
    let approval = simulate_and_approve(
        mandate,
        constitution,
        risk,
        engine,
        obligations,
        forecast,
        hook,
        vault,
        guardian_action,
        0,
        @0x0,
        0,
        clock,
        ctx,
    );
    approval
}

/// Assert every bootstrap object links to the same mandate_id.
public fun assert_canonical_graph(
    mandate: &FinancialMandate,
    vault: &MandateVault<SUI>,
    constitution: &FinancialConstitution,
    obligations: &ObligationRegistry,
    risk: &OperationalRiskProfile,
    engine: &LiquidityEngine,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    guardian: &GuardianPolicy,
    delegation_cap: &DelegationCap,
    tracker: &DailyExecutionTracker,
) {
    let mid = object::id(mandate);
    assert!(financial_mandate::vault_id(mandate) == object::id(vault), 0);
    assert!(financial_mandate::constitutional_id(mandate) == object::id(constitution), 1);
    assert!(financial_mandate::obligation_registry_id(mandate) == object::id(obligations), 2);
    assert!(financial_mandate::risk_profile_id(mandate) == object::id(risk), 3);
    assert!(financial_mandate::liquidity_engine_id(mandate) == object::id(engine), 4);
    assert!(financial_mandate::forecast_id(mandate) == object::id(forecast), 5);
    assert!(financial_mandate::hook_id(mandate) == object::id(hook), 6);
    assert!(vault::mandate_id(vault) == mid, 7);
    assert!(constitution.mandate_id() == mid, 8);
    assert!(obligations.registry_mandate_id() == mid, 9);
    assert!(risk.profile_mandate_id() == mid, 10);
    assert!(engine.engine_mandate_id() == mid, 11);
    assert!(forecast.forecast_mandate_id() == mid, 12);
    assert!(hook.hook_mandate_id() == mid, 13);
    assert!(guardian::policy_mandate_id(guardian) == mid, 14);
    assert!(delegation::cap_mandate_id(delegation_cap) == mid, 15);
    assert!(delegation::tracker_mandate_id(tracker) == mid, 16);
}

public fun assert_guardian_action_kind(action: &GuardianAction, expected: u8) {
    assert!(guardian::action_kind(action) == expected, 0);
}

public fun assert_plan_linked_to_mandate(plan: &GuardianRemediationPlan, mandate_id: ID) {
    assert!(guardian::plan_mandate_id(plan) == mandate_id, 0);
}

public fun consume_receipt(receipt: FinancialReceipt, holder: address) {
    transfer::public_transfer(receipt, holder);
}

public fun transfer_approval(approval: SimulationApproval, recipient: address) {
    simulation::transfer_approval(approval, recipient);
}

public fun dispose_approval(approval: SimulationApproval, holder: address) {
    simulation::transfer_approval(approval, holder);
}

public fun destroy_workflow_session(session: WorkflowSession) {
    workflow::destroy_session(session);
}

public fun destroy_executor_cap_option(cap_opt: Option<ExecutorCap>) {
    option::destroy_none(cap_opt);
}

public fun finish_settlement_tx(
    approval: SimulationApproval,
    session: WorkflowSession,
    cap_opt: Option<ExecutorCap>,
    holder: address,
) {
    dispose_approval(approval, holder);
    destroy_workflow_session(session);
    destroy_executor_cap_option(cap_opt);
}

public fun finish_settlement_with_cap(
    approval: SimulationApproval,
    session: WorkflowSession,
    mut cap_opt: Option<ExecutorCap>,
    holder: address,
    scenario: &mut Scenario,
) {
    dispose_approval(approval, holder);
    destroy_workflow_session(session);
    ts::return_to_sender(scenario, option::extract(&mut cap_opt));
    option::destroy_none(cap_opt);
}

public fun finish_guardian_action_tx(
    approval: SimulationApproval,
    session: WorkflowSession,
    action_receipt: GuardianActionReceipt,
    holder: address,
) {
    guardian::transfer_action_receipt(action_receipt, holder);
    dispose_approval(approval, holder);
    destroy_workflow_session(session);
}

public fun share_guardian_evaluation(
    action_opt: Option<GuardianAction>,
    plan_opt: Option<GuardianRemediationPlan>,
) {
    guardian::share_action(option::destroy_some(action_opt));
    if (option::is_some(&plan_opt)) {
        guardian::share_remediation_plan(option::destroy_some(plan_opt));
    } else {
        option::destroy_none(plan_opt);
    };
}

public fun dispose_plan_opt(mut plan_opt: Option<GuardianRemediationPlan>) {
    if (option::is_some(&plan_opt)) {
        guardian::share_remediation_plan(option::extract(&mut plan_opt));
    };
    option::destroy_none(plan_opt);
}

public fun destroy_workflow_authorization(auth: workflow::ExecutionAuthorization) {
    workflow::destroy_authorization(auth);
}

/// Wraps treasury disbursement that is expected to abort; owns approval, session, and cap.
public fun attempt_treasury_disbursement<SUI>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    config: &TreasuryConfig,
    vault: &mut MandateVault<SUI>,
    execution_tracker: &mut DailyExecutionTracker,
    approval: SimulationApproval,
    session: WorkflowSession,
    cap_opt: Option<ExecutorCap>,
    amount: u64,
    recipient: address,
    holder: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let mut approval = approval;
    let mut session = session;
    let receipt = treasury_mandate::treasury_disbursement(
        mandate,
        constitution,
        risk,
        engine,
        obligations,
        forecast,
        hook,
        config,
        vault,
        &mut session,
        execution_tracker,
        &mut approval,
        &cap_opt,
        amount,
        recipient,
        clock,
        ctx,
    );
    consume_receipt(receipt, holder);
    finish_settlement_tx(approval, session, cap_opt, holder);
}

/// Wraps assert_approval_matches that is expected to abort; owns approval and session.
public fun attempt_assert_approval_matches(
    mut approval: SimulationApproval,
    mut session: WorkflowSession,
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    now_ms: u64,
    holder: address,
) {
    simulation::assert_approval_matches(
        &mut approval,
        mandate_id,
        action,
        amount,
        recipient,
        obligation_id,
        now_ms,
    );
    dispose_approval(approval, holder);
    destroy_workflow_session(session);
}

/// Full workflow through assert_approval_matches that is expected to abort.
public fun attempt_workflow_approval_mismatch(
    mut approval: SimulationApproval,
    mut session: WorkflowSession,
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    obligations: &ObligationRegistry,
    engine: &LiquidityEngine,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<SUI>,
    clock: &Clock,
    amount: u64,
    holder: address,
) {
    let intent = workflow::begin_intent(
        &mut session,
        types::action_treasury(),
        amount,
        RECIPIENT,
        0,
        clock,
    );
    let constitutional = workflow::validate_constitution(
        &mut session,
        intent,
        constitution,
        financial_mandate::status(mandate),
        vault,
        EXECUTOR,
        clock,
        false,
    );
    let risk_validated = workflow::assess_risk(
        &mut session,
        constitutional,
        risk,
        obligations,
        financial_mandate::objectives(mandate),
        vault,
        clock,
    );
    let liquidity_validated = workflow::check_adaptive_liquidity(
        &mut session,
        risk_validated,
        engine,
        financial_mandate::objectives(mandate),
        obligations,
        forecast,
        hook,
        vault,
        clock,
    );
    simulation::assert_approval_matches(
        &mut approval,
        object::id(mandate),
        types::action_treasury(),
        amount,
        RECIPIENT,
        0,
        clock.timestamp_ms(),
    );
    let auth = workflow::authorize_execution(&mut session, liquidity_validated, clock);
    workflow::destroy_authorization(auth);
    dispose_approval(approval, holder);
    destroy_workflow_session(session);
}

/// Consumes approval once via workflow; returns consumed approval for reuse tests.
public fun consume_approval_via_workflow(
    mut approval: SimulationApproval,
    mut session: WorkflowSession,
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    obligations: &ObligationRegistry,
    engine: &LiquidityEngine,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<SUI>,
    clock: &Clock,
    amount: u64,
): SimulationApproval {
    let intent = workflow::begin_intent(
        &mut session,
        types::action_treasury(),
        amount,
        RECIPIENT,
        0,
        clock,
    );
    let constitutional = workflow::validate_constitution(
        &mut session,
        intent,
        constitution,
        financial_mandate::status(mandate),
        vault,
        EXECUTOR,
        clock,
        false,
    );
    let risk_validated = workflow::assess_risk(
        &mut session,
        constitutional,
        risk,
        obligations,
        financial_mandate::objectives(mandate),
        vault,
        clock,
    );
    let liquidity_validated = workflow::check_adaptive_liquidity(
        &mut session,
        risk_validated,
        engine,
        financial_mandate::objectives(mandate),
        obligations,
        forecast,
        hook,
        vault,
        clock,
    );
    simulation::assert_approval_matches(
        &mut approval,
        object::id(mandate),
        types::action_treasury(),
        amount,
        RECIPIENT,
        0,
        clock.timestamp_ms(),
    );
    let auth = workflow::authorize_execution(&mut session, liquidity_validated, clock);
    workflow::destroy_authorization(auth);
    destroy_workflow_session(session);
    approval
}

/// Second workflow attempt with already-consumed approval; expected to abort.
public fun attempt_reuse_consumed_approval_workflow(
    mut approval: SimulationApproval,
    mut session: WorkflowSession,
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    obligations: &ObligationRegistry,
    engine: &LiquidityEngine,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<SUI>,
    clock: &Clock,
    amount: u64,
    holder: address,
) {
    let intent = workflow::begin_intent(
        &mut session,
        types::action_treasury(),
        amount,
        RECIPIENT,
        0,
        clock,
    );
    let constitutional = workflow::validate_constitution(
        &mut session,
        intent,
        constitution,
        financial_mandate::status(mandate),
        vault,
        EXECUTOR,
        clock,
        false,
    );
    let risk_validated = workflow::assess_risk(
        &mut session,
        constitutional,
        risk,
        obligations,
        financial_mandate::objectives(mandate),
        vault,
        clock,
    );
    let liquidity_validated = workflow::check_adaptive_liquidity(
        &mut session,
        risk_validated,
        engine,
        financial_mandate::objectives(mandate),
        obligations,
        forecast,
        hook,
        vault,
        clock,
    );
    simulation::assert_approval_matches(
        &mut approval,
        object::id(mandate),
        types::action_treasury(),
        amount,
        RECIPIENT,
        0,
        clock.timestamp_ms(),
    );
    let auth = workflow::authorize_execution(&mut session, liquidity_validated, clock);
    workflow::destroy_authorization(auth);
    dispose_approval(approval, holder);
    destroy_workflow_session(session);
}

/// Wraps approve_simulation that is expected to abort; owns sim and outcome.
public fun attempt_approve_simulation(
    sim: SimulationSession,
    mut outcome: ProjectedOutcome,
    constitution: &FinancialConstitution,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let _approval = simulation::approve_simulation(&mut outcome, constitution, clock, ctx);
    simulation::share_outcome(outcome);
    simulation::share_session(sim);
    transfer_approval(_approval, ctx.sender());
}
