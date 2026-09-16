/// Constitutional rule structs embedded in every Financial Mandate Object.
module mandateos::rules;

use sui::vec_map::{Self, VecMap};

// ── Ownership ───────────────────────────────────────────────────────────────

public struct OwnershipRules has store {
    primary_owner: address,
    co_owners: vector<address>,
    transfer_requires_consensus: bool,
}

public fun ownership_rules(
    primary_owner: address,
    co_owners: vector<address>,
    transfer_requires_consensus: bool,
): OwnershipRules {
    OwnershipRules { primary_owner, co_owners, transfer_requires_consensus }
}

public fun primary_owner(rules: &OwnershipRules): address { rules.primary_owner }
public fun co_owners(rules: &OwnershipRules): &vector<address> { &rules.co_owners }
public fun transfer_requires_consensus(rules: &OwnershipRules): bool {
    rules.transfer_requires_consensus
}

public fun is_owner(rules: &OwnershipRules, addr: address): bool {
    if (rules.primary_owner == addr) return true;
    rules.co_owners.contains(&addr)
}

// ── Spending permissions ──────────────────────────────────────────────────

public struct SpendingPermissions has store, drop {
    max_per_tx: u64,
    max_daily: u64,
    daily_spent: u64,
    last_reset_day: u64,
    allowed_recipients: vector<address>,
    allow_any_recipient: bool,
}

public fun set_spending_limits(
    spending: &mut SpendingPermissions,
    max_per_tx: u64,
    max_daily: u64,
) {
    spending.max_per_tx = max_per_tx;
    spending.max_daily = max_daily;
}

public fun apply_execution_constraints(
    execution: &mut ExecutionConstraints,
    constraints: &ExecutionConstraints,
) {
    execution.min_interval_ms = constraints.min_interval_ms;
    execution.max_executions_per_day = constraints.max_executions_per_day;
    execution.allowed_actions = constraints.allowed_actions;
}

public fun spending_permissions(
    max_per_tx: u64,
    max_daily: u64,
    allowed_recipients: vector<address>,
    allow_any_recipient: bool,
): SpendingPermissions {
    SpendingPermissions {
        max_per_tx,
        max_daily,
        daily_spent: 0,
        last_reset_day: 0,
        allowed_recipients,
        allow_any_recipient,
    }
}

public fun max_per_tx(p: &SpendingPermissions): u64 { p.max_per_tx }
public fun max_daily(p: &SpendingPermissions): u64 { p.max_daily }
public fun daily_spent(p: &SpendingPermissions): u64 { p.daily_spent }
public fun last_reset_day_spending(p: &SpendingPermissions): u64 { p.last_reset_day }
public fun allowed_recipients(p: &SpendingPermissions): &vector<address> {
    &p.allowed_recipients
}
public fun allow_any_recipient(p: &SpendingPermissions): bool { p.allow_any_recipient }

public(package) fun reset_daily_if_needed(p: &mut SpendingPermissions, day: u64) {
    if (p.last_reset_day != day) {
        p.daily_spent = 0;
        p.last_reset_day = day;
    }
}

public(package) fun record_spend(p: &mut SpendingPermissions, amount: u64) {
    p.daily_spent = p.daily_spent + amount;
}

// ── Execution constraints ───────────────────────────────────────────────────

public struct ExecutionConstraints has store, drop {
    min_interval_ms: u64,
    max_executions_per_day: u64,
    executions_today: u64,
    last_execution_ms: u64,
    last_reset_day: u64,
    allowed_actions: vector<u8>,
}

public fun execution_constraints(
    min_interval_ms: u64,
    max_executions_per_day: u64,
    allowed_actions: vector<u8>,
): ExecutionConstraints {
    ExecutionConstraints {
        min_interval_ms,
        max_executions_per_day,
        executions_today: 0,
        last_execution_ms: 0,
        last_reset_day: 0,
        allowed_actions,
    }
}

public fun min_interval_ms(c: &ExecutionConstraints): u64 { c.min_interval_ms }
public fun max_executions_per_day(c: &ExecutionConstraints): u64 { c.max_executions_per_day }
public fun executions_today(c: &ExecutionConstraints): u64 { c.executions_today }
public fun last_execution_ms(c: &ExecutionConstraints): u64 { c.last_execution_ms }
public fun last_reset_day(c: &ExecutionConstraints): u64 { c.last_reset_day }
public fun allowed_actions(c: &ExecutionConstraints): &vector<u8> { &c.allowed_actions }

public(package) fun reset_executions_if_needed(c: &mut ExecutionConstraints, day: u64) {
    if (c.last_reset_day != day) {
        c.executions_today = 0;
        c.last_reset_day = day;
    }
}

