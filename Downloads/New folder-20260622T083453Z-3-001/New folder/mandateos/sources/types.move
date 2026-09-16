/// Shared types, constants, and error codes for MandateOS.
module mandateos::types;

// ── Mandate type discriminators ─────────────────────────────────────────────

const MANDATE_TREASURY: u8 = 1;
const MANDATE_PAYROLL: u8 = 2;
const MANDATE_AUTO_INVESTMENT: u8 = 3;
const MANDATE_SUBSCRIPTION: u8 = 4;
const MANDATE_REVENUE_ALLOCATION: u8 = 5;
const MANDATE_DAO_TREASURY: u8 = 6;

// ── Mandate lifecycle ───────────────────────────────────────────────────────

const STATUS_ACTIVE: u8 = 0;
const STATUS_PAUSED: u8 = 1;
const STATUS_EXPIRED: u8 = 2;
const STATUS_REVOKED: u8 = 3;
const STATUS_RESTRICTED: u8 = 4;
const STATUS_WARNING: u8 = 5;
const STATUS_CRITICAL: u8 = 6;

// ── Intent lifecycle (pre-constitutional) ─────────────────────────────────────

const INTENT_DRAFT: u8 = 0;
const INTENT_REVIEW: u8 = 1;
const INTENT_APPROVED: u8 = 2;
const INTENT_COMPILED: u8 = 3;
const INTENT_ACTIVATED: u8 = 4;

// ── Governance roles ────────────────────────────────────────────────────────

const ROLE_OWNER: u8 = 0;
const ROLE_EXECUTOR: u8 = 1;
const ROLE_AUDITOR: u8 = 2;
const ROLE_GOVERNOR: u8 = 3;
const ROLE_AGENT: u8 = 4;

// ── Execution action kinds ────────────────────────────────────────────────────

const ACTION_TRANSFER: u8 = 1;
const ACTION_ALLOCATE: u8 = 2;
const ACTION_INVEST: u8 = 3;
const ACTION_PAYROLL: u8 = 4;
const ACTION_SUBSCRIPTION: u8 = 5;
const ACTION_TREASURY: u8 = 6;
const ACTION_REVENUE_SPLIT: u8 = 7;

// ── Guardian workflow actions (non-monetary settlement path) ────────────────

const ACTION_GUARDIAN_PAUSE: u8 = 20;
const ACTION_GUARDIAN_RESTRICT: u8 = 21;
const ACTION_GUARDIAN_REALLOCATE: u8 = 22;
const ACTION_GUARDIAN_ESCALATE: u8 = 23;

public fun is_guardian_action(action: u8): bool {
    action == ACTION_GUARDIAN_PAUSE
        || action == ACTION_GUARDIAN_RESTRICT
        || action == ACTION_GUARDIAN_REALLOCATE
        || action == ACTION_GUARDIAN_ESCALATE
}

// ── Guardian action kinds ─────────────────────────────────────────────────────

const GUARDIAN_AUTO_PAUSE: u8 = 1;
const GUARDIAN_AUTO_RESTRICT: u8 = 2;
const GUARDIAN_AUTO_REALLOCATE: u8 = 3;
const GUARDIAN_AUTO_ESCALATE: u8 = 4;

// ── Guardian trigger kinds ────────────────────────────────────────────────────

const TRIGGER_OBLIGATION_VIOLATION: u8 = 1;
const TRIGGER_LIQUIDITY_FAILURE: u8 = 2;
const TRIGGER_CONCENTRATION_BREACH: u8 = 3;
const TRIGGER_STALE_FORECAST: u8 = 4;
const TRIGGER_CONSTITUTION_BREACH: u8 = 5;

// ── Template registry ─────────────────────────────────────────────────────────

const TEMPLATE_STARTUP_TREASURY: u8 = 1;
const TEMPLATE_DAO_TREASURY: u8 = 2;
const TEMPLATE_PAYROLL: u8 = 3;
const TEMPLATE_SUBSCRIPTION: u8 = 4;
const TEMPLATE_REVENUE_ROUTING: u8 = 5;
const TEMPLATE_AUTO_INVESTMENT: u8 = 6;

// ── Remediation lifecycle ─────────────────────────────────────────────────────

const REMEDIATION_PENDING: u8 = 0;
const REMEDIATION_EXECUTED: u8 = 1;

// ── Protocol mask bits (agent delegation) ─────────────────────────────────────

