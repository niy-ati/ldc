/// Financial objectives and obligations — what a mandate must achieve and honor.
module mandateos::objectives;

use sui::event;
use mandateos::authority;
use mandateos::constitutional::FinancialConstitution;
use mandateos::types::{Self};

// ── Objective kinds ───────────────────────────────────────────────────────────

const OBJECTIVE_GROWTH: u8 = 1;
const OBJECTIVE_PRESERVATION: u8 = 2;
const OBJECTIVE_DISTRIBUTION: u8 = 3;
const OBJECTIVE_RUNWAY: u8 = 4;

// ── Obligation kinds ──────────────────────────────────────────────────────────

const OBLIGATION_PAYMENT: u8 = 1;
const OBLIGATION_RESERVE_COVENANT: u8 = 2;
const OBLIGATION_CONTRIBUTION: u8 = 3;
const OBLIGATION_REPORTING: u8 = 4;
const OBLIGATION_LIQUIDITY_COVENANT: u8 = 5;

const OBLIGATION_PENDING: u8 = 0;
const OBLIGATION_PARTIAL: u8 = 1;
const OBLIGATION_FULFILLED: u8 = 2;
const OBLIGATION_OVERDUE: u8 = 3;

// ── Financial objectives (mandate purpose, not limits) ────────────────────────

/// Declarative financial goals the mandate is chartered to pursue.
public struct FinancialObjectives has store {
    primary_objective: u8,
    target_balance: u64,
    min_runway_days: u64,
    growth_target_bps: u64,
    distribution_target_bps: u64,
    reserve_covenant_bps: u64,
    purpose_hash: vector<u8>,
}

public fun financial_objectives(
    primary_objective: u8,
    target_balance: u64,
    min_runway_days: u64,
    growth_target_bps: u64,
    distribution_target_bps: u64,
    reserve_covenant_bps: u64,
    purpose_hash: vector<u8>,
): FinancialObjectives {
    FinancialObjectives {
        primary_objective,
        target_balance,
        min_runway_days,
        growth_target_bps,
        distribution_target_bps,
        reserve_covenant_bps,
        purpose_hash,
    }
}

public fun primary_objective(o: &FinancialObjectives): u8 { o.primary_objective }
public fun target_balance(o: &FinancialObjectives): u64 { o.target_balance }
public fun min_runway_days(o: &FinancialObjectives): u64 { o.min_runway_days }
public fun growth_target_bps(o: &FinancialObjectives): u64 { o.growth_target_bps }
public fun distribution_target_bps(o: &FinancialObjectives): u64 { o.distribution_target_bps }
public fun reserve_covenant_bps(o: &FinancialObjectives): u64 { o.reserve_covenant_bps }

public fun preservation_objectives(
    target_balance: u64,
    min_runway_days: u64,
    reserve_covenant_bps: u64,
): FinancialObjectives {
    financial_objectives(
        OBJECTIVE_PRESERVATION,
        target_balance,
        min_runway_days,
        0,
        0,
        reserve_covenant_bps,
        vector[],
    )
}

public fun distribution_objectives(
    target_balance: u64,
    distribution_target_bps: u64,
    min_runway_days: u64,
): FinancialObjectives {
    financial_objectives(
        OBJECTIVE_DISTRIBUTION,
        target_balance,
        min_runway_days,
        0,
        distribution_target_bps,
        500,
        vector[],
    )
}

public fun growth_objectives(
    target_balance: u64,
    growth_target_bps: u64,
    min_runway_days: u64,
): FinancialObjectives {
    financial_objectives(
        OBJECTIVE_GROWTH,
        target_balance,
        min_runway_days,
        growth_target_bps,
        0,
        1000,
        vector[],
    )
}

// ── Financial obligations (mandate duties, not spending caps) ────────────────

public struct FinancialObligation has store, copy, drop {
    obligation_id: u64,
    obligation_type: u8,
    counterparty: address,
    principal: u64,
    fulfilled: u64,
    due_at_ms: u64,
    recurrence_ms: u64,
    priority: u8,
    status: u8,
}

