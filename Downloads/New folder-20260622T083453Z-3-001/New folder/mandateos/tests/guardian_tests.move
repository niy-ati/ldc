#[test_only]
module mandateos::guardian_tests;

use std::option;
use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use mandateos::test_helpers;
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::constitutional::FinancialConstitution;
use mandateos::treasury_mandate::{Self, TreasuryConfig};
use mandateos::objectives::{Self, ObligationRegistry};
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::{Self, LiquidityEngine};
use mandateos::deepbook_forecast::MarketForecast;
use mandateos::deepbook_forecast::DeepBookHook;
use mandateos::vault::{Self, MandateVault};
use mandateos::guardian::{Self, GuardianPolicy, GuardianAction, GuardianRemediationPlan};
use mandateos::delegation::{DailyExecutionTracker, ExecutorCap};
use mandateos::workflow::{Self, WorkflowSession};
use mandateos::simulation::SimulationApproval;
use mandateos::types;
use sui::sui::SUI;

#[test]
fun test_guardian_evaluate_concentration_triggers_restrict() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 1_000_000_000);

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
        assert!(option::is_some(&action_opt), 0);
        assert!(option::is_none(&plan_opt), 1);
        let action = option::destroy_some(action_opt);
        test_helpers::assert_guardian_action_kind(&action, types::guardian_auto_restrict());
        guardian::share_action(action);
        option::destroy_none(plan_opt);

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

    ts::end(scenario);
}

#[test]
fun test_guardian_execute_restrict_sets_restricted_status() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 500_000_000);

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
        test_helpers::share_guardian_evaluation(action_opt, plan_opt);
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

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let action_receipt = guardian::execute_action(
            &mut action, &mut plan_opt, &guardian, &mut mandate, &mut constitution, &mut risk,
            &mut engine, &mut obligations, &forecast, &hook, &mut vault, &mut session,
            &mut execution_tracker, &mut approval, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::finish_guardian_action_tx(approval, session, action_receipt, test_helpers::executor());
        test_helpers::dispose_plan_opt(plan_opt);

        assert!(financial_mandate::status(&mandate) == types::status_restricted(), 0);
        assert!(vault::balance_value(&vault) == 500_000_000, 1);

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
fun test_guardian_pause_from_restricted_with_overdue() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 500_000_000);

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
        test_helpers::share_guardian_evaluation(action_opt, plan_opt);

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

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let action_receipt = guardian::execute_action(
            &mut action, &mut plan_opt, &guardian, &mut mandate, &mut constitution, &mut risk,
            &mut engine, &mut obligations, &forecast, &hook, &mut vault, &mut session,
            &mut execution_tracker, &mut approval, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::finish_guardian_action_tx(approval, session, action_receipt, test_helpers::executor());
        test_helpers::dispose_plan_opt(plan_opt);
        assert!(financial_mandate::status(&mandate) == types::status_restricted(), 0);

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

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mut clock = ts::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, 10_000);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);

        financial_mandate::register_obligation(
            &mandate,
            &constitution,
            &mut obligations,
            objectives::obligation_payment(),
            test_helpers::recipient(),
            50_000_000,
            1,
            0,
            1,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(clock);
    };

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
        let action = option::destroy_some(action_opt);
        test_helpers::assert_guardian_action_kind(&action, types::guardian_auto_pause());
        guardian::share_action(action);
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
            types::action_guardian_pause(), &clock, ts::ctx(&mut scenario),
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

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let action_receipt = guardian::execute_action(
            &mut action, &mut plan_opt, &guardian, &mut mandate, &mut constitution, &mut risk,
            &mut engine, &mut obligations, &forecast, &hook, &mut vault, &mut session,
            &mut execution_tracker, &mut approval, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::finish_guardian_action_tx(approval, session, action_receipt, test_helpers::executor());
        test_helpers::dispose_plan_opt(plan_opt);
        assert!(financial_mandate::status(&mandate) == types::status_paused(), 0);

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
fun test_guardian_evaluate_liquidity_creates_remediation_plan() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 0);
    test_helpers::fund_treasury(&mut scenario, 10_000_000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);

        financial_mandate::register_obligation(
            &mandate,
            &constitution,
            &mut obligations,
            objectives::obligation_payment(),
            test_helpers::recipient(),
            500_000_000,
            clock.timestamp_ms() + 86_400_000,
            0,
            1,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::executor());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let mut engine = ts::take_shared<LiquidityEngine>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);

        financial_mandate::rebalance_liquidity(
            &mandate, &constitution, &mut engine, &obligations, &forecast, &hook, &vault, &clock,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(engine);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(vault);
        ts::return_shared(clock);
    };

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

        assert!(adaptive_liquidity::total_required_buffer(&engine) > 0, 1);

        let (action_opt, plan_opt) = guardian::evaluate(
            &guardian, &mandate, &constitution, &obligations, &risk, &engine, &forecast, &vault,
            &clock, ts::ctx(&mut scenario),
        );
        assert!(option::is_some(&action_opt), 2);
        assert!(option::is_some(&plan_opt), 3);
        let action = option::destroy_some(action_opt);
        let plan = option::destroy_some(plan_opt);
        test_helpers::assert_guardian_action_kind(&action, types::guardian_auto_reallocate());
        test_helpers::assert_plan_linked_to_mandate(&plan, object::id(&mandate));
        guardian::share_action(action);
        guardian::share_remediation_plan(plan);

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

    ts::end(scenario);
}

