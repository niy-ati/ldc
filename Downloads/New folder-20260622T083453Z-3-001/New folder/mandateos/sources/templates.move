/// Mandate Template Registry — first-class on-chain capital product definitions.
module mandateos::templates;

use sui::event;
use mandateos::types::{Self};

/// Immutable template definition published to the registry.
public struct MandateTemplate has key, store {
    id: UID,
    template_id: u8,
    mandate_type: u8,
    version: u64,
    name: vector<u8>,
    default_primary_objective: u8,
    default_min_runway_days: u64,
    default_reserve_bps: u64,
    default_max_concentration_bps: u64,
    default_actions: vector<u8>,
    active: bool,
}

public struct TemplateRegistry has key {
    id: UID,
    templates: vector<ID>,
    template_count: u64,
}

public struct TemplateRegistered has copy, drop {
    registry_id: ID,
    template_id: u8,
    template_object_id: ID,
}

public(package) fun share_registry(registry: TemplateRegistry) {
    transfer::share_object(registry);
}

public(package) fun share_template(template: MandateTemplate) {
    transfer::share_object(template);
}

public(package) fun create_registry(ctx: &mut TxContext): TemplateRegistry {
    TemplateRegistry {
        id: object::new(ctx),
        templates: vector[],
        template_count: 0,
    }
}

public(package) fun register_template(
    registry: &mut TemplateRegistry,
    template_id: u8,
    mandate_type: u8,
    name: vector<u8>,
    default_primary_objective: u8,
    default_min_runway_days: u64,
    default_reserve_bps: u64,
    default_max_concentration_bps: u64,
    default_actions: vector<u8>,
    ctx: &mut TxContext,
): MandateTemplate {
    let template = MandateTemplate {
        id: object::new(ctx),
        template_id,
        mandate_type,
        version: 1,
        name,
        default_primary_objective,
        default_min_runway_days,
        default_reserve_bps,
        default_max_concentration_bps,
        default_actions,
        active: true,
    };

    registry.templates.push_back(object::id(&template));
    registry.template_count = registry.template_count + 1;

    event::emit(TemplateRegistered {
        registry_id: object::id(registry),
        template_id,
        template_object_id: object::id(&template),
    });

    template
}

public fun template_id(t: &MandateTemplate): u8 { t.template_id }
public fun mandate_type(t: &MandateTemplate): u8 { t.mandate_type }
public fun name(t: &MandateTemplate): vector<u8> { t.name }
public fun default_primary_objective(t: &MandateTemplate): u8 { t.default_primary_objective }
public fun default_min_runway_days(t: &MandateTemplate): u64 { t.default_min_runway_days }
public fun default_reserve_bps(t: &MandateTemplate): u64 { t.default_reserve_bps }
public fun default_max_concentration_bps(t: &MandateTemplate): u64 { t.default_max_concentration_bps }
public fun default_actions(t: &MandateTemplate): &vector<u8> { &t.default_actions }
public fun is_active(t: &MandateTemplate): bool { t.active }
public fun template_count(registry: &TemplateRegistry): u64 { registry.template_count }

public(package) fun bootstrap_standard_templates(
    registry: &mut TemplateRegistry,
    ctx: &mut TxContext,
) {
    share_template(register_template(
        registry,
        types::template_startup_treasury(),
        types::mandate_treasury(),
        b"Startup Treasury",
        mandateos::objectives::objective_preservation(),
        90,
        1000,
        2500,
        vector[types::action_treasury(), types::action_transfer(), types::action_allocate()],
        ctx,
    ));
    share_template(register_template(
        registry,
        types::template_dao_treasury(),
        types::mandate_dao_treasury(),
        b"DAO Treasury",
        mandateos::objectives::objective_preservation(),
        180,
        2000,
        2000,
        vector[types::action_treasury(), types::action_transfer(), types::action_allocate()],
        ctx,
    ));
    share_template(register_template(
        registry,
        types::template_payroll(),
        types::mandate_payroll(),
        b"Payroll",
        mandateos::objectives::objective_distribution(),
        30,
        500,
        2500,
        vector[types::action_payroll(), types::action_transfer()],
        ctx,
    ));
    share_template(register_template(
        registry,
        types::template_subscription(),
        types::mandate_subscription(),
        b"Subscription",
        mandateos::objectives::objective_preservation(),
        30,
        500,
        1500,
        vector[types::action_subscription(), types::action_transfer()],
        ctx,
    ));
    share_template(register_template(
        registry,
        types::template_revenue_routing(),
        types::mandate_revenue_allocation(),
        b"Revenue Routing",
        mandateos::objectives::objective_distribution(),
        14,
        500,
        2000,
        vector[types::action_revenue_split(), types::action_allocate(), types::action_transfer()],
        ctx,
    ));
    share_template(register_template(
        registry,
        types::template_auto_investment(),
        types::mandate_auto_investment(),
        b"Auto-Investment",
        mandateos::objectives::objective_growth(),
        60,
        1000,
        1500,
        vector[types::action_invest(), types::action_allocate()],
        ctx,
    ));
}
