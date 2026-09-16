/// Operational Risk Layer — concentration, counterparty, and covenant risk beyond limits.
module mandateos::operational_risk;

use sui::event;
use mandateos::authority;
use mandateos::constitutional::FinancialConstitution;
use mandateos::types::{Self};

public struct CounterpartyExposure has store, copy, drop {
    counterparty: address,
    exposure_bps: u64,
    risk_score: u64,
}

public struct OperationalRiskProfile has key {
    id: UID,
    mandate_id: ID,
    max_concentration_bps: u64,
    min_liquidity_coverage_bps: u64,
    max_counterparty_risk_score: u64,
    stress_mode: bool,
    portfolio_risk_score: u64,
    counterparties: vector<CounterpartyExposure>,
    assessments_count: u64,
}

public struct RiskAssessment has copy, drop, store {
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    exposure_bps: u64,
    portfolio_risk_score: u64,
    stress_mode: bool,
    assessed_at: u64,
    cleared: bool,
}

/// Non-forgeable clearance witness — only produced by assess_execution.
public struct RiskCleared {
    assessment: RiskAssessment,
    constitution_version: u64,
}

public struct RiskProfileUpdated has copy, drop {
    profile_id: ID,
    mandate_id: ID,
    portfolio_risk_score: u64,
    stress_mode: bool,
}

public(package) fun create_profile(
    mandate_id: ID,
    max_concentration_bps: u64,
    min_liquidity_coverage_bps: u64,
    max_counterparty_risk_score: u64,
    ctx: &mut TxContext,
): OperationalRiskProfile {
    OperationalRiskProfile {
        id: object::new(ctx),
        mandate_id,
        max_concentration_bps,
        min_liquidity_coverage_bps,
        max_counterparty_risk_score,
        stress_mode: false,
        portfolio_risk_score: 0,
        counterparties: vector[],
        assessments_count: 0,
    }
}

/// Workflow-only risk gate.
public(package) fun assess_execution(
    profile: &mut OperationalRiskProfile,
    mandate_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    vault_balance: u64,
    liquid_balance: u64,
    upcoming_obligations: u64,
    constitution_version: u64,
    now_ms: u64,
): RiskCleared {
    assert!(profile.mandate_id == mandate_id, types::evault_mismatch());

    let exposure_bps = if (vault_balance == 0) {
        10000
    } else {
        (amount * 10000) / vault_balance
    };

    assert!(exposure_bps <= profile.max_concentration_bps, types::econcentration_exceeded());
    assert!(profile.portfolio_risk_score <= profile.max_counterparty_risk_score, types::erisk_threshold_exceeded());
    assert!(!profile.stress_mode || exposure_bps <= profile.max_concentration_bps / 2, types::estress_mode_active());

    let cp_risk = counterparty_risk(profile, recipient);
    assert!(cp_risk <= profile.max_counterparty_risk_score, types::ecounterparty_risk_exceeded());
    if (amount > 0) {
        assert!(
            check_liquidity_coverage(profile, liquid_balance, upcoming_obligations),
            types::einsufficient_liquidity(),
        );
    };

    profile.assessments_count = profile.assessments_count + 1;

    RiskCleared {
        assessment: RiskAssessment {
            mandate_id,
            action,
            amount,
            recipient,
            exposure_bps,
            portfolio_risk_score: profile.portfolio_risk_score,
            stress_mode: profile.stress_mode,
            assessed_at: now_ms,
            cleared: true,
        },
        constitution_version,
    }
}

fun check_liquidity_coverage(
    profile: &OperationalRiskProfile,
    liquid_balance: u64,
    upcoming_obligations: u64,
): bool {
    if (upcoming_obligations == 0) return true;
    let coverage_bps = (liquid_balance * 10000) / upcoming_obligations;
    coverage_bps >= profile.min_liquidity_coverage_bps
}

public fun set_portfolio_risk_score(
    profile: &mut OperationalRiskProfile,
    constitution: &FinancialConstitution,
    score: u64,
    ctx: &TxContext,
) {
    assert!(profile.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_auditor(constitution, ctx.sender());
    profile.portfolio_risk_score = score;
    event::emit(RiskProfileUpdated {
        profile_id: object::id(profile),
        mandate_id: profile.mandate_id,
        portfolio_risk_score: score,
        stress_mode: profile.stress_mode,
    });
}

public fun enter_stress_mode(
    profile: &mut OperationalRiskProfile,
    constitution: &FinancialConstitution,
    ctx: &TxContext,
) {
    assert!(profile.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());
    profile.stress_mode = true;
    event::emit(RiskProfileUpdated {
        profile_id: object::id(profile),
        mandate_id: profile.mandate_id,
        portfolio_risk_score: profile.portfolio_risk_score,
        stress_mode: true,
    });
}

public fun exit_stress_mode(
    profile: &mut OperationalRiskProfile,
    constitution: &FinancialConstitution,
    ctx: &TxContext,
) {
    assert!(profile.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());
    profile.stress_mode = false;
    event::emit(RiskProfileUpdated {
        profile_id: object::id(profile),
        mandate_id: profile.mandate_id,
        portfolio_risk_score: profile.portfolio_risk_score,
        stress_mode: false,
    });
}

public fun register_counterparty(
    profile: &mut OperationalRiskProfile,
    constitution: &FinancialConstitution,
    counterparty: address,
    exposure_bps: u64,
    risk_score: u64,
    ctx: &TxContext,
) {
    assert!(profile.mandate_id == constitution.mandate_id(), types::evault_mismatch());
    authority::assert_governor(constitution, ctx.sender());
    profile.counterparties.push_back(CounterpartyExposure {
        counterparty,
        exposure_bps,
        risk_score,
    });
}

fun counterparty_risk(profile: &OperationalRiskProfile, recipient: address): u64 {
    let mut i = 0;
    while (i < profile.counterparties.length()) {
        if (profile.counterparties[i].counterparty == recipient) {
            return profile.counterparties[i].risk_score
        };
        i = i + 1;
    };
    5000
}

public fun profile_mandate_id(p: &OperationalRiskProfile): ID { p.mandate_id }
public fun portfolio_risk_score(p: &OperationalRiskProfile): u64 { p.portfolio_risk_score }
public fun stress_mode(p: &OperationalRiskProfile): bool { p.stress_mode }
public(package) fun risk_constitution_version(r: &RiskCleared): u64 { r.constitution_version }
public(package) fun cleared_assessment(c: &RiskCleared): &RiskAssessment { &c.assessment }

public(package) fun share_profile(p: OperationalRiskProfile) {
    transfer::share_object(p);
}

public(package) fun destroy_cleared(cleared: RiskCleared) {
    let RiskCleared { assessment: _, constitution_version: _ } = cleared;
}

public(package) fun assessment_action(a: &RiskAssessment): u8 { a.action }
public(package) fun assessment_amount(a: &RiskAssessment): u64 { a.amount }
public(package) fun assessment_recipient(a: &RiskAssessment): address { a.recipient }
public(package) fun assessment_exposure_bps(a: &RiskAssessment): u64 { a.exposure_bps }
public(package) fun assessment_portfolio_risk_score(a: &RiskAssessment): u64 { a.portfolio_risk_score }
public(package) fun assessment_assessed_at(a: &RiskAssessment): u64 { a.assessed_at }

public(package) fun standard_profile(mandate_id: ID, ctx: &mut TxContext): OperationalRiskProfile {
    create_profile(mandate_id, 2500, 15000, 8000, ctx)
}