const PROTOCOL_BIT_TRANSFER: u64 = 1;
const PROTOCOL_BIT_ALLOCATE: u64 = 2;
const PROTOCOL_BIT_INVEST: u64 = 4;
const PROTOCOL_BIT_PAYROLL: u64 = 8;
const PROTOCOL_BIT_SUBSCRIPTION: u64 = 16;
const PROTOCOL_BIT_TREASURY: u64 = 32;
const PROTOCOL_BIT_REVENUE: u64 = 64;
const PROTOCOL_BIT_GUARDIAN: u64 = 128;

public fun protocol_bit_for_action(action: u8): u64 {
    if (action == ACTION_TRANSFER) {
        PROTOCOL_BIT_TRANSFER
    } else if (action == ACTION_ALLOCATE) {
        PROTOCOL_BIT_ALLOCATE
    } else if (action == ACTION_INVEST) {
        PROTOCOL_BIT_INVEST
    } else if (action == ACTION_PAYROLL) {
        PROTOCOL_BIT_PAYROLL
    } else if (action == ACTION_SUBSCRIPTION) {
        PROTOCOL_BIT_SUBSCRIPTION
    } else if (action == ACTION_TREASURY) {
        PROTOCOL_BIT_TREASURY
    } else if (action == ACTION_REVENUE_SPLIT) {
        PROTOCOL_BIT_REVENUE
    } else if (is_guardian_action(action)) {
        PROTOCOL_BIT_GUARDIAN
    } else {
        0
    }
}

/// Mandate statuses that permit workflow execution for the given action class.
public fun allows_workflow_status(status: u8, action: u8): bool {
    if (is_guardian_action(action)) {
        status == STATUS_ACTIVE
            || status == STATUS_WARNING
            || status == STATUS_RESTRICTED
            || status == STATUS_CRITICAL
    } else {
        status == STATUS_ACTIVE
    }
}

/// Validates guardian corrective action is executable from the current mandate status.
public fun assert_guardian_source_status(action: u8, status: u8) {
    if (action == ACTION_GUARDIAN_PAUSE) {
        assert!(
            status == STATUS_ACTIVE
                || status == STATUS_WARNING
                || status == STATUS_RESTRICTED
                || status == STATUS_CRITICAL,
            EInvalidMandateStatus,
        );
    } else if (action == ACTION_GUARDIAN_RESTRICT) {
        assert!(status == STATUS_ACTIVE || status == STATUS_WARNING, EInvalidMandateStatus);
    } else if (action == ACTION_GUARDIAN_REALLOCATE) {
        assert!(
            status == STATUS_ACTIVE
                || status == STATUS_WARNING
                || status == STATUS_RESTRICTED
                || status == STATUS_CRITICAL,
            EInvalidMandateStatus,
        );
    } else if (action == ACTION_GUARDIAN_ESCALATE) {
        assert!(
            status == STATUS_ACTIVE
                || status == STATUS_WARNING
                || status == STATUS_RESTRICTED,
            EInvalidMandateStatus,
        );
    };
}

/// Target mandate status after a guardian corrective action settles.
public fun guardian_target_status(action: u8, current: u8): u8 {
    if (action == ACTION_GUARDIAN_PAUSE) {
        STATUS_PAUSED
    } else if (action == ACTION_GUARDIAN_RESTRICT) {
        STATUS_RESTRICTED
    } else if (action == ACTION_GUARDIAN_REALLOCATE) {
        if (current == STATUS_CRITICAL || current == STATUS_RESTRICTED) {
            STATUS_WARNING
        } else if (current == STATUS_WARNING) {
            STATUS_ACTIVE
        } else {
            STATUS_ACTIVE
        }
    } else if (action == ACTION_GUARDIAN_ESCALATE) {
        if (current == STATUS_ACTIVE) {
            STATUS_WARNING
        } else {
            STATUS_CRITICAL
        }
    } else {
        current
    }
}

// ── Errors ──────────────────────────────────────────────────────────────────

