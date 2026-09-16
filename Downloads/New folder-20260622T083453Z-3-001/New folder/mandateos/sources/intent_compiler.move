/// IntentCompiler — materializes approved intents into the full MandateOS object graph.
module mandateos::intent_compiler;

use sui::clock::Clock;
use mandateos::intent::{Self, IntentObject};
use mandateos::templates::MandateTemplate;
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::constitutional::{Self, FinancialConstitution};
use mandateos::objectives::{Self, ObligationRegistry};
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook, OracleCap};
use mandateos::guardian::GuardianPolicy;
use mandateos::delegation::{DelegationCap, DailyExecutionTracker};
use mandateos::rules;
use mandateos::types::{Self};
use mandateos::vault::MandateVault;

public struct CompiledIntent has copy, drop {
    intent_id: ID,
    mandate_id: ID,
    mandate_type: u8,
    template_id: u8,
}

/// Compile an approved intent into an unshared mandate graph.
public fun compile<T>(
    intent: &mut IntentObject,
    template: &MandateTemplate,
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
    GuardianPolicy,
    DelegationCap,
    DailyExecutionTracker,
) {
    assert!(intent::status(intent) == types::intent_approved(), types::einvalid_intent_status());
    let inputs = *intent::inputs(intent);
    assert!(template.template_id() == intent::input_template_id(&inputs), types::etemplate_not_found());

    let objectives = objectives::financial_objectives(
        intent::input_primary_objective(&inputs),
        intent::input_target_balance(&inputs),
        intent::input_min_runway_days(&inputs),
        0,
        0,
        intent::input_reserve_bps(&inputs),
        *intent::input_purpose_hash(&inputs),
    );

    let ownership = financial_mandate::ownership_for(intent::input_owner(&inputs));
    let spending = financial_mandate::permissive_spending(
        intent::input_max_per_tx(&inputs),
        intent::input_max_daily(&inputs),
    );
    let execution = financial_mandate::actions_only(*template.default_actions());
    let reserve = rules::reserve_requirements(intent::input_reserve_bps(&inputs), 0);
    let treasury = financial_mandate::no_treasury_obligation();
    let governance = financial_mandate::default_governance(intent::input_executor(&inputs), ctx);
    let expiration = financial_mandate::year_expiration(clock);
    let initial_obligations = vector[];

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
        intent::input_mandate_type(&inputs),
        objectives,
        ownership,
        spending,
        execution,
        reserve,
        treasury,
        governance,
        expiration,
        initial_obligations,
        clock,
        ctx,
    );

    let mandate_id = object::id(&mandate);
    let guardian = mandateos::guardian::create_policy(mandate_id, 2500, ctx);
    intent::mark_compiled(intent, mandate_id, clock.timestamp_ms());

    let _compiled = CompiledIntent {
        intent_id: intent::intent_id(intent),
        mandate_id,
        mandate_type: intent::input_mandate_type(&inputs),
        template_id: intent::input_template_id(&inputs),
    };

    (
        mandate,
        vault,
        constitution,
        obligations,
        risk,
        engine,
        forecast,
        hook,
        oracle_cap,
        guardian,
        delegation_cap,
        execution_tracker,
    )
}

/// Activate compiled intent — share mandate graph on-chain.
public fun activate<T>(
    intent: &mut IntentObject,
    mandate: FinancialMandate,
    vault: MandateVault<T>,
    constitution: FinancialConstitution,
    obligations: ObligationRegistry,
    risk: OperationalRiskProfile,
    engine: LiquidityEngine,
    forecast: MarketForecast,
    hook: DeepBookHook,
    oracle_cap: OracleCap,
    guardian: GuardianPolicy,
    delegation_cap: DelegationCap,
    execution_tracker: DailyExecutionTracker,
) {
    assert!(intent::status(intent) == types::intent_compiled(), types::einvalid_intent_status());
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
    intent::mark_activated(intent);
}
