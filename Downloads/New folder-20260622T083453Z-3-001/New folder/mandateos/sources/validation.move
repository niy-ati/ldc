/// Constitutional validation gate — enforces FinancialConstitution rules on-chain.
module mandateos::validation;

use mandateos::constitutional::FinancialConstitution;
use mandateos::rules::{
    Self,
    SpendingPermissions,
    ExecutionConstraints,
    ReserveRequirements,
};
use mandateos::types::{Self};
use mandateos::vault::{Self, MandateVault};

/// Constitutional layer checks (Step 2 of PTB workflow).
public fun check_constitutional<T>(
    constitution: &FinancialConstitution,
    action: u8,
    amount: u64,
    recipient: address,
    executor: address,
    now_ms: u64,
    day: u64,
    vault: &MandateVault<T>,
    skip_governance: bool,
) {
    check_expiration(constitution.expiration(), now_ms);
    if (!skip_governance) {
        check_governance(constitution.governance(), executor);
    };
    check_action_allowed(constitution.execution(), action, now_ms, day);
    check_spending(constitution.spending(), amount, recipient, day);
    check_reserve(constitution.reserve(), vault, amount);
}

fun check_expiration(
    expiration: &rules::ExpirationConditions,
    now_ms: u64,
) {
    assert!(now_ms < rules::expires_at_ms(expiration), types::emandate_expired());
}

fun check_governance(
    governance: &rules::GovernanceAuthorities,
    executor: address,
) {
    assert!(rules::is_executor(governance, executor), types::enot_authorized());
}

fun check_action_allowed(
    constraints: &ExecutionConstraints,
    action: u8,
    now_ms: u64,
    day: u64,
) {
    if (types::is_guardian_action(action)) return;

    assert!(constraints.allowed_actions().contains(&action), types::eexecution_constraint_violation());

    let mut effective_executions = constraints.executions_today();
    if (constraints.last_reset_day() != day) {
        effective_executions = 0;
    };
    assert!(
        effective_executions < constraints.max_executions_per_day(),
        types::eexecution_constraint_violation(),
    );

    if (constraints.last_execution_ms() > 0) {
        assert!(
            now_ms >= constraints.last_execution_ms() + constraints.min_interval_ms(),
            types::eexecution_constraint_violation(),
        );
    };
}

fun check_spending(
    spending: &SpendingPermissions,
    amount: u64,
    recipient: address,
    day: u64,
) {
    assert!(amount <= spending.max_per_tx(), types::espending_limit_exceeded());

    let mut effective_spent = spending.daily_spent();
    if (spending.last_reset_day_spending() != day) {
        effective_spent = 0;
    };
    assert!(
        effective_spent + amount <= spending.max_daily(),
        types::espending_limit_exceeded(),
    );

    if (!spending.allow_any_recipient()) {
        assert!(spending.allowed_recipients().contains(&recipient), types::erecipient_not_allowed());
    };
}

fun check_reserve<T>(
    reserve: &ReserveRequirements,
    vault: &MandateVault<T>,
    amount: u64,
) {
    let post_balance = vault::post_debit_balance(vault, amount);
    let required = vault::reserve_amount(vault, reserve.min_reserve_bps(), reserve.reserve_floor());
    assert!(post_balance >= required, types::ereserve_violation());
}

/// Record constitutional counters after successful execution.
public fun record_constitutional_execution(
    constitution: &mut FinancialConstitution,
    amount: u64,
    now_ms: u64,
) {
    let day = now_ms / 86_400_000;
    rules::reset_daily_if_needed(constitution.spending_mut(), day);
    rules::record_spend(constitution.spending_mut(), amount);
    rules::reset_executions_if_needed(constitution.execution_mut(), day);
    rules::record_execution(constitution.execution_mut(), now_ms);
}
