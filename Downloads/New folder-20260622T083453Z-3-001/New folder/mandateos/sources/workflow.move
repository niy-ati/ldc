/// PTB Financial Workflow Layer — composable pipeline with non-forgeable capabilities.
module mandateos::workflow;

use sui::clock::Clock;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{FinancialObjectives, ObligationRegistry};
use mandateos::operational_risk::{Self, OperationalRiskProfile, RiskCleared};
use mandateos::adaptive_liquidity::{Self, LiquidityEngine, LiquidityCleared};
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::types::{Self};
use mandateos::vault::{Self, MandateVault};

// ── Workflow steps ────────────────────────────────────────────────────────────

const STEP_INTENT: u8 = 1;
const STEP_CONSTITUTIONAL: u8 = 2;
const STEP_RISK: u8 = 3;
const STEP_LIQUIDITY: u8 = 4;
const STEP_AUTHORIZED: u8 = 5;

// ── Non-forgeable hot-potato witnesses (no copy, drop, or store) ──────────────

public struct WorkflowIntent {
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    initiated_at: u64,
}

public struct ConstitutionallyValidated {
    intent: WorkflowIntent,
    constitution_version: u64,
}

public struct RiskValidated {
    intent: WorkflowIntent,
    risk: RiskCleared,
}

public struct LiquidityValidated {
    intent: WorkflowIntent,
    risk: RiskCleared,
    liquidity: LiquidityCleared,
}

/// Sole capability permitting vault debit. Only produced by authorize_execution.
public struct ExecutionAuthorization {
    mandate_id: ID,
    workflow_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    validated_at: u64,
    risk: RiskCleared,
    liquidity: LiquidityCleared,
}

public struct WorkflowSession has key, store {
    id: UID,
    mandate_id: ID,
    current_step: u8,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    started_at: u64,
}

// ── Session lifecycle ─────────────────────────────────────────────────────────

public fun open_session(
    mandate_id: ID,
    clock: &Clock,
    ctx: &mut TxContext,
): WorkflowSession {
    WorkflowSession {
        id: object::new(ctx),
        mandate_id,
        current_step: 0,
        action: 0,
        amount: 0,
        recipient: @0x0,
        obligation_id: 0,
        started_at: clock.timestamp_ms(),
    }
}

// ── PTB steps (each consumes prior witness) ───────────────────────────────────

public fun begin_intent(
    session: &mut WorkflowSession,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    clock: &Clock,
): WorkflowIntent {
    assert!(amount > 0 || types::is_guardian_action(action), types::einvalid_amount());
    session.current_step = STEP_INTENT;
    session.action = action;
    session.amount = amount;
    session.recipient = recipient;
    session.obligation_id = obligation_id;

    WorkflowIntent {
        mandate_id: session.mandate_id,
        action,
        amount,
        recipient,
        obligation_id,
        initiated_at: clock.timestamp_ms(),
    }
}

public fun validate_constitution<T>(
    session: &mut WorkflowSession,
    intent: WorkflowIntent,
    constitution: &FinancialConstitution,
    mandate_status: u8,
    vault: &MandateVault<T>,
    executor: address,
    clock: &Clock,
    skip_governance: bool,
): ConstitutionallyValidated {
    assert!(session.mandate_id == intent.mandate_id, types::eworkflow_mismatch());
    assert!(types::allows_workflow_status(mandate_status, intent.action), types::einvalid_mandate_status());
    assert!(constitution.mandate_id() == intent.mandate_id, types::evault_mismatch());
    assert!(vault::mandate_id(vault) == intent.mandate_id, types::evault_mismatch());

    let now_ms = clock.timestamp_ms();
    let day = now_ms / 86_400_000;

    mandateos::validation::check_constitutional(
        constitution,
        intent.action,
        intent.amount,
        intent.recipient,
        executor,
        now_ms,
        day,
        vault,
        skip_governance,
    );

    session.current_step = STEP_CONSTITUTIONAL;
    ConstitutionallyValidated {
        intent,
        constitution_version: constitution.version(),
    }
}

public fun assess_risk<T>(
    session: &mut WorkflowSession,
    constitutional: ConstitutionallyValidated,
    risk_profile: &mut OperationalRiskProfile,
    obligations: &ObligationRegistry,
    objectives: &FinancialObjectives,
    vault: &MandateVault<T>,
    clock: &Clock,
): RiskValidated {
    let ConstitutionallyValidated { intent, constitution_version } = constitutional;
    assert!(session.mandate_id == intent.mandate_id, types::eworkflow_mismatch());

    let horizon = objectives.min_runway_days() * 86_400_000;
    let upcoming = mandateos::objectives::upcoming_obligation_exposure(
        obligations,
        horizon,
        clock.timestamp_ms(),
    );

    let risk = operational_risk::assess_execution(
        risk_profile,
        intent.mandate_id,
        intent.action,
        intent.amount,
        intent.recipient,
        vault::balance_value(vault),
        vault.liquid_balance_after_debit(0),
        upcoming,
        constitution_version,
        clock.timestamp_ms(),
    );

    session.current_step = STEP_RISK;
    RiskValidated { intent, risk }
}