public fun financial_obligation(
    obligation_id: u64,
    obligation_type: u8,
    counterparty: address,
    principal: u64,
    due_at_ms: u64,
    recurrence_ms: u64,
    priority: u8,
): FinancialObligation {
    FinancialObligation {
        obligation_id,
        obligation_type,
        counterparty,
        principal,
        fulfilled: 0,
        due_at_ms,
        recurrence_ms,
        priority,
        status: OBLIGATION_PENDING,
    }
}

public fun obligation_id(o: &FinancialObligation): u64 { o.obligation_id }
public fun obligation_type(o: &FinancialObligation): u8 { o.obligation_type }
public fun counterparty(o: &FinancialObligation): address { o.counterparty }
public fun principal(o: &FinancialObligation): u64 { o.principal }
public fun fulfilled(o: &FinancialObligation): u64 { o.fulfilled }
public fun due_at_ms(o: &FinancialObligation): u64 { o.due_at_ms }
public fun obligation_status(o: &FinancialObligation): u8 { o.status }
public fun remaining(o: &FinancialObligation): u64 {
    if (o.principal <= o.fulfilled) 0 else o.principal - o.fulfilled
}

public(package) fun record_fulfillment(o: &mut FinancialObligation, amount: u64) {
    o.fulfilled = o.fulfilled + amount;
    if (o.fulfilled >= o.principal) {
        o.status = OBLIGATION_FULFILLED;
    } else {
        o.status = OBLIGATION_PARTIAL;
    };
}

public(package) fun mark_overdue(o: &mut FinancialObligation) {
    if (o.status != OBLIGATION_FULFILLED) {
        o.status = OBLIGATION_OVERDUE;
    };
}

// ── Obligation registry (shared object) ───────────────────────────────────────

public struct ObligationRegistry has key {
    id: UID,
    mandate_id: ID,
    obligations: vector<FinancialObligation>,
    next_obligation_id: u64,
    total_principal: u64,
    total_fulfilled: u64,
}

public struct ObligationRegistered has copy, drop {
    registry_id: ID,
    mandate_id: ID,
    obligation_id: u64,
    obligation_type: u8,
    principal: u64,
}

public struct ObligationFulfilled has copy, drop {
    registry_id: ID,
    obligation_id: u64,
    amount: u64,
    remaining: u64,
}

public(package) fun share_registry(r: ObligationRegistry) {
    transfer::share_object(r);
}

public(package) fun create_registry(
    mandate_id: ID,
    initial: vector<FinancialObligation>,
    ctx: &mut TxContext,
): ObligationRegistry {
    let mut total_principal = 0u64;
    let mut i = 0;
    while (i < initial.length()) {
        total_principal = total_principal + initial[i].principal;
        i = i + 1;
    };
    ObligationRegistry {
        id: object::new(ctx),
        mandate_id,
        obligations: initial,
        next_obligation_id: (initial.length() as u64) + 1,
        total_principal,
        total_fulfilled: 0,
    }
}

public fun registry_mandate_id(r: &ObligationRegistry): ID { r.mandate_id }
public fun obligations(r: &ObligationRegistry): &vector<FinancialObligation> { &r.obligations }
public fun total_principal(r: &ObligationRegistry): u64 { r.total_principal }
public fun total_fulfilled(r: &ObligationRegistry): u64 { r.total_fulfilled }

public fun has_overdue(registry: &ObligationRegistry, now_ms: u64): bool {
    let mut i = 0;
    while (i < registry.obligations.length()) {
        let o = &registry.obligations[i];
        if (o.status == OBLIGATION_OVERDUE) return true;
        if (o.status != OBLIGATION_FULFILLED && o.due_at_ms < now_ms && o.fulfilled < o.principal) {
            return true
        };
        i = i + 1;
    };
    false
}