public(package) fun record_execution(c: &mut ExecutionConstraints, now_ms: u64) {
    c.last_execution_ms = now_ms;
    c.executions_today = c.executions_today + 1;
}

// ── Liquidity requirements ──────────────────────────────────────────────────

public struct LiquidityRequirements has store {
    min_liquid_balance: u64,
    max_illiquid_ratio_bps: u64, // basis points (10000 = 100%)
}

public fun liquidity_requirements(
    min_liquid_balance: u64,
    max_illiquid_ratio_bps: u64,
): LiquidityRequirements {
    LiquidityRequirements { min_liquid_balance, max_illiquid_ratio_bps }
}

public fun min_liquid_balance(r: &LiquidityRequirements): u64 { r.min_liquid_balance }
public fun max_illiquid_ratio_bps(r: &LiquidityRequirements): u64 { r.max_illiquid_ratio_bps }

// ── Reserve requirements ────────────────────────────────────────────────────

public struct ReserveRequirements has store {
    min_reserve_bps: u64,
    reserve_floor: u64,
}

public fun reserve_requirements(min_reserve_bps: u64, reserve_floor: u64): ReserveRequirements {
    ReserveRequirements { min_reserve_bps, reserve_floor }
}

public fun min_reserve_bps(r: &ReserveRequirements): u64 { r.min_reserve_bps }
public fun reserve_floor(r: &ReserveRequirements): u64 { r.reserve_floor }

// ── Treasury obligations ────────────────────────────────────────────────────

public struct TreasuryObligations has store {
    required_contribution_bps: u64,
    contribution_recipient: address,
    last_contribution_ms: u64,
    contribution_interval_ms: u64,
}

public fun treasury_obligations(
    required_contribution_bps: u64,
    contribution_recipient: address,
    contribution_interval_ms: u64,
): TreasuryObligations {
    TreasuryObligations {
        required_contribution_bps,
        contribution_recipient,
        last_contribution_ms: 0,
        contribution_interval_ms,
    }
}

public fun required_contribution_bps(o: &TreasuryObligations): u64 { o.required_contribution_bps }
public fun contribution_recipient(o: &TreasuryObligations): address { o.contribution_recipient }
public fun contribution_interval_ms(o: &TreasuryObligations): u64 { o.contribution_interval_ms }

public(package) fun record_contribution(o: &mut TreasuryObligations, now_ms: u64) {
    o.last_contribution_ms = now_ms;
}

// ── Governance authorities ────────────────────────────────────────────────────

public struct GovernanceAuthorities has store {
    authorities: VecMap<address, u8>,
    quorum: u64,
}

public fun governance_authorities(
    authorities: VecMap<address, u8>,
    quorum: u64,
): GovernanceAuthorities {
    GovernanceAuthorities { authorities, quorum }
}

public fun quorum(g: &GovernanceAuthorities): u64 { g.quorum }
public fun authorities(g: &GovernanceAuthorities): &VecMap<address, u8> { &g.authorities }

public fun has_role(g: &GovernanceAuthorities, addr: address, role: u8): bool {
    if (!g.authorities.contains(&addr)) return false;
    *g.authorities.get(&addr) == role
}

public fun is_governor(g: &GovernanceAuthorities, addr: address): bool {
    has_role(g, addr, mandateos::types::role_governor())
}

public fun is_executor(g: &GovernanceAuthorities, addr: address): bool {
    has_role(g, addr, mandateos::types::role_executor())
        || has_role(g, addr, mandateos::types::role_governor())
}

public(package) fun add_authority(
    g: &mut GovernanceAuthorities,
    authority: address,
    role: u8,
) {
    g.authorities.insert(authority, role);
}


// ── Expiration conditions ───────────────────────────────────────────────────

public struct ExpirationConditions has store {
    expires_at_ms: u64,
    auto_renew: bool,
    renewal_period_ms: u64,
}

public fun expiration_conditions(
    expires_at_ms: u64,
    auto_renew: bool,
    renewal_period_ms: u64,
): ExpirationConditions {
    ExpirationConditions { expires_at_ms, auto_renew, renewal_period_ms }
}

public fun expires_at_ms(e: &ExpirationConditions): u64 { e.expires_at_ms }
public fun auto_renew(e: &ExpirationConditions): bool { e.auto_renew }
public fun renewal_period_ms(e: &ExpirationConditions): u64 { e.renewal_period_ms }

public(package) fun renew(e: &mut ExpirationConditions) {
    e.expires_at_ms = e.expires_at_ms + e.renewal_period_ms;
}