public fun check_adaptive_liquidity<T>(
    session: &mut WorkflowSession,
    risk_validated: RiskValidated,
    engine: &LiquidityEngine,
    objectives: &FinancialObjectives,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
    clock: &Clock,
): LiquidityValidated {
    let RiskValidated { intent, risk } = risk_validated;
    assert!(session.mandate_id == intent.mandate_id, types::eworkflow_mismatch());

    let liquidity = adaptive_liquidity::assess_debit(
        engine,
        objectives,
        obligations,
        forecast,
        hook,
        vault,
        intent.amount,
        clock.timestamp_ms(),
    );

    session.current_step = STEP_LIQUIDITY;
    LiquidityValidated {
        intent,
        risk,
        liquidity,
    }
}

public(package) fun discard_liquidity_validated(v: LiquidityValidated) {
    let LiquidityValidated { intent, risk, liquidity } = v;
    let WorkflowIntent {
        mandate_id: _,
        action: _,
        amount: _,
        recipient: _,
        obligation_id: _,
        initiated_at: _,
    } = intent;
    operational_risk::destroy_cleared(risk);
    adaptive_liquidity::destroy_cleared(liquidity);
}

public fun destroy_session(session: WorkflowSession) {
    let WorkflowSession {
        id,
        mandate_id: _,
        current_step: _,
        action: _,
        amount: _,
        recipient: _,
        obligation_id: _,
        started_at: _,
    } = session;
    object::delete(id);
}

/// Final workflow step — mints ExecutionAuthorization only from approved simulation.
public fun authorize_execution(
    session: &mut WorkflowSession,
    liquidity_validated: LiquidityValidated,
    clock: &Clock,
): ExecutionAuthorization {
    let LiquidityValidated { intent, risk, liquidity } = liquidity_validated;
    let WorkflowIntent {
        mandate_id,
        action,
        amount,
        recipient,
        obligation_id,
        initiated_at: _,
    } = intent;
    assert!(session.mandate_id == mandate_id, types::eworkflow_mismatch());
    session.current_step = STEP_AUTHORIZED;

    ExecutionAuthorization {
        mandate_id,
        workflow_id: object::id(session),
        action,
        amount,
        recipient,
        obligation_id,
        validated_at: clock.timestamp_ms(),
        risk,
        liquidity,
    }
}

public(package) fun destroy_authorization(auth: ExecutionAuthorization) {
    let ExecutionAuthorization {
        mandate_id: _,
        workflow_id: _,
        action: _,
        amount: _,
        recipient: _,
        obligation_id: _,
        validated_at: _,
        risk,
        liquidity,
    } = auth;
    operational_risk::destroy_cleared(risk);
    adaptive_liquidity::destroy_cleared(liquidity);
}

// ── Authorization accessors (read-only; settlement module uses these) ─────────

public(package) fun auth_mandate_id(a: &ExecutionAuthorization): ID { a.mandate_id }
public(package) fun auth_workflow_id(a: &ExecutionAuthorization): ID { a.workflow_id }
public(package) fun auth_action(a: &ExecutionAuthorization): u8 { a.action }
public(package) fun auth_amount(a: &ExecutionAuthorization): u64 { a.amount }
public(package) fun auth_recipient(a: &ExecutionAuthorization): address { a.recipient }
public(package) fun auth_obligation_id(a: &ExecutionAuthorization): u64 { a.obligation_id }
public(package) fun auth_validated_at(a: &ExecutionAuthorization): u64 { a.validated_at }
public(package) fun auth_risk(a: &ExecutionAuthorization): &RiskCleared { &a.risk }
public(package) fun auth_liquidity(a: &ExecutionAuthorization): &LiquidityCleared { &a.liquidity }

// ── Session accessors ─────────────────────────────────────────────────────────

public fun session_id(s: &WorkflowSession): ID { object::id(s) }
public fun session_mandate_id(s: &WorkflowSession): ID { s.mandate_id }
public fun session_obligation_id(s: &WorkflowSession): u64 { s.obligation_id }
public fun steps_completed(s: &WorkflowSession): u8 { s.current_step }

public fun step_intent(): u8 { STEP_INTENT }
public fun step_constitutional(): u8 { STEP_CONSTITUTIONAL }
public fun step_risk(): u8 { STEP_RISK }
public fun step_liquidity(): u8 { STEP_LIQUIDITY }
public fun step_authorized(): u8 { STEP_AUTHORIZED }
