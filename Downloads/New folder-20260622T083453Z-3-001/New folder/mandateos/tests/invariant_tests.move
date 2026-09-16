#[test_only]
module mandateos::invariant_tests;

use std::option;
use sui::test_scenario::{Self as ts};
use sui::clock::Clock;
use sui::sui::SUI;
use mandateos::test_helpers;
use mandateos::treasury_mandate::{Self, TreasuryConfig};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::ObligationRegistry;
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::vault::{Self, MandateVault};
use mandateos::delegation::{DailyExecutionTracker, ExecutorCap};
use mandateos::workflow::{Self, WorkflowSession};
use mandateos::simulation::SimulationApproval;
use mandateos::types;
use mandateos::guardian::{Self, GuardianPolicy, GuardianAction, GuardianRemediationPlan};

#[test]
fun test_invariant_workflow_reaches_authorized_before_settle() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 300_000_000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut risk = ts::take_shared<OperationalRiskProfile>(&scenario);
        let engine = ts::take_shared<LiquidityEngine>(&scenario);
        let obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let approval = test_helpers::simulate_and_approve(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            types::action_treasury(), 25_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::transfer_approval(approval, test_helpers::executor());
        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(risk);
        ts::return_shared(engine);
        ts::return_shared(obligations);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(vault);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::executor());
    {
        let mut mandate = ts::take_shared<FinancialMandate>(&scenario);
        let mut constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let mut risk = ts::take_shared<OperationalRiskProfile>(&scenario);
        let mut engine = ts::take_shared<LiquidityEngine>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let config = ts::take_shared<TreasuryConfig>(&scenario);
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let mut execution_tracker = ts::take_shared<DailyExecutionTracker>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let mut approval = ts::take_from_sender<SimulationApproval>(&scenario);
        let cap_opt = option::none<ExecutorCap>();

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let receipt = treasury_mandate::treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut session, &mut execution_tracker, &mut approval,
            &cap_opt, 25_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
        );
        test_helpers::consume_receipt(receipt, test_helpers::executor());
        test_helpers::finish_settlement_tx(approval, session, cap_opt, test_helpers::executor());

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(risk);
        ts::return_shared(engine);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(config);
        ts::return_shared(vault);
        ts::return_shared(execution_tracker);
        ts::return_shared(clock);
    };

    ts::end(scenario);
}

#[test]
fun test_invariant_settlement_debits_exact_amount() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 200_000_000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut risk = ts::take_shared<OperationalRiskProfile>(&scenario);
        let engine = ts::take_shared<LiquidityEngine>(&scenario);
        let obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let approval = test_helpers::simulate_and_approve(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            types::action_treasury(), 30_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::transfer_approval(approval, test_helpers::executor());
        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(risk);
        ts::return_shared(engine);
        ts::return_shared(obligations);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(vault);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::executor());
    {
        let mut mandate = ts::take_shared<FinancialMandate>(&scenario);
        let mut constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let mut risk = ts::take_shared<OperationalRiskProfile>(&scenario);
        let mut engine = ts::take_shared<LiquidityEngine>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let config = ts::take_shared<TreasuryConfig>(&scenario);
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let mut execution_tracker = ts::take_shared<DailyExecutionTracker>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let mut approval = ts::take_from_sender<SimulationApproval>(&scenario);
        let cap_opt = option::none<ExecutorCap>();

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let receipt = treasury_mandate::treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut session, &mut execution_tracker, &mut approval,
            &cap_opt, 30_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
        );
        test_helpers::consume_receipt(receipt, test_helpers::executor());
        assert!(vault::balance_value(&vault) == 170_000_000, 0);
        assert!(financial_mandate::total_volume(&mandate) == 30_000_000, 1);
        test_helpers::finish_settlement_tx(approval, session, cap_opt, test_helpers::executor());

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(risk);
        ts::return_shared(engine);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(config);
        ts::return_shared(vault);
        ts::return_shared(execution_tracker);
        ts::return_shared(clock);
    };

    ts::end(scenario);
}

#[test]
fun test_invariant_guardian_restrict_does_not_debit_vault() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 400_000_000);

    ts::next_tx(&mut scenario, test_helpers::executor());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let risk = ts::take_shared<OperationalRiskProfile>(&scenario);
        let engine = ts::take_shared<LiquidityEngine>(&scenario);
        let obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let guardian = ts::take_shared<GuardianPolicy>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);

        let (action_opt, plan_opt) = guardian::evaluate(
            &guardian, &mandate, &constitution, &obligations, &risk, &engine, &forecast, &vault,
            &clock, ts::ctx(&mut scenario),
        );
        guardian::share_action(option::destroy_some(action_opt));
        if (option::is_some(&plan_opt)) {
            guardian::share_remediation_plan(option::destroy_some(plan_opt));
        } else {
            option::destroy_none(plan_opt);
        };

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(risk);
        ts::return_shared(engine);
        ts::return_shared(obligations);
        ts::return_shared(forecast);
        ts::return_shared(vault);
        ts::return_shared(guardian);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut risk = ts::take_shared<OperationalRiskProfile>(&scenario);
        let engine = ts::take_shared<LiquidityEngine>(&scenario);
        let obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let approval = test_helpers::simulate_and_approve_guardian(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            types::action_guardian_restrict(), &clock, ts::ctx(&mut scenario),
        );
        test_helpers::transfer_approval(approval, test_helpers::executor());
        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(risk);
        ts::return_shared(engine);
        ts::return_shared(obligations);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(vault);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::executor());
    {
        let mut mandate = ts::take_shared<FinancialMandate>(&scenario);
        let mut constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let mut risk = ts::take_shared<OperationalRiskProfile>(&scenario);
        let mut engine = ts::take_shared<LiquidityEngine>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let guardian = ts::take_shared<GuardianPolicy>(&scenario);
        let mut execution_tracker = ts::take_shared<DailyExecutionTracker>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let mut action = ts::take_shared<GuardianAction>(&scenario);
        let mut approval = ts::take_from_sender<SimulationApproval>(&scenario);
        let mut plan_opt = option::none<GuardianRemediationPlan>();

        let balance_before = vault::balance_value(&vault);
        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let action_receipt = guardian::execute_action(
            &mut action, &mut plan_opt, &guardian, &mut mandate, &mut constitution, &mut risk,
            &mut engine, &mut obligations, &forecast, &hook, &mut vault, &mut session,
            &mut execution_tracker, &mut approval, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::finish_guardian_action_tx(approval, session, action_receipt, test_helpers::executor());
        test_helpers::dispose_plan_opt(plan_opt);
        assert!(vault::balance_value(&vault) == balance_before, 0);

        ts::return_shared(action);
        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(risk);
        ts::return_shared(engine);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(vault);
        ts::return_shared(guardian);
        ts::return_shared(execution_tracker);
        ts::return_shared(clock);
    };

    ts::end(scenario);
}

#[test]
fun test_invariant_types_guardian_state_transitions() {
    assert!(types::allows_workflow_status(types::status_restricted(), types::action_guardian_pause()), 0);
    assert!(types::allows_workflow_status(types::status_critical(), types::action_guardian_reallocate()), 1);
    assert!(!types::allows_workflow_status(types::status_paused(), types::action_treasury()), 2);
    assert!(types::guardian_target_status(types::action_guardian_pause(), types::status_restricted()) == types::status_paused(), 3);
    assert!(types::guardian_target_status(types::action_guardian_restrict(), types::status_active()) == types::status_restricted(), 4);
}
