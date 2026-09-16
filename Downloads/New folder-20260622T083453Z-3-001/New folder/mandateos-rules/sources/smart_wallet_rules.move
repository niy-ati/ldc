/// On-chain smart wallet automation rules — auditable, editable, proof-linked execution markers.
module mandateos::smart_wallet_rules;

use sui::clock::Clock;
use sui::event;

// ── Rule types ────────────────────────────────────────────────────────────────

const RULE_BALANCE_INVEST: u8 = 1;
const RULE_PAYROLL_DATE: u8 = 2;
const RULE_RISK_WITHDRAW: u8 = 3;

public struct SmartWalletRule has key, store {
    id: UID,
    owner: address,
    rule_type: u8,
    threshold_mist: u64,
    percent_bps: u64,
    payroll_due_ms: u64,
    enabled: bool,
    created_ms: u64,
    updated_ms: u64,
    label: vector<u8>,
    last_proof_digest: vector<u8>,
}

public struct RuleCreated has copy, drop {
    rule_id: ID,
    owner: address,
    rule_type: u8,
    threshold_mist: u64,
    percent_bps: u64,
}

public struct RuleUpdated has copy, drop {
    rule_id: ID,
    enabled: bool,
    threshold_mist: u64,
    percent_bps: u64,
}

public struct RuleExecuted has copy, drop {
    rule_id: ID,
    owner: address,
    rule_type: u8,
    proof_digest: vector<u8>,
    executed_ms: u64,
}

public fun rule_balance_invest(): u8 { RULE_BALANCE_INVEST }
public fun rule_payroll_date(): u8 { RULE_PAYROLL_DATE }
public fun rule_risk_withdraw(): u8 { RULE_RISK_WITHDRAW }

public fun create_balance_invest_rule(
    threshold_mist: u64,
    invest_percent_bps: u64,
    label: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): SmartWalletRule {
    assert!(invest_percent_bps <= 10_000, 1);
    let now = clock.timestamp_ms();
    SmartWalletRule {
        id: object::new(ctx),
        owner: ctx.sender(),
        rule_type: RULE_BALANCE_INVEST,
        threshold_mist,
        percent_bps: invest_percent_bps,
        payroll_due_ms: 0,
        enabled: true,
        created_ms: now,
        updated_ms: now,
        label,
        last_proof_digest: vector[],
    }
}

public fun create_payroll_date_rule(
    payroll_due_ms: u64,
    label: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): SmartWalletRule {
    let now = clock.timestamp_ms();
    SmartWalletRule {
        id: object::new(ctx),
        owner: ctx.sender(),
        rule_type: RULE_PAYROLL_DATE,
        threshold_mist: 0,
        percent_bps: 0,
        payroll_due_ms,
        enabled: true,
        created_ms: now,
        updated_ms: now,
        label,
        last_proof_digest: vector[],
    }
}

public fun create_risk_withdraw_rule(
    risk_threshold_bps: u64,
    withdraw_percent_bps: u64,
    label: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): SmartWalletRule {
    assert!(risk_threshold_bps <= 10_000, 2);
    assert!(withdraw_percent_bps <= 10_000, 3);
    let now = clock.timestamp_ms();
    SmartWalletRule {
        id: object::new(ctx),
        owner: ctx.sender(),
        rule_type: RULE_RISK_WITHDRAW,
        threshold_mist: risk_threshold_bps,
        percent_bps: withdraw_percent_bps,
        payroll_due_ms: 0,
        enabled: true,
        created_ms: now,
        updated_ms: now,
        label,
        last_proof_digest: vector[],
    }
}

public fun share_rule(rule: SmartWalletRule, clock: &Clock) {
    event::emit(RuleCreated {
        rule_id: object::id(&rule),
        owner: rule.owner,
        rule_type: rule.rule_type,
        threshold_mist: rule.threshold_mist,
        percent_bps: rule.percent_bps,
    });
    let _ = clock.timestamp_ms();
    transfer::share_object(rule);
}

public fun update_rule(
    rule: &mut SmartWalletRule,
    enabled: bool,
    threshold_mist: u64,
    percent_bps: u64,
    payroll_due_ms: u64,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert!(rule.owner == ctx.sender(), 4);
    rule.enabled = enabled;
    rule.threshold_mist = threshold_mist;
    rule.percent_bps = percent_bps;
    rule.payroll_due_ms = payroll_due_ms;
    rule.updated_ms = clock.timestamp_ms();
    event::emit(RuleUpdated {
        rule_id: object::id(rule),
        enabled,
        threshold_mist,
        percent_bps,
    });
}

/// Record rule execution with linked transaction digest bytes (proof-backed audit trail).
public fun execute_rule(
    rule: &mut SmartWalletRule,
    proof_digest: vector<u8>,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert!(rule.owner == ctx.sender(), 5);
    assert!(rule.enabled, 6);
    assert!(vector::length(&proof_digest) > 0, 7);
    rule.last_proof_digest = proof_digest;
    rule.updated_ms = clock.timestamp_ms();
    event::emit(RuleExecuted {
        rule_id: object::id(rule),
        owner: rule.owner,
        rule_type: rule.rule_type,
        proof_digest,
        executed_ms: clock.timestamp_ms(),
    });
}

public fun owner(rule: &SmartWalletRule): address { rule.owner }
public fun rule_type(rule: &SmartWalletRule): u8 { rule.rule_type }
public fun enabled(rule: &SmartWalletRule): bool { rule.enabled }
public fun threshold_mist(rule: &SmartWalletRule): u64 { rule.threshold_mist }
public fun percent_bps(rule: &SmartWalletRule): u64 { rule.percent_bps }
public fun payroll_due_ms(rule: &SmartWalletRule): u64 { rule.payroll_due_ms }
public fun last_proof_digest(rule: &SmartWalletRule): &vector<u8> { &rule.last_proof_digest }
