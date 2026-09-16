/// Constitutional Objects — enforceable on-chain financial constitutions.
/// Separate from mandate objectives; defines HOW operations are constrained.
module mandateos::constitutional;

use sui::event;
use mandateos::rules::{
    Self,
    OwnershipRules,
    SpendingPermissions,
    ExecutionConstraints,
    ReserveRequirements,
    TreasuryObligations,
    GovernanceAuthorities,
    ExpirationConditions,
};
use mandateos::types::{Self};

/// First-class constitutional object. Amendable only through governed process.
public struct FinancialConstitution has key {
    id: UID,
    mandate_id: ID,
    version: u64,
    ownership: OwnershipRules,
    spending: SpendingPermissions,
    execution: ExecutionConstraints,
    reserve: ReserveRequirements,
    treasury: TreasuryObligations,
    governance: GovernanceAuthorities,
    expiration: ExpirationConditions,
    amendment_count: u64,
    ratified_at_ms: u64,
}

public struct ConstitutionRatified has copy, drop {
    constitution_id: ID,
    mandate_id: ID,
    version: u64,
}

public struct ConstitutionAmended has copy, drop {
    constitution_id: ID,
    mandate_id: ID,
    new_version: u64,
    amendment_count: u64,
}

public(package) fun share_constitution(c: FinancialConstitution) {
    transfer::share_object(c);
}

public(package) fun ratify(
    mandate_id: ID,
    ownership: OwnershipRules,
    spending: SpendingPermissions,
    execution: ExecutionConstraints,
    reserve: ReserveRequirements,
    treasury: TreasuryObligations,
    governance: GovernanceAuthorities,
    expiration: ExpirationConditions,
    ratified_at_ms: u64,
    ctx: &mut TxContext,
): FinancialConstitution {
    let constitution = FinancialConstitution {
        id: object::new(ctx),
        mandate_id,
        version: 1,
        ownership,
        spending,
        execution,
        reserve,
        treasury,
        governance,
        expiration,
        amendment_count: 0,
        ratified_at_ms,
    };

    event::emit(ConstitutionRatified {
        constitution_id: object::id(&constitution),
        mandate_id,
        version: 1,
    });

    constitution
}

// ── Accessors ─────────────────────────────────────────────────────────────────

public fun constitution_id(c: &FinancialConstitution): ID { object::id(c) }
public fun mandate_id(c: &FinancialConstitution): ID { c.mandate_id }
public fun version(c: &FinancialConstitution): u64 { c.version }
public fun ownership(c: &FinancialConstitution): &OwnershipRules { &c.ownership }
public fun spending(c: &FinancialConstitution): &SpendingPermissions { &c.spending }
public fun spending_mut(c: &mut FinancialConstitution): &mut SpendingPermissions { &mut c.spending }
public fun execution(c: &FinancialConstitution): &ExecutionConstraints { &c.execution }
public fun execution_mut(c: &mut FinancialConstitution): &mut ExecutionConstraints { &mut c.execution }
public fun reserve(c: &FinancialConstitution): &ReserveRequirements { &c.reserve }
public fun treasury(c: &FinancialConstitution): &TreasuryObligations { &c.treasury }
public fun governance(c: &FinancialConstitution): &GovernanceAuthorities { &c.governance }
public fun expiration(c: &FinancialConstitution): &ExpirationConditions { &c.expiration }
public fun expiration_mut(c: &mut FinancialConstitution): &mut ExpirationConditions { &mut c.expiration }

// ── Governed amendment ────────────────────────────────────────────────────────

public fun amend_spending_limits(
    constitution: &mut FinancialConstitution,
    max_per_tx: u64,
    max_daily: u64,
    ctx: &TxContext,
) {
    assert!(rules::is_governor(constitution.governance(), ctx.sender()), types::enot_authorized());
    rules::set_spending_limits(constitution.spending_mut(), max_per_tx, max_daily);
    bump_version(constitution);
}

public fun amend_execution_constraints(
    constitution: &mut FinancialConstitution,
    constraints: ExecutionConstraints,
    ctx: &TxContext,
) {
    assert!(rules::is_governor(constitution.governance(), ctx.sender()), types::enot_authorized());
    rules::apply_execution_constraints(constitution.execution_mut(), &constraints);
    bump_version(constitution);
}

public fun renew_constitution(
    constitution: &mut FinancialConstitution,
    ctx: &TxContext,
) {
    assert!(rules::is_governor(constitution.governance(), ctx.sender()), types::enot_authorized());
    rules::renew(&mut constitution.expiration);
    bump_version(constitution);
}

public fun add_constitutional_authority(
    constitution: &mut FinancialConstitution,
    authority: address,
    role: u8,
    ctx: &TxContext,
) {
    assert!(rules::is_governor(constitution.governance(), ctx.sender()), types::enot_authorized());
    rules::add_authority(&mut constitution.governance, authority, role);
    bump_version(constitution);
}

fun bump_version(constitution: &mut FinancialConstitution) {
    constitution.version = constitution.version + 1;
    constitution.amendment_count = constitution.amendment_count + 1;
    event::emit(ConstitutionAmended {
        constitution_id: object::id(constitution),
        mandate_id: constitution.mandate_id,
        new_version: constitution.version,
        amendment_count: constitution.amendment_count,
    });
}