#[test]
fun test_guardian_reallocate_preserves_vault_balance() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 0);
    test_helpers::fund_treasury(&mut scenario, 10_000_000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);

        financial_mandate::register_obligation(
            &mandate,
            &constitution,
            &mut obligations,
            objectives::obligation_payment(),
            test_helpers::recipient(),
            500_000_000,
            clock.timestamp_ms() + 86_400_000,
            0,
            1,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::executor());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let mut engine = ts::take_shared<LiquidityEngine>(&scenario);
        let forecast = ts::take_shared<MarketForecast>(&scenario);
        let hook = ts::take_shared<DeepBookHook>(&scenario);
        let vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);

        financial_mandate::rebalance_liquidity(
            &mandate, &constitution, &mut engine, &obligations, &forecast, &hook, &vault, &clock,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(engine);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(vault);
        ts::return_shared(clock);
    };

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
        assert!(option::is_some(&action_opt), 0);
        assert!(option::is_some(&plan_opt), 1);
        test_helpers::share_guardian_evaluation(action_opt, plan_opt);

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
            types::action_guardian_reallocate(), &clock, ts::ctx(&mut scenario),
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
        let plan = ts::take_shared<GuardianRemediationPlan>(&scenario);
        let mut plan_opt = option::some(plan);
        let mut approval = ts::take_from_sender<SimulationApproval>(&scenario);

        let balance_before = vault::balance_value(&vault);
        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let action_receipt = guardian::execute_action(
            &mut action, &mut plan_opt, &guardian, &mut mandate, &mut constitution,
            &mut risk, &mut engine, &mut obligations, &forecast, &hook, &mut vault, &mut session,
            &mut execution_tracker, &mut approval, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::finish_guardian_action_tx(approval, session, action_receipt, test_helpers::executor());
        assert!(vault::balance_value(&vault) == balance_before, 0);

        ts::return_shared(action);
        test_helpers::dispose_plan_opt(plan_opt);
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
fun test_guardian_escalate_on_stale_forecast() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mut clock = ts::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, 8_000_000);
        ts::return_shared(clock);
    };

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
        assert!(option::is_some(&action_opt), 0);
        assert!(option::is_none(&plan_opt), 1);
        let action = option::destroy_some(action_opt);
        test_helpers::assert_guardian_action_kind(&action, types::guardian_auto_escalate());
        guardian::share_action(action);
        option::destroy_none(plan_opt);

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

    ts::end(scenario);
}

#[test]
fun test_share_evaluation_drops_empty_options() {
    guardian::share_evaluation(
        option::none<GuardianAction>(),
        option::none<GuardianRemediationPlan>(),
    );
}

#[test]
fun test_share_evaluation_shares_liquidity_trigger() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 0);
    test_helpers::fund_treasury(&mut scenario, 10_000_000);

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
        assert!(option::is_some(&action_opt), 0);
        guardian::share_evaluation(action_opt, plan_opt);

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

    ts::end(scenario);
}

#[test]
fun test_discard_evaluation_drops_triggered_objects() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 0);
    test_helpers::fund_treasury(&mut scenario, 10_000_000);

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
        assert!(option::is_some(&action_opt), 0);
        guardian::discard_evaluation(action_opt, plan_opt);

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

    ts::end(scenario);
}
