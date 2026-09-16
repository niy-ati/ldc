/// DAO Treasury Mandate — governance objectives with proposal obligations.
module mandateos::dao_treasury_mandate;

use sui::clock::Clock;
use sui::vec_map;
use std::option::{Self, Option};
use sui::coin::Coin;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{Self, ObligationRegistry};
use mandateos::operational_risk::{Self, OperationalRiskProfile};
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook, OracleCap};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::authority;
use mandateos::rules::{Self};
use mandateos::types::{Self};
use mandateos::vault::{Self, MandateVault};
use mandateos::receipts::FinancialReceipt;
use mandateos::simulation::SimulationApproval;
use mandateos::delegation::{ExecutorCap, DelegationCap, DailyExecutionTracker};
use mandateos::workflow::WorkflowSession;

public struct DaoProposal has store, copy, drop {
    proposal_id: u64,
    recipient: address,
    amount: u64,
    votes_for: u64,
    votes_against: u64,
    executed: bool,
}

public struct DaoTreasuryConfig has key {
    id: UID,
    mandate_id: ID,
    quorum_votes: u64,
    voting_period_ms: u64,
    proposals: vector<DaoProposal>,
    next_proposal_id: u64,
}

public fun create<T>(
    dao_admin: address,
    governors: vector<address>,
    quorum: u64,
    max_per_tx: u64,
    max_daily: u64,
    voting_period_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (
    FinancialMandate,
    MandateVault<T>,
    FinancialConstitution,
    ObligationRegistry,
    OperationalRiskProfile,
    LiquidityEngine,
    MarketForecast,
    DeepBookHook,
    OracleCap,
    mandateos::guardian::GuardianPolicy,
    DelegationCap,
    DailyExecutionTracker,
    DaoTreasuryConfig,
) {
    let objectives = objectives::preservation_objectives(max_daily * 30, 180, 2000);
    let ownership = rules::ownership_rules(dao_admin, governors, true);
    let spending = financial_mandate::permissive_spending(max_per_tx, max_daily);
    let actions = vector[types::action_treasury(), types::action_transfer(), types::action_allocate()];
    let execution = financial_mandate::actions_only(actions);
    let reserve = rules::reserve_requirements(2000, max_per_tx);
    let treasury = financial_mandate::no_treasury_obligation();

    let mut authorities = vec_map::empty<address, u8>();
    authorities.insert(dao_admin, types::role_governor());
    let mut i = 0;
    while (i < governors.length()) {
        authorities.insert(governors[i], types::role_governor());
        i = i + 1;
    };
    let governance = rules::governance_authorities(authorities, quorum);
    let expiration = financial_mandate::no_expiration();

    let (
        mandate,
        vault,
        constitution,
        obligations,
        risk,
        engine,
        forecast,
        hook,
        oracle_cap,
        delegation_cap,
        execution_tracker,
    ) = financial_mandate::bootstrap_os<T>(
            types::mandate_dao_treasury(),
            objectives,
            ownership,
            spending,
            execution,
            reserve,
            treasury,
            governance,
            expiration,
            vector[],
            clock,
            ctx,
        );

    let guardian = mandateos::guardian::create_policy(object::id(&mandate), 2500, ctx);

    let config = DaoTreasuryConfig {
        id: object::new(ctx),
        mandate_id: object::id(&mandate),
        quorum_votes: quorum,
        voting_period_ms,
        proposals: vector[],
        next_proposal_id: 1,
    };

    (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config)
}

public fun share_all<T>(
    mandate: FinancialMandate,
    vault: MandateVault<T>,
    constitution: FinancialConstitution,
    obligations: ObligationRegistry,
    risk: OperationalRiskProfile,
    engine: LiquidityEngine,
    forecast: MarketForecast,
    hook: DeepBookHook,
    oracle_cap: OracleCap,
    guardian: mandateos::guardian::GuardianPolicy,
    delegation_cap: DelegationCap,
    execution_tracker: DailyExecutionTracker,
    config: DaoTreasuryConfig,
) {
    financial_mandate::share_os(
        mandate,
        vault,
        constitution,
        obligations,
        risk,
        engine,
        forecast,
        hook,
        oracle_cap,
        delegation_cap,
        execution_tracker,
    );
    mandateos::guardian::share_policy(guardian);
    transfer::share_object(config);
}

public fun create_proposal(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    config: &mut DaoTreasuryConfig,
    recipient: address,
    amount: u64,
    ctx: &TxContext,
): u64 {
    assert!(object::id(mandate) == config.mandate_id, types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());

    let id = config.next_proposal_id;
    config.proposals.push_back(DaoProposal {
        proposal_id: id,
        recipient,
        amount,
        votes_for: 0,
        votes_against: 0,
        executed: false,
    });
    config.next_proposal_id = config.next_proposal_id + 1;
    id
}

public fun vote(
    constitution: &FinancialConstitution,
    config: &mut DaoTreasuryConfig,
    proposal_id: u64,
    approve: bool,
    ctx: &TxContext,
) {
    authority::assert_governor(constitution, ctx.sender());
    let idx = find_proposal(config, proposal_id);
    if (approve) {
        config.proposals[idx].votes_for = config.proposals[idx].votes_for + 1;
    } else {
        config.proposals[idx].votes_against = config.proposals[idx].votes_against + 1;
    };
}

public fun execute_proposal<T>(
    mandate: &mut FinancialMandate,
    constitution: &mut FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &mut LiquidityEngine,
    obligations: &mut ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    config: &mut DaoTreasuryConfig,
    vault: &mut MandateVault<T>,
    session: &mut WorkflowSession,
    execution_tracker: &mut DailyExecutionTracker,
    approval: &mut SimulationApproval,
    executor_cap: &Option<ExecutorCap>,
    proposal_id: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): FinancialReceipt {
    assert!(object::id(mandate) == config.mandate_id, types::evault_mismatch());

    let idx = find_proposal(config, proposal_id);
    let amount = config.proposals[idx].amount;
    let recipient = config.proposals[idx].recipient;
    assert!(!config.proposals[idx].executed, types::eexecution_constraint_violation());
    assert!(config.proposals[idx].votes_for >= config.quorum_votes, types::egovernance_quorum_not_met());

    config.proposals[idx].executed = true;

    financial_mandate::run_authorized_settlement(
        mandate,
        constitution,
        risk,
        engine,
        obligations,
        forecast,
        hook,
        vault,
        session,
        execution_tracker,
        types::action_treasury(),
        amount,
        recipient,
        0,
        executor_cap,
        approval,
        clock,
        ctx,
    )
}

public fun fund<T>(vault: &mut MandateVault<T>, coin: Coin<T>) {
    vault::deposit(vault, coin);
}

fun find_proposal(config: &DaoTreasuryConfig, proposal_id: u64): u64 {
    let mut i = 0;
    while (i < config.proposals.length()) {
        if (config.proposals[i].proposal_id == proposal_id) return i;
        i = i + 1;
    };
    abort types::einvalid_amount()
}
