/// Agent Delegation — scoped capabilities for autonomous agents (never fund custody).
module mandateos::delegation;

use std::option::{Self, Option};
use sui::event;
use mandateos::constitutional::FinancialConstitution;
use mandateos::rules;
use mandateos::types::{Self};

/// Scoped authority parameters embedded in every delegation cap.
public struct AgentAuthority has store, copy, drop {
    mandate_id: ID,
    agent: address,
    expires_at_ms: u64,
    max_per_tx: u64,
    max_daily: u64,
    allowed_actions: vector<u8>,
    protocol_mask: u64,
}

/// Per-agent daily execution ledger — enforced at settlement.
public struct DailyExecutionTracker has key, store {
    id: UID,
    agent: address,
    mandate_id: ID,
    current_day: u64,
    total_executed_today: u64,
}

public struct DelegationIssued has copy, drop {
    mandate_id: ID,
    agent: address,
    cap_type: u8,
    expires_at_ms: u64,
}

/// Parent capability — governor issues scoped executor/auditor caps to agents.
public struct DelegationCap has key, store {
    id: UID,
    mandate_id: ID,
}

/// Agent executor capability — scoped workflow initiation, never holds funds.
public struct ExecutorCap has key, store {
    id: UID,
    authority: AgentAuthority,
}

/// Agent auditor capability — scoped read/risk reporting.
public struct AuditorCap has key, store {
    id: UID,
    authority: AgentAuthority,
}

public(package) fun create_delegation_cap(mandate_id: ID, ctx: &mut TxContext): DelegationCap {
    DelegationCap { id: object::new(ctx), mandate_id }
}

public(package) fun share_tracker(t: DailyExecutionTracker) {
    transfer::share_object(t);
}

public fun transfer_delegation_cap(cap: DelegationCap, owner: address) {
    transfer::transfer(cap, owner);
}

public(package) fun create_daily_tracker(
    mandate_id: ID,
    ctx: &mut TxContext,
): DailyExecutionTracker {
    DailyExecutionTracker {
        id: object::new(ctx),
        agent: @0x0,
        mandate_id,
        current_day: 0,
        total_executed_today: 0,
    }
}

public fun agent_authority(
    mandate_id: ID,
    agent: address,
    expires_at_ms: u64,
    max_per_tx: u64,
    max_daily: u64,
    allowed_actions: vector<u8>,
    protocol_mask: u64,
): AgentAuthority {
    AgentAuthority {
        mandate_id,
        agent,
        expires_at_ms,
        max_per_tx,
        max_daily,
        allowed_actions,
        protocol_mask,
    }
}

public fun issue_executor_cap(
    delegation: &DelegationCap,
    constitution: &FinancialConstitution,
    authority_params: AgentAuthority,
    ctx: &mut TxContext,
): ExecutorCap {
    assert!(delegation.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    assert!(rules::is_governor(constitution.governance(), ctx.sender()), types::enot_authorized());
    assert!(authority_params.mandate_id == delegation.mandate_id, types::edelegation_scope_violation());

    event::emit(DelegationIssued {
        mandate_id: delegation.mandate_id,
        agent: authority_params.agent,
        cap_type: types::role_executor(),
        expires_at_ms: authority_params.expires_at_ms,
    });

    ExecutorCap {
        id: object::new(ctx),
        authority: authority_params,
    }
}

public fun issue_auditor_cap(
    delegation: &DelegationCap,
    constitution: &FinancialConstitution,
    authority_params: AgentAuthority,
    ctx: &mut TxContext,
): AuditorCap {
    assert!(delegation.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    assert!(rules::is_governor(constitution.governance(), ctx.sender()), types::enot_authorized());
    assert!(authority_params.mandate_id == delegation.mandate_id, types::edelegation_scope_violation());

    event::emit(DelegationIssued {
        mandate_id: delegation.mandate_id,
        agent: authority_params.agent,
        cap_type: types::role_auditor(),
        expires_at_ms: authority_params.expires_at_ms,
    });

    AuditorCap { id: object::new(ctx), authority: authority_params }
}

public fun transfer_executor_cap(cap: ExecutorCap, agent: address) {
    transfer::transfer(cap, agent);
}

public fun transfer_auditor_cap(cap: AuditorCap, agent: address) {
    transfer::transfer(cap, agent);
}

/// Validate agent executor cap and daily ledger at settlement (no fund access).
public fun assert_executor_cap(
    cap: &ExecutorCap,
    tracker: &mut DailyExecutionTracker,
    mandate_id: ID,
    action: u8,
    amount: u64,
    day: u64,
    now_ms: u64,
    sender: address,
) {
    let a = &cap.authority;
    assert!(a.agent == sender, types::enot_authorized());
    assert!(a.mandate_id == mandate_id, types::edelegation_scope_violation());
    assert!(tracker.mandate_id == mandate_id, types::edelegation_scope_violation());
    assert!(now_ms < a.expires_at_ms, types::edelegation_expired());
    assert!(amount <= a.max_per_tx, types::edelegation_scope_violation());
    assert!(a.allowed_actions.contains(&action), types::edelegation_scope_violation());

    let protocol_bit = types::protocol_bit_for_action(action);
    if (protocol_bit > 0) {
        assert!((a.protocol_mask & protocol_bit) != 0, types::eprotocol_restricted());
    };

    if (tracker.agent != sender || tracker.current_day != day) {
        tracker.agent = sender;
        tracker.current_day = day;
        tracker.total_executed_today = 0;
    };
    assert!(
        tracker.total_executed_today + amount <= a.max_daily,
        types::edelegation_scope_violation(),
    );
    tracker.total_executed_today = tracker.total_executed_today + amount;
}

public fun assert_auditor_cap(
    cap: &AuditorCap,
    mandate_id: ID,
    now_ms: u64,
    sender: address,
) {
    let a = &cap.authority;
    assert!(a.agent == sender, types::enot_authorized());
    assert!(a.mandate_id == mandate_id, types::edelegation_scope_violation());
    assert!(now_ms < a.expires_at_ms, types::edelegation_expired());
}

public fun cap_mandate_id(cap: &DelegationCap): ID { cap.mandate_id }
public fun executor_authority(cap: &ExecutorCap): &AgentAuthority { &cap.authority }
public fun tracker_agent(t: &DailyExecutionTracker): address { t.agent }
public fun tracker_mandate_id(t: &DailyExecutionTracker): ID { t.mandate_id }
public fun total_executed_today(t: &DailyExecutionTracker): u64 { t.total_executed_today }
