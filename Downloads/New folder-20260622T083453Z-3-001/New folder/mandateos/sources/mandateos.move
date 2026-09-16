/// MandateOS package entrypoint and admin capability.
module mandateos::mandateos;

use sui::vec_map::{Self, VecMap};
use mandateos::templates::{Self, TemplateRegistry};

/// One-time admin capability for protocol bootstrap.
public struct MandateOSAdminCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let mut registry = templates::create_registry(ctx);
    templates::bootstrap_standard_templates(&mut registry, ctx);
    templates::share_registry(registry);

    transfer::transfer(
        MandateOSAdminCap { id: object::new(ctx) },
        ctx.sender(),
    );
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

/// Build governance authorities map for custom mandate setups.
public fun build_authorities(
    governor: address,
    executor: address,
    auditor: address,
): VecMap<address, u8> {
    let mut authorities = vec_map::empty<address, u8>();
    authorities.insert(governor, mandateos::types::role_governor());
    authorities.insert(executor, mandateos::types::role_executor());
    authorities.insert(auditor, mandateos::types::role_auditor());
    authorities
}
