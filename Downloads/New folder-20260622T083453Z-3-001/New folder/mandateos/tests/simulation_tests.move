#[test_only]
module mandateos::simulation_tests;

use std::option;
use sui::test_scenario::{Self as ts};
use sui::clock::Clock;
use sui::sui::SUI;
use mandateos::test_helpers;
use mandateos::financial_mandate::FinancialMandate;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::ObligationRegistry;
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::vault::MandateVault;
use mandateos::simulation::{Self, SimulationSession, SimulationApproval, ProjectedOutcome};
use mandateos::workflow::{Self, WorkflowSession};
use mandateos::types;

#[test]
fun test_simulation_projection_completes() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 1_000_000_000);

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
            types::action_treasury(), 100_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
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

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let sim = ts::take_shared<SimulationSession>(&scenario);
        let outcome = ts::take_shared<ProjectedOutcome>(&scenario);
        assert!(simulation::simulation_id(&sim) == simulation::outcome_simulation_id(&outcome), 0);
        assert!(simulation::outcome_approved(&outcome), 1);
        ts::return_shared(sim);
        ts::return_shared(outcome);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 34)]
fun test_simulation_approval_action_mismatch_rejected() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 500_000_000);

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

        let mut approval = test_helpers::simulate_and_approve(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            types::action_treasury(), 100_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
        );

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        test_helpers::attempt_workflow_approval_mismatch(
            approval,
            session,
            &mandate,
            &constitution,
            &mut risk,
            &obligations,
            &engine,
            &forecast,
            &hook,
            &vault,
            &clock,
            120_000_000,
            test_helpers::executor(),
        );

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

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 32)]
fun test_consumed_simulation_approval_rejected() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 500_000_000);

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

        let mut approval = test_helpers::simulate_and_approve(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            types::action_treasury(), 50_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
        );

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let mut approval = test_helpers::consume_approval_via_workflow(
            approval,
            session,
            &mandate,
            &constitution,
            &mut risk,
            &obligations,
            &engine,
            &forecast,
            &hook,
            &vault,
            &clock,
            50_000_000,
        );

        let mut session2 = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        test_helpers::attempt_reuse_consumed_approval_workflow(
            approval,
            session2,
            &mandate,
            &constitution,
            &mut risk,
            &obligations,
            &engine,
            &forecast,
            &hook,
            &vault,
            &clock,
            50_000_000,
            test_helpers::executor(),
        );

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

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1)]
fun test_simulation_approval_requires_governor() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 100_000_000);

    ts::next_tx(&mut scenario, test_helpers::executor());
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

        let mut sim = simulation::open_simulation(
            object::id(&mandate), types::action_treasury(), 10_000_000, test_helpers::recipient(), 0, &clock,
            ts::ctx(&mut scenario),
        );
        let mut outcome = simulation::run_projection(
            &mut sim, object::id(&mandate), mandateos::financial_mandate::status(&mandate),
            &constitution, &mut risk, &engine, &obligations,
            mandateos::financial_mandate::objectives(&mandate), &forecast, &hook, &vault, test_helpers::executor(),
            &clock, ts::ctx(&mut scenario),
        );
        test_helpers::attempt_approve_simulation(
            sim, outcome, &constitution, &clock, ts::ctx(&mut scenario),
        );

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

    ts::end(scenario);
}
