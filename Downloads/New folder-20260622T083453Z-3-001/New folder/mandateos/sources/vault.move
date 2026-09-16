/// Mandate-controlled vault. Debits require non-forgeable ExecutionAuthorization.
module mandateos::vault;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use mandateos::types::{Self};

/// On-chain fund container governed exclusively by its linked Financial Mandate.
public struct MandateVault<phantom T> has key, store {
    id: UID,
    mandate_id: ID,
    balance: Balance<T>,
    total_deposited: u64,
    total_withdrawn: u64,
    illiquid_allocation_bps: u64,
}

public struct VaultFunded has copy, drop {
    vault_id: ID,
    mandate_id: ID,
    amount: u64,
    new_balance: u64,
}

public struct VaultDebited has copy, drop {
    vault_id: ID,
    mandate_id: ID,
    amount: u64,
    recipient: address,
    new_balance: u64,
}

public(package) fun share_vault<T>(vault: MandateVault<T>) {
    transfer::share_object(vault);
}

public(package) fun create_vault<T>(
    mandate_id: ID,
    ctx: &mut TxContext,
): MandateVault<T> {
    MandateVault {
        id: object::new(ctx),
        mandate_id,
        balance: balance::zero(),
        total_deposited: 0,
        total_withdrawn: 0,
        illiquid_allocation_bps: 0,
    }
}

public fun vault_id<T>(vault: &MandateVault<T>): ID { object::id(vault) }
public fun mandate_id<T>(vault: &MandateVault<T>): ID { vault.mandate_id }
public fun balance_value<T>(vault: &MandateVault<T>): u64 { vault.balance.value() }
public fun total_deposited<T>(vault: &MandateVault<T>): u64 { vault.total_deposited }
public fun illiquid_allocation_bps<T>(vault: &MandateVault<T>): u64 {
    vault.illiquid_allocation_bps
}

/// Deposit coins into the mandate vault. Anyone may fund a mandate.
public fun deposit<T>(vault: &mut MandateVault<T>, coin: Coin<T>) {
    let amount = coin.value();
    balance::join(&mut vault.balance, coin::into_balance(coin));
    vault.total_deposited = vault.total_deposited + amount;

    event::emit(VaultFunded {
        vault_id: object::id(vault),
        mandate_id: vault.mandate_id,
        amount,
        new_balance: vault.balance.value(),
    });
}

/// Debit vault — ONLY callable with workflow-issued authorization fields from settlement.
public(package) fun debit_authorized<T>(
    vault: &mut MandateVault<T>,
    mandate_id: ID,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(mandate_id == vault.mandate_id, types::evault_mismatch());
    assert!(amount > 0, types::einvalid_amount());
    assert!(vault.balance.value() >= amount, types::einsufficient_liquidity());

    vault.total_withdrawn = vault.total_withdrawn + amount;
    let coin = coin::from_balance(balance::split(&mut vault.balance, amount), ctx);

    event::emit(VaultDebited {
        vault_id: object::id(vault),
        mandate_id: vault.mandate_id,
        amount,
        recipient,
        new_balance: vault.balance.value(),
    });

    coin
}

public(package) fun set_illiquid_allocation<T>(
    vault: &mut MandateVault<T>,
    bps: u64,
) {
    vault.illiquid_allocation_bps = bps;
}

public fun liquid_balance_after_debit<T>(
    vault: &MandateVault<T>,
    debit_amount: u64,
): u64 {
    let total = vault.balance.value();
    if (total <= debit_amount) return 0;
    let remaining = total - debit_amount;
    let illiquid = (remaining * vault.illiquid_allocation_bps) / 10000;
    remaining - illiquid
}

public fun post_debit_balance<T>(vault: &MandateVault<T>, debit_amount: u64): u64 {
    if (vault.balance.value() < debit_amount) return 0;
    vault.balance.value() - debit_amount
}

public fun reserve_amount<T>(
    vault: &MandateVault<T>,
    min_reserve_bps: u64,
    reserve_floor: u64,
): u64 {
    let balance_bps = (vault.balance.value() * min_reserve_bps) / 10000;
    if (balance_bps > reserve_floor) balance_bps else reserve_floor
}