const ENotAuthorized: u64 = 1;
const EInvalidMandateStatus: u64 = 2;
const ESpendingLimitExceeded: u64 = 3;
const ERecipientNotAllowed: u64 = 4;
const EInsufficientLiquidity: u64 = 5;
const EReserveViolation: u64 = 6;
const ETreasuryObligationUnmet: u64 = 7;
const ERiskThresholdExceeded: u64 = 8;
const EMandateExpired: u64 = 9;
const EExecutionConstraintViolation: u64 = 10;
const EInvalidMandateType: u64 = 11;
const EVaultMismatch: u64 = 12;
const EInvalidAmount: u64 = 13;
const EGovernanceQuorumNotMet: u64 = 14;
const EAllocationExceeds100: u64 = 15;
const EPayrollCycleViolation: u64 = 16;
const ESubscriptionNotDue: u64 = 17;
const EInvestmentBelowMinimum: u64 = 18;
const EObligationNotFound: u64 = 19;
const EConcentrationExceeded: u64 = 20;
const ECounterpartyRiskExceeded: u64 = 21;
const EStressModeActive: u64 = 22;
const EForecastStale: u64 = 23;
const EInsufficientMarketDepth: u64 = 24;
const ESlippageExceeded: u64 = 25;
const EVolatilityExceeded: u64 = 26;
const EForecastHookDisabled: u64 = 27;
const EWorkflowMismatch: u64 = 28;
const EUnauthorizedSettlement: u64 = 29;
const EOracleCapMismatch: u64 = 30;
const EInvalidIntentStatus: u64 = 31;
const ESimulationNotApproved: u64 = 32;
const ESimulationExpired: u64 = 33;
const ESimulationMismatch: u64 = 34;
const EDelegationExpired: u64 = 35;
const EDelegationScopeViolation: u64 = 36;
const ETemplateNotFound: u64 = 37;
const EGuardianActionInvalid: u64 = 38;
const EIntentAlreadyActivated: u64 = 39;
const EInvalidStateTransition: u64 = 40;
const EProtocolRestricted: u64 = 41;
const ERemediationMismatch: u64 = 42;

