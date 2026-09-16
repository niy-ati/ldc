/// DeepBook Forecast Hooks — market liquidity signals feeding the OS liquidity engine.
module mandateos::deepbook_forecast;

use sui::event;
use mandateos::authority;
use mandateos::constitutional::FinancialConstitution;
use mandateos::types::{Self};

const POOL_SUI_USDC: u8 = 1;
const POOL_SUI_USDT: u8 = 2;
const POOL_CUSTOM: u8 = 99;

/// Non-transferable capability required to submit forecast updates.
public struct OracleCap has key, store {
    id: UID,
    mandate_id: ID,
    forecast_id: ID,
}

public struct MarketForecast has key {
    id: UID,
    mandate_id: ID,
    pool_id: u8,
    mid_price: u64,
    spread_bps: u64,
    depth_at_1pct_bps: u64,
    volatility_bps: u64,
    slippage_estimate_bps: u64,
    forecast_horizon_ms: u64,
    updated_at_ms: u64,
    stale_after_ms: u64,
}

public struct ForecastUpdated has copy, drop {
    forecast_id: ID,
    mandate_id: ID,
    pool_id: u8,
    volatility_bps: u64,
    slippage_estimate_bps: u64,
}

public struct DeepBookHook has key {
    id: UID,
    mandate_id: ID,
    forecast_id: ID,
    enabled: bool,
    min_depth_bps: u64,
    max_slippage_bps: u64,
    max_volatility_bps: u64,
}

public(package) fun create_forecast(
    mandate_id: ID,
    pool_id: u8,
    stale_after_ms: u64,
    updated_at_ms: u64,
    ctx: &mut TxContext,
): (MarketForecast, OracleCap) {
    let forecast = MarketForecast {
        id: object::new(ctx),
        mandate_id,
        pool_id,
        mid_price: 0,
        spread_bps: 0,
        depth_at_1pct_bps: 10000,
        volatility_bps: 0,
        slippage_estimate_bps: 0,
        forecast_horizon_ms: 86_400_000,
        updated_at_ms,
        stale_after_ms,
    };
    let cap = OracleCap {
        id: object::new(ctx),
        mandate_id,
        forecast_id: object::id(&forecast),
    };
    (forecast, cap)
}

public(package) fun create_hook(
    mandate_id: ID,
    forecast_id: ID,
    min_depth_bps: u64,
    max_slippage_bps: u64,
    max_volatility_bps: u64,
    ctx: &mut TxContext,
): DeepBookHook {
    DeepBookHook {
        id: object::new(ctx),
        mandate_id,
        forecast_id,
        enabled: true,
        min_depth_bps,
        max_slippage_bps,
        max_volatility_bps,
    }
}

public fun submit_forecast(
    forecast: &mut MarketForecast,
    hook: &DeepBookHook,
    cap: &OracleCap,
    mid_price: u64,
    spread_bps: u64,
    depth_at_1pct_bps: u64,
    volatility_bps: u64,
    slippage_estimate_bps: u64,
    now_ms: u64,
) {
    assert!(cap.forecast_id == object::id(forecast), types::eoracle_cap_mismatch());
    assert!(cap.mandate_id == forecast.mandate_id, types::eoracle_cap_mismatch());
    assert!(hook.enabled, types::eforecast_hook_disabled());
    assert!(forecast.mandate_id == hook.mandate_id, types::evault_mismatch());

    forecast.mid_price = mid_price;
    forecast.spread_bps = spread_bps;
    forecast.depth_at_1pct_bps = depth_at_1pct_bps;
    forecast.volatility_bps = volatility_bps;
    forecast.slippage_estimate_bps = slippage_estimate_bps;
    forecast.updated_at_ms = now_ms;

    event::emit(ForecastUpdated {
        forecast_id: object::id(forecast),
        mandate_id: forecast.mandate_id,
        pool_id: forecast.pool_id,
        volatility_bps,
        slippage_estimate_bps,
    });
}

public fun configure_hook(
    hook: &mut DeepBookHook,
    constitution: &FinancialConstitution,
    enabled: bool,
    min_depth_bps: u64,
    max_slippage_bps: u64,
    max_volatility_bps: u64,
    ctx: &TxContext,
) {
    assert!(hook.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());
    hook.enabled = enabled;
    hook.min_depth_bps = min_depth_bps;
    hook.max_slippage_bps = max_slippage_bps;
    hook.max_volatility_bps = max_volatility_bps;
}

public(package) fun pre_execution_hook(
    hook: &DeepBookHook,
    forecast: &MarketForecast,
    outflow_amount: u64,
    vault_balance: u64,
    now_ms: u64,
): u64 {
    if (!hook.enabled) return 0;
    assert!(!is_stale(forecast, now_ms), types::eforecast_stale());
    assert!(forecast.depth_at_1pct_bps >= hook.min_depth_bps, types::einsufficient_market_depth());
    assert!(forecast.slippage_estimate_bps <= hook.max_slippage_bps, types::eslippage_exceeded());
    assert!(forecast.volatility_bps <= hook.max_volatility_bps, types::evolatility_exceeded());

    if (vault_balance == 0) return 0;
    liquidity_impact_bps(outflow_amount, vault_balance, forecast)
}

public fun forecast_buffer_multiplier(forecast: &MarketForecast, hook: &DeepBookHook): u64 {
    if (!hook.enabled) return 10000;
    let vol_factor = 10000 + forecast.volatility_bps;
    let slip_factor = 10000 + forecast.slippage_estimate_bps;
    (vol_factor + slip_factor) / 2
}

public fun is_stale(forecast: &MarketForecast, now_ms: u64): bool {
    now_ms > forecast.updated_at_ms + forecast.stale_after_ms
}

fun liquidity_impact_bps(
    outflow_amount: u64,
    vault_balance: u64,
    forecast: &MarketForecast,
): u64 {
    let outflow_bps = (outflow_amount * 10000) / vault_balance;
    outflow_bps + forecast.slippage_estimate_bps + (forecast.volatility_bps / 2)
}

public fun forecast_mandate_id(f: &MarketForecast): ID { f.mandate_id }
public fun volatility_bps(f: &MarketForecast): u64 { f.volatility_bps }
public fun hook_mandate_id(h: &DeepBookHook): ID { h.mandate_id }
public fun hook_enabled(h: &DeepBookHook): bool { h.enabled }
public fun oracle_cap_forecast_id(c: &OracleCap): ID { c.forecast_id }

public(package) fun share_forecast(forecast: MarketForecast) {
    transfer::share_object(forecast);
}

public(package) fun share_hook(hook: DeepBookHook) {
    transfer::share_object(hook);
}

public(package) fun transfer_oracle_cap(cap: OracleCap, owner: address) {
    transfer::transfer(cap, owner);
}

public(package) fun neutral_forecast(
    mandate_id: ID,
    now_ms: u64,
    ctx: &mut TxContext,
): (MarketForecast, OracleCap) {
    create_forecast(mandate_id, POOL_CUSTOM, 7_200_000, now_ms, ctx)
}

public(package) fun neutral_hook(
    mandate_id: ID,
    forecast_id: ID,
    ctx: &mut TxContext,
): DeepBookHook {
    create_hook(mandate_id, forecast_id, 0, 10000, 10000, ctx)
}
