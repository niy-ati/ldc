/// PTB client shim — composes MandateOS simulation inside a single Move call.
/// External PTBs cannot pass `&FinancialObjectives` across commands (no `drop`).
module mandateos_ptb::client;

use sui::clock::Clock;
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::ObligationRegistry;
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::vault::MandateVault;
use mandateos::simulation::{Self, SimulationApproval};

/// Governor simulation + approval in one PTB-safe entry (mirrors test_helpers::simulate_and_approve).
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
        financial_mandate::status(mandate),
        constitution,
        risk,
        engine,
        obligations,
        financial_mandate::objectives(mandate),
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
