/// Intent Layer — pre-constitutional financial objectives before mandate ratification.
module mandateos::intent;

use std::option::{Self, Option};
use sui::event;
use mandateos::templates::MandateTemplate;
use mandateos::types::{Self};

/// Parameter bundle consumed by IntentCompiler to materialize a mandate graph.
public struct IntentCompilerInputs has store, copy, drop {
    template_id: u8,
    mandate_type: u8,
    owner: address,
    executor: address,
    max_per_tx: u64,
    max_daily: u64,
    target_balance: u64,
    min_runway_days: u64,
    primary_objective: u8,
    reserve_bps: u64,
    purpose_hash: vector<u8>,
}

/// Lightweight intent template reference (links to MandateTemplate registry entry).
public struct IntentTemplate has store, copy, drop {
    registry_template_id: u8,
    mandate_type: u8,
    name: vector<u8>,
}

public struct IntentStatusChanged has copy, drop {
    intent_id: ID,
    old_status: u8,
    new_status: u8,
}

/// Financial objective before constitutional ratification.
public struct IntentObject has key, store {
    id: UID,
    status: u8,
    template: IntentTemplate,
    inputs: IntentCompilerInputs,
    drafter: address,
    reviewer: address,
    mandate_id: Option<ID>,
    created_at_ms: u64,
    compiled_at_ms: u64,
}

public fun intent_template_from_mandate_template(t: &MandateTemplate): IntentTemplate {
    IntentTemplate {
        registry_template_id: t.template_id(),
        mandate_type: t.mandate_type(),
        name: t.name(),
    }
}

public fun compiler_inputs(
    template_id: u8,
    mandate_type: u8,
    owner: address,
    executor: address,
    max_per_tx: u64,
    max_daily: u64,
    target_balance: u64,
    min_runway_days: u64,
    primary_objective: u8,
    reserve_bps: u64,
    purpose_hash: vector<u8>,
): IntentCompilerInputs {
    IntentCompilerInputs {
        template_id,
        mandate_type,
        owner,
        executor,
        max_per_tx,
        max_daily,
        target_balance,
        min_runway_days,
        primary_objective,
        reserve_bps,
        purpose_hash,
    }
}

public fun inputs_from_template(
    t: &MandateTemplate,
    owner: address,
    executor: address,
    max_per_tx: u64,
    max_daily: u64,
    target_balance: u64,
    purpose_hash: vector<u8>,
): IntentCompilerInputs {
    compiler_inputs(
        t.template_id(),
        t.mandate_type(),
        owner,
        executor,
        max_per_tx,
        max_daily,
        target_balance,
        t.default_min_runway_days(),
        t.default_primary_objective(),
        t.default_reserve_bps(),
        purpose_hash,
    )
}

public fun draft_intent(
    template: IntentTemplate,
    inputs: IntentCompilerInputs,
    now_ms: u64,
    ctx: &mut TxContext,
): IntentObject {
    IntentObject {
        id: object::new(ctx),
        status: types::intent_draft(),
        template,
        inputs,
        drafter: ctx.sender(),
        reviewer: @0x0,
        mandate_id: option::none(),
        created_at_ms: now_ms,
        compiled_at_ms: 0,
    }
}

public fun submit_for_review(intent: &mut IntentObject, ctx: &TxContext) {
    assert!(intent.status == types::intent_draft(), types::einvalid_intent_status());
    assert!(intent.drafter == ctx.sender(), types::enot_authorized());
    transition(intent, types::intent_review());
}

public fun approve_intent(intent: &mut IntentObject, reviewer: address, ctx: &TxContext) {
    assert!(intent.status == types::intent_review(), types::einvalid_intent_status());
    assert!(ctx.sender() == reviewer || intent.drafter == ctx.sender(), types::enot_authorized());
    intent.reviewer = reviewer;
    transition(intent, types::intent_approved());
}

public(package) fun mark_compiled(intent: &mut IntentObject, mandate_id: ID, now_ms: u64) {
    assert!(intent.status == types::intent_approved(), types::einvalid_intent_status());
    intent.mandate_id = option::some(mandate_id);
    intent.compiled_at_ms = now_ms;
    transition(intent, types::intent_compiled());
}

public(package) fun mark_activated(intent: &mut IntentObject) {
    assert!(intent.status == types::intent_compiled(), types::einvalid_intent_status());
    transition(intent, types::intent_activated());
}

fun transition(intent: &mut IntentObject, new_status: u8) {
    let old = intent.status;
    intent.status = new_status;
    event::emit(IntentStatusChanged {
        intent_id: object::id(intent),
        old_status: old,
        new_status,
    });
}

public fun input_template_id(i: &IntentCompilerInputs): u8 { i.template_id }
public fun input_mandate_type(i: &IntentCompilerInputs): u8 { i.mandate_type }
public fun input_owner(i: &IntentCompilerInputs): address { i.owner }
public fun input_executor(i: &IntentCompilerInputs): address { i.executor }
public fun input_max_per_tx(i: &IntentCompilerInputs): u64 { i.max_per_tx }
public fun input_max_daily(i: &IntentCompilerInputs): u64 { i.max_daily }
public fun input_target_balance(i: &IntentCompilerInputs): u64 { i.target_balance }
public fun input_min_runway_days(i: &IntentCompilerInputs): u64 { i.min_runway_days }
public fun input_primary_objective(i: &IntentCompilerInputs): u8 { i.primary_objective }
public fun input_reserve_bps(i: &IntentCompilerInputs): u64 { i.reserve_bps }
public fun input_purpose_hash(i: &IntentCompilerInputs): &vector<u8> { &i.purpose_hash }

public fun intent_id(i: &IntentObject): ID { object::id(i) }
public fun status(i: &IntentObject): u8 { i.status }
public fun inputs(i: &IntentObject): &IntentCompilerInputs { &i.inputs }
public fun mandate_id(i: &IntentObject): Option<ID> { i.mandate_id }
public fun template_ref(i: &IntentObject): &IntentTemplate { &i.template }

public fun share_intent(intent: IntentObject) {
    transfer::share_object(intent);
}