// ── Public accessors (Move 2024: constants are module-internal) ───────────
public fun mandate_treasury(): u8 { MANDATE_TREASURY }
public fun mandate_payroll(): u8 { MANDATE_PAYROLL }
public fun mandate_auto_investment(): u8 { MANDATE_AUTO_INVESTMENT }
public fun mandate_subscription(): u8 { MANDATE_SUBSCRIPTION }
public fun mandate_revenue_allocation(): u8 { MANDATE_REVENUE_ALLOCATION }
public fun mandate_dao_treasury(): u8 { MANDATE_DAO_TREASURY }
public fun status_active(): u8 { STATUS_ACTIVE }
public fun status_paused(): u8 { STATUS_PAUSED }
public fun status_expired(): u8 { STATUS_EXPIRED }
public fun status_revoked(): u8 { STATUS_REVOKED }
public fun status_restricted(): u8 { STATUS_RESTRICTED }
public fun status_warning(): u8 { STATUS_WARNING }
public fun status_critical(): u8 { STATUS_CRITICAL }
public fun intent_draft(): u8 { INTENT_DRAFT }
public fun intent_review(): u8 { INTENT_REVIEW }
public fun intent_approved(): u8 { INTENT_APPROVED }
public fun intent_compiled(): u8 { INTENT_COMPILED }
public fun intent_activated(): u8 { INTENT_ACTIVATED }
public fun role_owner(): u8 { ROLE_OWNER }
public fun role_executor(): u8 { ROLE_EXECUTOR }
public fun role_auditor(): u8 { ROLE_AUDITOR }
public fun role_governor(): u8 { ROLE_GOVERNOR }
public fun role_agent(): u8 { ROLE_AGENT }
public fun action_transfer(): u8 { ACTION_TRANSFER }
public fun action_allocate(): u8 { ACTION_ALLOCATE }
public fun action_invest(): u8 { ACTION_INVEST }
public fun action_payroll(): u8 { ACTION_PAYROLL }
public fun action_subscription(): u8 { ACTION_SUBSCRIPTION }
public fun action_treasury(): u8 { ACTION_TREASURY }
public fun action_revenue_split(): u8 { ACTION_REVENUE_SPLIT }
public fun action_guardian_pause(): u8 { ACTION_GUARDIAN_PAUSE }
public fun action_guardian_restrict(): u8 { ACTION_GUARDIAN_RESTRICT }
public fun action_guardian_reallocate(): u8 { ACTION_GUARDIAN_REALLOCATE }
public fun action_guardian_escalate(): u8 { ACTION_GUARDIAN_ESCALATE }
public fun guardian_auto_pause(): u8 { GUARDIAN_AUTO_PAUSE }
public fun guardian_auto_restrict(): u8 { GUARDIAN_AUTO_RESTRICT }
public fun guardian_auto_reallocate(): u8 { GUARDIAN_AUTO_REALLOCATE }
public fun guardian_auto_escalate(): u8 { GUARDIAN_AUTO_ESCALATE }
public fun trigger_obligation_violation(): u8 { TRIGGER_OBLIGATION_VIOLATION }
public fun trigger_liquidity_failure(): u8 { TRIGGER_LIQUIDITY_FAILURE }
public fun trigger_concentration_breach(): u8 { TRIGGER_CONCENTRATION_BREACH }
public fun trigger_stale_forecast(): u8 { TRIGGER_STALE_FORECAST }
public fun trigger_constitution_breach(): u8 { TRIGGER_CONSTITUTION_BREACH }
public fun template_startup_treasury(): u8 { TEMPLATE_STARTUP_TREASURY }
public fun template_dao_treasury(): u8 { TEMPLATE_DAO_TREASURY }
public fun template_payroll(): u8 { TEMPLATE_PAYROLL }
public fun template_subscription(): u8 { TEMPLATE_SUBSCRIPTION }
public fun template_revenue_routing(): u8 { TEMPLATE_REVENUE_ROUTING }
public fun template_auto_investment(): u8 { TEMPLATE_AUTO_INVESTMENT }
public fun remediation_pending(): u8 { REMEDIATION_PENDING }
public fun remediation_executed(): u8 { REMEDIATION_EXECUTED }
public fun protocol_bit_transfer(): u64 { PROTOCOL_BIT_TRANSFER }
public fun protocol_bit_allocate(): u64 { PROTOCOL_BIT_ALLOCATE }
public fun protocol_bit_invest(): u64 { PROTOCOL_BIT_INVEST }
public fun protocol_bit_payroll(): u64 { PROTOCOL_BIT_PAYROLL }
public fun protocol_bit_subscription(): u64 { PROTOCOL_BIT_SUBSCRIPTION }
public fun protocol_bit_treasury(): u64 { PROTOCOL_BIT_TREASURY }
public fun protocol_bit_revenue(): u64 { PROTOCOL_BIT_REVENUE }
public fun protocol_bit_guardian(): u64 { PROTOCOL_BIT_GUARDIAN }
public fun enot_authorized(): u64 { ENotAuthorized }
public fun einvalid_mandate_status(): u64 { EInvalidMandateStatus }
public fun espending_limit_exceeded(): u64 { ESpendingLimitExceeded }
public fun erecipient_not_allowed(): u64 { ERecipientNotAllowed }
public fun einsufficient_liquidity(): u64 { EInsufficientLiquidity }
public fun ereserve_violation(): u64 { EReserveViolation }
public fun etreasury_obligation_unmet(): u64 { ETreasuryObligationUnmet }
public fun erisk_threshold_exceeded(): u64 { ERiskThresholdExceeded }
public fun emandate_expired(): u64 { EMandateExpired }
public fun eexecution_constraint_violation(): u64 { EExecutionConstraintViolation }
public fun einvalid_mandate_type(): u64 { EInvalidMandateType }
public fun evault_mismatch(): u64 { EVaultMismatch }
public fun einvalid_amount(): u64 { EInvalidAmount }
public fun egovernance_quorum_not_met(): u64 { EGovernanceQuorumNotMet }
public fun eallocation_exceeds100(): u64 { EAllocationExceeds100 }
public fun epayroll_cycle_violation(): u64 { EPayrollCycleViolation }
public fun esubscription_not_due(): u64 { ESubscriptionNotDue }
public fun einvestment_below_minimum(): u64 { EInvestmentBelowMinimum }
public fun eobligation_not_found(): u64 { EObligationNotFound }
public fun econcentration_exceeded(): u64 { EConcentrationExceeded }
public fun ecounterparty_risk_exceeded(): u64 { ECounterpartyRiskExceeded }
public fun estress_mode_active(): u64 { EStressModeActive }
public fun eforecast_stale(): u64 { EForecastStale }
public fun einsufficient_market_depth(): u64 { EInsufficientMarketDepth }
public fun eslippage_exceeded(): u64 { ESlippageExceeded }
public fun evolatility_exceeded(): u64 { EVolatilityExceeded }
public fun eforecast_hook_disabled(): u64 { EForecastHookDisabled }
public fun eworkflow_mismatch(): u64 { EWorkflowMismatch }
public fun eunauthorized_settlement(): u64 { EUnauthorizedSettlement }
public fun eoracle_cap_mismatch(): u64 { EOracleCapMismatch }
public fun einvalid_intent_status(): u64 { EInvalidIntentStatus }
public fun esimulation_not_approved(): u64 { ESimulationNotApproved }
public fun esimulation_expired(): u64 { ESimulationExpired }
public fun esimulation_mismatch(): u64 { ESimulationMismatch }
public fun edelegation_expired(): u64 { EDelegationExpired }
public fun edelegation_scope_violation(): u64 { EDelegationScopeViolation }
public fun etemplate_not_found(): u64 { ETemplateNotFound }
public fun eguardian_action_invalid(): u64 { EGuardianActionInvalid }
public fun eintent_already_activated(): u64 { EIntentAlreadyActivated }
public fun einvalid_state_transition(): u64 { EInvalidStateTransition }
public fun eprotocol_restricted(): u64 { EProtocolRestricted }
public fun eremediation_mismatch(): u64 { ERemediationMismatch }
