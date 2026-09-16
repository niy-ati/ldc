/// Receipt Objects — immutable audit trail for every OS layer transition.
module mandateos::receipts;

use mandateos::operational_risk::{Self, RiskCleared};
use mandateos::adaptive_liquidity::{Self, LiquidityCleared};
use mandateos::workflow::{Self, WorkflowSession, ExecutionAuthorization};

const RECEIPT_EXECUTION: u8 = 1;
const RECEIPT_OBLIGATION: u8 = 2;
const RECEIPT_RISK: u8 = 3;
const RECEIPT_LIQUIDITY: u8 = 4;
const RECEIPT_WORKFLOW: u8 = 5;
const RECEIPT_REMEDIATION: u8 = 6;

public struct GuardianRemediationReceipt has key, store {
    id: UID,
    mandate_id: ID,
    plan_id: ID,
    reason: u8,
    source_allocation: u64,
    target_allocation: u64,
    liquidity_deficit: u64,
    executed_at: u64,
}

public struct RiskAssessmentReceipt has key, store {
    id: UID,
    mandate_id: ID,
    workflow_id: ID,
    action: u8,
    amount: u64,
    recipient: address,
    exposure_bps: u64,
    portfolio_risk_score: u64,
    assessed_at: u64,
}

public struct LiquidityAssessmentReceipt has key, store {
    id: UID,
    mandate_id: ID,
    workflow_id: ID,
    required_buffer: u64,
    post_debit_liquid: u64,
    forecast_multiplier_bps: u64,
    assessed_at: u64,
}

public struct ObligationFulfillmentReceipt has key, store {
    id: UID,
    mandate_id: ID,
    workflow_id: ID,
    obligation_id: u64,
    amount: u64,
    remaining: u64,
    fulfilled_at: u64,
}

public struct FinancialReceipt has key, store {
    id: UID,
    mandate_id: ID,
    workflow_id: ID,
    receipt_type: u8,
    action: u8,
    amount: u64,
    recipient: address,
    constitution_version: u64,
    risk_exposure_bps: u64,
    liquidity_buffer_required: u64,
    obligation_id: u64,
    executed_at: u64,
    vault_balance_after: u64,
}

public struct WorkflowCompletionReceipt has key, store {
    id: UID,
    mandate_id: ID,
    workflow_id: ID,
    steps_completed: u8,
    completed_at: u64,
}

public(package) fun issue_layer_receipts(
    auth: &ExecutionAuthorization,
    ctx: &mut TxContext,
): (RiskAssessmentReceipt, LiquidityAssessmentReceipt) {
    let risk = workflow::auth_risk(auth);
    let liquidity = workflow::auth_liquidity(auth);
    let risk_a = operational_risk::cleared_assessment(risk);
    let liq_a = adaptive_liquidity::cleared_assessment(liquidity);

    let risk_receipt = RiskAssessmentReceipt {
        id: object::new(ctx),
        mandate_id: workflow::auth_mandate_id(auth),
        workflow_id: workflow::auth_workflow_id(auth),
        action: operational_risk::assessment_action(risk_a),
        amount: operational_risk::assessment_amount(risk_a),
        recipient: operational_risk::assessment_recipient(risk_a),
        exposure_bps: operational_risk::assessment_exposure_bps(risk_a),
        portfolio_risk_score: operational_risk::assessment_portfolio_risk_score(risk_a),
        assessed_at: operational_risk::assessment_assessed_at(risk_a),
    };

    let liquidity_receipt = LiquidityAssessmentReceipt {
        id: object::new(ctx),
        mandate_id: workflow::auth_mandate_id(auth),
        workflow_id: workflow::auth_workflow_id(auth),
        required_buffer: adaptive_liquidity::assessment_required_buffer(liq_a),
        post_debit_liquid: adaptive_liquidity::assessment_post_debit_liquid(liq_a),
        forecast_multiplier_bps: adaptive_liquidity::assessment_forecast_multiplier_bps(liq_a),
        assessed_at: adaptive_liquidity::assessment_assessed_at(liq_a),
    };

    (risk_receipt, liquidity_receipt)
}

public(package) fun issue_obligation_receipt(
    auth: &ExecutionAuthorization,
    remaining: u64,
    ctx: &mut TxContext,
): ObligationFulfillmentReceipt {
    ObligationFulfillmentReceipt {
        id: object::new(ctx),
        mandate_id: workflow::auth_mandate_id(auth),
        workflow_id: workflow::auth_workflow_id(auth),
        obligation_id: workflow::auth_obligation_id(auth),
        amount: workflow::auth_amount(auth),
        remaining,
        fulfilled_at: workflow::auth_validated_at(auth),
    }
}

public(package) fun issue_financial_receipt(
    session: &WorkflowSession,
    auth: &ExecutionAuthorization,
    vault_balance_after: u64,
    ctx: &mut TxContext,
): FinancialReceipt {
    let risk_a = operational_risk::cleared_assessment(workflow::auth_risk(auth));
    let liq_a = adaptive_liquidity::cleared_assessment(workflow::auth_liquidity(auth));

    FinancialReceipt {
        id: object::new(ctx),
        mandate_id: workflow::session_mandate_id(session),
        workflow_id: workflow::session_id(session),
        receipt_type: RECEIPT_EXECUTION,
        action: workflow::auth_action(auth),
        amount: workflow::auth_amount(auth),
        recipient: workflow::auth_recipient(auth),
        constitution_version: operational_risk::risk_constitution_version(workflow::auth_risk(auth)),
        risk_exposure_bps: operational_risk::assessment_exposure_bps(risk_a),
        liquidity_buffer_required: adaptive_liquidity::assessment_required_buffer(liq_a),
        obligation_id: workflow::auth_obligation_id(auth),
        executed_at: workflow::auth_validated_at(auth),
        vault_balance_after,
    }
}

public(package) fun issue_workflow_completion(
    session: &WorkflowSession,
    completed_at: u64,
    ctx: &mut TxContext,
): WorkflowCompletionReceipt {
    WorkflowCompletionReceipt {
        id: object::new(ctx),
        mandate_id: workflow::session_mandate_id(session),
        workflow_id: workflow::session_id(session),
        steps_completed: workflow::steps_completed(session),
        completed_at,
    }
}

public(package) fun issue_remediation_receipt(
    plan_id: ID,
    mandate_id: ID,
    reason: u8,
    source_allocation: u64,
    target_allocation: u64,
    liquidity_deficit: u64,
    executed_at: u64,
    ctx: &mut TxContext,
): GuardianRemediationReceipt {
    GuardianRemediationReceipt {
        id: object::new(ctx),
        mandate_id,
        plan_id,
        reason,
        source_allocation,
        target_allocation,
        liquidity_deficit,
        executed_at,
    }
}

public fun financial_receipt_mandate_id(r: &FinancialReceipt): ID { r.mandate_id }
public fun financial_receipt_amount(r: &FinancialReceipt): u64 { r.amount }
public fun financial_receipt_recipient(r: &FinancialReceipt): address { r.recipient }
public fun financial_receipt_workflow_id(r: &FinancialReceipt): ID { r.workflow_id }