/// Sum of unfulfilled obligation principal due within horizon.
public fun upcoming_obligation_exposure(r: &ObligationRegistry, horizon_ms: u64, now_ms: u64): u64 {
    let mut exposure = 0u64;
    let mut i = 0;
    while (i < r.obligations.length()) {
        let o = &r.obligations[i];
        if (o.status != OBLIGATION_FULFILLED && o.due_at_ms <= now_ms + horizon_ms) {
            exposure = exposure + remaining(o);
        };
        i = i + 1;
    };
    exposure
}

public fun register_obligation(
    registry: &mut ObligationRegistry,
    constitution: &FinancialConstitution,
    obligation_type: u8,
    counterparty: address,
    principal: u64,
    due_at_ms: u64,
    recurrence_ms: u64,
    priority: u8,
    ctx: &TxContext,
): u64 {
    assert!(registry.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());
    let id = registry.next_obligation_id;
    registry.obligations.push_back(financial_obligation(
        id,
        obligation_type,
        counterparty,
        principal,
        due_at_ms,
        recurrence_ms,
        priority,
    ));
    registry.next_obligation_id = registry.next_obligation_id + 1;
    registry.total_principal = registry.total_principal + principal;

    event::emit(ObligationRegistered {
        registry_id: object::id(registry),
        mandate_id: registry.mandate_id,
        obligation_id: id,
        obligation_type,
        principal,
    });
    id
}

public(package) fun fulfill_obligation(
    registry: &mut ObligationRegistry,
    obligation_id: u64,
    amount: u64,
): u64 {
    let idx = find_obligation(registry, obligation_id);
    record_fulfillment(&mut registry.obligations[idx], amount);
    registry.total_fulfilled = registry.total_fulfilled + amount;
    let rem = remaining(&registry.obligations[idx]);

    event::emit(ObligationFulfilled {
        registry_id: object::id(registry),
        obligation_id,
        amount,
        remaining: rem,
    });
    rem
}

public fun scan_overdue(
    registry: &mut ObligationRegistry,
    constitution: &FinancialConstitution,
    now_ms: u64,
    ctx: &TxContext,
) {
    assert!(registry.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor_or_executor(constitution, ctx.sender());
    let mut i = 0;
    while (i < registry.obligations.length()) {
        let o = &mut registry.obligations[i];
        if (o.status != OBLIGATION_FULFILLED && now_ms > o.due_at_ms) {
            mark_overdue(o);
        };
        i = i + 1;
    };
}

fun find_obligation(registry: &ObligationRegistry, obligation_id: u64): u64 {
    let mut i = 0;
    while (i < registry.obligations.length()) {
        if (registry.obligations[i].obligation_id == obligation_id) return i;
        i = i + 1;
    };
    abort types::eobligation_not_found()
}

// ── Public accessors ──────────────────────────────────────────────────────────

public fun objective_growth(): u8 { OBJECTIVE_GROWTH }
public fun objective_preservation(): u8 { OBJECTIVE_PRESERVATION }
public fun objective_distribution(): u8 { OBJECTIVE_DISTRIBUTION }
public fun objective_runway(): u8 { OBJECTIVE_RUNWAY }
public fun obligation_payment(): u8 { OBLIGATION_PAYMENT }
public fun obligation_reserve_covenant(): u8 { OBLIGATION_RESERVE_COVENANT }
public fun obligation_contribution(): u8 { OBLIGATION_CONTRIBUTION }
public fun obligation_reporting(): u8 { OBLIGATION_REPORTING }
public fun obligation_liquidity_covenant(): u8 { OBLIGATION_LIQUIDITY_COVENANT }
public fun obligation_pending(): u8 { OBLIGATION_PENDING }
public fun obligation_partial(): u8 { OBLIGATION_PARTIAL }
public fun obligation_fulfilled(): u8 { OBLIGATION_FULFILLED }
public fun obligation_overdue(): u8 { OBLIGATION_OVERDUE }
