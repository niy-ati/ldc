/// Adaptive Liquidity Engine — dynamic buffers from obligations, velocity, and forecasts.
module mandateos::adaptive_liquidity;

use sui::event;
use mandateos::authority;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{Self, FinancialObjectives, ObligationRegistry};
use mandateos::deepbook_forecast::{Self, MarketForecast, DeepBookHook};
use mandateos::types::{Self};
use mandateos::vault::MandateVault;

public struct LiquidityEngine has key {
    id: UID,
    mandate_id: ID,
    base_buffer_bps: u64,
    obligation_buffer_bps: u64,
    forecast_buffer_bps: u64,
    velocity_buffer_bps: u64,
    total_required_buffer: u64,
    avg_daily_outflow: u64,
    last_rebalance_ms: u64,
    rebalance_count: u64,
}

public struct LiquidityAssessment has copy, drop, store {
    mandate_id: ID,
    required_buffer: u64,
    available_liquid: u64,
    post_debit_liquid: u64,
    forecast_multiplier_bps: u64,
    obligation_exposure: u64,
    cleared: bool,
    assessed_at: u64,
}

/// Non-forgeable clearance witness — only produced by assess_debit.
public struct LiquidityCleared {
    assessment: LiquidityAssessment,
}

public struct LiquidityRebalanced has copy, drop {
    engine_id: ID,
    mandate_id: ID,
    total_required_buffer: u64,
    forecast_buffer_bps: u64,
}

public(package) fun create_engine(
    mandate_id: ID,
    base_buffer_bps: u64,
    ctx: &mut TxContext,
): LiquidityEngine {
    LiquidityEngine {
        id: object::new(ctx),
        mandate_id,
        base_buffer_bps,
        obligation_buffer_bps: 0,
        forecast_buffer_bps: 0,
        velocity_buffer_bps: 0,
        total_required_buffer: 0,
        avg_daily_outflow: 0,
        last_rebalance_ms: 0,
        rebalance_count: 0,
    }
}

