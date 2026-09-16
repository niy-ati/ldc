/// Simulation System — pre-commit dry runs required before execution authorization.
module mandateos::simulation;

use sui::clock::Clock;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{FinancialObjectives, ObligationRegistry};
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::workflow::{Self, WorkflowSession, ConstitutionallyValidated};
use mandateos::authority;
use mandateos::types::{Self};
use mandateos::vault::MandateVault;

const SIMULATION_TTL_MS: u64 = 3_600_000;

/// Dry-run session — mirrors workflow without vault mutation.
public struct SimulationSession has key, store {
    id: UID,
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    started_at: u64,
    completed: bool,
}

public struct RiskProjection has store, copy, drop {
    stress_score_bps: u64,
    concentration_bps: u64,
    counterparty_risk_bps: u64,
    constitution_version: u64,
    passes: bool,
}

public struct LiquidityProjection has store, copy, drop {
    runway_days_after: u64,
    liquid_after_debit: u64,
    coverage_bps: u64,
    passes: bool,
}

/// Immutable projected outcome from a simulation run.
public struct ProjectedOutcome has key, store {
    id: UID,
    simulation_id: ID,
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    risk: RiskProjection,
    liquidity: LiquidityProjection,
    projected_at: u64,
    approved: bool,
}

/// On-chain approval object — consumed when minting ExecutionAuthorization.
public struct SimulationApproval has key, store {
    id: UID,
    simulation_id: ID,
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    approved_at: u64,
    expires_at_ms: u64,
    consumed: bool,
}

public fun open_simulation(
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): SimulationSession {
    assert!(amount > 0 || types::is_guardian_action(action), types::einvalid_amount());
    SimulationSession {
        id: object::new(ctx),
        mandate_id,
        action,
        amount,
        recipient,
        obligation_id,
        started_at: clock.timestamp_ms(),
        completed: false,
    }
}

/// Run projection through the same validation pipeline as workflow (no vault debit).
public fun run_projection<T>(
    sim: &mut SimulationSession,
    mandate_id: ID,
    mandate_status: u8,
    constitution: &FinancialConstitution,
    risk_profile: &mut OperationalRiskProfile,
    engine: &LiquidityEngine,
    obligations: &ObligationRegistry,
    objectives: &FinancialObjectives,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
    executor: address,
    clock: &Clock,
    ctx: &mut TxContext,
): ProjectedOutcome {
    assert!(sim.mandate_id == mandate_id, types::esimulation_mismatch());
    assert!(!sim.completed, types::esimulation_mismatch());

    let mut session = workflow::open_session(mandate_id, clock, ctx);
    let intent = workflow::begin_intent(
        &mut session,
        sim.action,
        sim.amount,
        sim.recipient,
        sim.obligation_id,
        clock,
    );
    let constitutional = workflow::validate_constitution(
        &mut session,
        intent,
        constitution,
        mandate_status,
        vault,
        executor,
        clock,
        false,
    );
    let constitution_version = constitution.version();
    let risk_validated = workflow::assess_risk(
        &mut session,
        constitutional,
        risk_profile,
        obligations,
        objectives,
        vault,
        clock,
    );
    let liquidity_validated = workflow::check_adaptive_liquidity(
        &mut session,
        risk_validated,
        engine,
        objectives,
        obligations,
        forecast,
        hook,
        vault,
        clock,
    );
    workflow::discard_liquidity_validated(liquidity_validated);
    workflow::destroy_session(session);

    let now_ms = clock.timestamp_ms();
    let balance = vault.balance_value();
    let liquid_after = vault.liquid_balance_after_debit(sim.amount);
    let horizon = objectives.min_runway_days() * 86_400_000;
    let upcoming = mandateos::objectives::upcoming_obligation_exposure(
        obligations,
        horizon,
        now_ms,
    );
    let denom = if (balance == 0) { 1 } else { balance };
    let concentration_bps = (sim.amount * 10_000) / denom;
    let runway_after = if (upcoming > 0 && liquid_after > 0) {
        (liquid_after * objectives.min_runway_days()) / denom
    } else {
        objectives.min_runway_days()
    };

    sim.completed = true;

    ProjectedOutcome {
        id: object::new(ctx),
        simulation_id: object::id(sim),
        mandate_id,
        action: sim.action,
        amount: sim.amount,
        recipient: sim.recipient,
        obligation_id: sim.obligation_id,
        risk: RiskProjection {
            stress_score_bps: if (mandateos::operational_risk::stress_mode(risk_profile)) {
                10_000
            } else {
                mandateos::operational_risk::portfolio_risk_score(risk_profile)
            },
            concentration_bps,
            counterparty_risk_bps: mandateos::operational_risk::portfolio_risk_score(risk_profile),
            constitution_version,
            passes: true,
        },
        liquidity: LiquidityProjection {
            runway_days_after: runway_after,
            liquid_after_debit: liquid_after,
            coverage_bps: if (upcoming > 0) { (liquid_after * 10_000) / upcoming } else { 10_000 },
            passes: true,
        },
        projected_at: now_ms,
        approved: false,
    }
}

/// Governor approves simulation — creates consumable SimulationApproval object.
public fun approve_simulation(
    outcome: &mut ProjectedOutcome,
    constitution: &FinancialConstitution,
    clock: &Clock,
    ctx: &mut TxContext,
): SimulationApproval {
    assert!(!outcome.approved, types::esimulation_not_approved());
    assert!(outcome.mandate_id == constitution.mandate_id(), types::esimulation_mismatch());
    authority::assert_governor(constitution, ctx.sender());

    let now_ms = clock.timestamp_ms();
    outcome.approved = true;

    SimulationApproval {
        id: object::new(ctx),
        simulation_id: outcome.simulation_id,
        mandate_id: outcome.mandate_id,
        action: outcome.action,
        amount: outcome.amount,
        recipient: outcome.recipient,
        obligation_id: outcome.obligation_id,
        approved_at: now_ms,
        expires_at_ms: now_ms + SIMULATION_TTL_MS,
        consumed: false,
    }
}

public(package) fun assert_approval_matches(
    approval: &mut SimulationApproval,
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    obligation_id: u64,
    now_ms: u64,
) {
    assert!(!approval.consumed, types::esimulation_not_approved());
    assert!(approval.mandate_id == mandate_id, types::esimulation_mismatch());
    assert!(approval.action == action, types::esimulation_mismatch());
    assert!(approval.amount == amount, types::esimulation_mismatch());
    assert!(approval.recipient == recipient, types::esimulation_mismatch());
    assert!(approval.obligation_id == obligation_id, types::esimulation_mismatch());
    assert!(now_ms < approval.expires_at_ms, types::esimulation_expired());
    approval.consumed = true;
}

public fun share_session(sim: SimulationSession) {
    transfer::share_object(sim);
}

public fun simulation_id(s: &SimulationSession): ID { object::id(s) }
public fun outcome_simulation_id(o: &ProjectedOutcome): ID { o.simulation_id }
public fun outcome_approved(o: &ProjectedOutcome): bool { o.approved }

public fun share_outcome(outcome: ProjectedOutcome) {
    transfer::share_object(outcome);
}

public fun transfer_approval(approval: SimulationApproval, recipient: address) {
    transfer::transfer(approval, recipient);
}
