/// Central authority validation against FinancialConstitution governance.
module mandateos::authority;

use std::option::{Self, Option};
use mandateos::constitutional::FinancialConstitution;
use mandateos::rules;
use mandateos::types;

public fun assert_governor(constitution: &FinancialConstitution, sender: address) {
    assert!(rules::is_governor(constitution.governance(), sender), types::enot_authorized());
}

public fun assert_executor(constitution: &FinancialConstitution, sender: address) {
    assert!(rules::is_executor(constitution.governance(), sender), types::enot_authorized());
}

/// Constitutional executor when no agent cap is presented.
public fun assert_executor_or_cap(
    constitution: &FinancialConstitution,
    sender: address,
    cap: &Option<mandateos::delegation::ExecutorCap>,
) {
    if (option::is_none(cap)) {
        assert_executor(constitution, sender);
    };
}

public fun assert_agent_executor(
    cap: &mandateos::delegation::ExecutorCap,
    tracker: &mut mandateos::delegation::DailyExecutionTracker,
    mandate_id: ID,
    action: u8,
    amount: u64,
    day: u64,
    now_ms: u64,
    sender: address,
) {
    mandateos::delegation::assert_executor_cap(
        cap,
        tracker,
        mandate_id,
        action,
        amount,
        day,
        now_ms,
        sender,
    );
}

public fun assert_auditor(constitution: &FinancialConstitution, sender: address) {
    assert!(
        rules::has_role(constitution.governance(), sender, types::role_auditor()),
        types::enot_authorized(),
    );
}

public fun assert_owner(constitution: &FinancialConstitution, sender: address) {
    assert!(rules::is_owner(constitution.ownership(), sender), types::enot_authorized());
}

public fun assert_governor_or_executor(constitution: &FinancialConstitution, sender: address) {
    let gov = constitution.governance();
    assert!(
        rules::is_governor(gov, sender) || rules::is_executor(gov, sender),
        types::enot_authorized(),
    );
}