public fun rebalance<T>(
    engine: &mut LiquidityEngine,
    constitution: &FinancialConstitution,
    objectives: &FinancialObjectives,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
    now_ms: u64,
    ctx: &TxContext,
) {
    assert!(engine.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    assert!(engine.mandate_id == vault.mandate_id(), types::evault_mismatch());
    authority::assert_governor_or_executor(constitution, ctx.sender());

    let horizon = objectives.min_runway_days() * 86_400_000;
    let obligation_exposure = objectives::upcoming_obligation_exposure(obligations, horizon, now_ms);

    engine.obligation_buffer_bps = if (vault.balance_value() == 0) {
        0
    } else {
        (obligation_exposure * 10000) / vault.balance_value()
    };

    engine.forecast_buffer_bps = deepbook_forecast::forecast_buffer_multiplier(forecast, hook);
    if (engine.forecast_buffer_bps > 10000) {
        engine.forecast_buffer_bps = engine.forecast_buffer_bps - 10000;
    } else {
        engine.forecast_buffer_bps = 0;
    };

    engine.velocity_buffer_bps = if (vault.balance_value() == 0) {
        0
    } else {
        (engine.avg_daily_outflow * 10000) / vault.balance_value()
    };

    let covenant_bps = objectives.reserve_covenant_bps();
    engine.total_required_buffer = compute_buffer_amount(
        vault.balance_value(),
        engine.base_buffer_bps,
        engine.obligation_buffer_bps,
        engine.forecast_buffer_bps,
        engine.velocity_buffer_bps,
        covenant_bps,
    );

    engine.last_rebalance_ms = now_ms;
    engine.rebalance_count = engine.rebalance_count + 1;

    event::emit(LiquidityRebalanced {
        engine_id: object::id(engine),
        mandate_id: engine.mandate_id,
        total_required_buffer: engine.total_required_buffer,
        forecast_buffer_bps: engine.forecast_buffer_bps,
    });
}

/// Workflow-only liquidity gate.
public(package) fun assess_debit<T>(
    engine: &LiquidityEngine,
    objectives: &FinancialObjectives,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
    debit_amount: u64,
    now_ms: u64,
): LiquidityCleared {
    let horizon = objectives.min_runway_days() * 86_400_000;
    let obligation_exposure = objectives::upcoming_obligation_exposure(obligations, horizon, now_ms);
    let available_liquid = vault.liquid_balance_after_debit(0);
    let post_debit_liquid = vault.liquid_balance_after_debit(debit_amount);

    let required = engine.total_required_buffer;
    if (debit_amount > 0) {
        if (required == 0) {
            let covenant_amount = (vault.balance_value() * objectives.reserve_covenant_bps()) / 10000;
            assert!(post_debit_liquid >= covenant_amount, types::einsufficient_liquidity());
        } else {
            assert!(post_debit_liquid >= required, types::einsufficient_liquidity());
        };
    };

    let _ = deepbook_forecast::pre_execution_hook(
        hook,
        forecast,
        debit_amount,
        vault.balance_value(),
        now_ms,
    );

    LiquidityCleared {
        assessment: LiquidityAssessment {
            mandate_id: engine.mandate_id,
            required_buffer: required,
            available_liquid,
            post_debit_liquid,
            forecast_multiplier_bps: engine.forecast_buffer_bps,
            obligation_exposure,
            cleared: true,
            assessed_at: now_ms,
        },
    }
}

public(package) fun record_outflow(engine: &mut LiquidityEngine, amount: u64) {
    if (engine.avg_daily_outflow == 0) {
        engine.avg_daily_outflow = amount;
    } else {
        engine.avg_daily_outflow = (engine.avg_daily_outflow * 7 + amount) / 8;
    };
}

fun compute_buffer_amount(
    balance: u64,
    base_bps: u64,
    obligation_bps: u64,
    forecast_bps: u64,
    velocity_bps: u64,
    covenant_bps: u64,
): u64 {
    let total_bps = base_bps + obligation_bps + forecast_bps + velocity_bps;
    let effective_bps = if (total_bps > covenant_bps) total_bps else covenant_bps;
    (balance * effective_bps) / 10000
}

public fun engine_mandate_id(e: &LiquidityEngine): ID { e.mandate_id }
public fun total_required_buffer(e: &LiquidityEngine): u64 { e.total_required_buffer }
public(package) fun cleared_assessment(c: &LiquidityCleared): &LiquidityAssessment { &c.assessment }

public(package) fun share_engine(e: LiquidityEngine) {
    transfer::share_object(e);
}

public(package) fun destroy_cleared(cleared: LiquidityCleared) {
    let LiquidityCleared { assessment: _ } = cleared;
}

public(package) fun assessment_required_buffer(a: &LiquidityAssessment): u64 { a.required_buffer }
public(package) fun assessment_post_debit_liquid(a: &LiquidityAssessment): u64 { a.post_debit_liquid }
public(package) fun assessment_forecast_multiplier_bps(a: &LiquidityAssessment): u64 { a.forecast_multiplier_bps }
public(package) fun assessment_assessed_at(a: &LiquidityAssessment): u64 { a.assessed_at }

public(package) fun standard_engine(mandate_id: ID, ctx: &mut TxContext): LiquidityEngine {
    create_engine(mandate_id, 1000, ctx)
}

/// Guardian settlement path — rebalance without alternate asset mutation.
public(package) fun rebalance_from_settlement<T>(
    engine: &mut LiquidityEngine,
    objectives: &FinancialObjectives,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<T>,
    now_ms: u64,
) {
    assert!(engine.mandate_id == vault.mandate_id(), types::evault_mismatch());

    let horizon = objectives.min_runway_days() * 86_400_000;
    let obligation_exposure = objectives::upcoming_obligation_exposure(obligations, horizon, now_ms);

    engine.obligation_buffer_bps = if (vault.balance_value() == 0) {
        0
    } else {
        (obligation_exposure * 10000) / vault.balance_value()
    };

    engine.forecast_buffer_bps = deepbook_forecast::forecast_buffer_multiplier(forecast, hook);
    if (engine.forecast_buffer_bps > 10000) {
        engine.forecast_buffer_bps = engine.forecast_buffer_bps - 10000;
    } else {
        engine.forecast_buffer_bps = 0;
    };

    engine.velocity_buffer_bps = if (vault.balance_value() == 0) {
        0
    } else {
        (engine.avg_daily_outflow * 10000) / vault.balance_value()
    };

    let covenant_bps = objectives.reserve_covenant_bps();
    engine.total_required_buffer = compute_buffer_amount(
        vault.balance_value(),
        engine.base_buffer_bps,
        engine.obligation_buffer_bps,
        engine.forecast_buffer_bps,
        engine.velocity_buffer_bps,
        covenant_bps,
    );

    engine.last_rebalance_ms = now_ms;
    engine.rebalance_count = engine.rebalance_count + 1;

    event::emit(LiquidityRebalanced {
        engine_id: object::id(engine),
        mandate_id: engine.mandate_id,
        total_required_buffer: engine.total_required_buffer,
        forecast_buffer_bps: engine.forecast_buffer_bps,
    });
}
