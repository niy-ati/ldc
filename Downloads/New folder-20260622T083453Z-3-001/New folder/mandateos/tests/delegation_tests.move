#[test_only]
module mandateos::delegation_tests;

use std::option;
use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use sui::sui::SUI;
use mandateos::mandateos;
use mandateos::test_helpers;
use mandateos::treasury_mandate::{Self, TreasuryConfig};
use mandateos::financial_mandate::FinancialMandate;
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::ObligationRegistry;
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::vault::MandateVault;
use mandateos::delegation::{Self, ExecutorCap, DelegationCap, DailyExecutionTracker};
use mandateos::workflow::{Self, WorkflowSession};
use mandateos::simulation::SimulationApproval;
use mandateos::types;

fun setup_agent_cap(scenario: &mut ts::Scenario, max_per_tx: u64, max_daily: u64, protocol_mask: u64) {
    ts::next_tx(scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                test_helpers::owner(), test_helpers::executor(), 1_000_000_000, max_per_tx * 2, max_daily, 1000, 0, test_helpers::recipient(), 1,
                &clock, ts::ctx(scenario),
            );
        let mandate_id = object::id(&mandate);
        let authority = delegation::agent_authority(
            mandate_id, test_helpers::agent(), clock.timestamp_ms() + 86_400_000, max_per_tx, max_daily,
            vector[types::action_treasury()], protocol_mask,
        );
        let executor_cap = delegation::issue_executor_cap(&delegation_cap, &constitution, authority, ts::ctx(scenario));
        delegation::transfer_executor_cap(executor_cap, test_helpers::agent());
        treasury_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, execution_tracker, config,
        );
        clock::share_for_testing(clock);
    };
    test_helpers::fund_treasury(scenario, 1_000_000_000);
}

#[test]
#[expected_failure(abort_code = 36)]
fun test_agent_max_per_tx_exceeded() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    setup_agent_cap(&mut scenario, 50_000_000, 500_000_000, 32);

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
        test_helpers::transfer_approval(approval, test_helpers::agent());
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

    ts::next_tx(&mut scenario, test_helpers::agent());
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
        let executor_cap = ts::take_from_sender<ExecutorCap>(&scenario);
        let mut cap_opt = option::some(executor_cap);

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        test_helpers::attempt_treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut execution_tracker,
            approval, session, cap_opt, 100_000_000, test_helpers::recipient(), test_helpers::executor(),
            &clock, ts::ctx(&mut scenario),
        );
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
#[expected_failure(abort_code = 1)]
fun test_agent_wrong_sender_rejected() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    setup_agent_cap(&mut scenario, 200_000_000, 500_000_000, 32);

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
            types::action_treasury(), 50_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::transfer_approval(approval, test_helpers::intruder());
        let executor_cap = ts::take_from_address<ExecutorCap>(&scenario, test_helpers::agent());
        delegation::transfer_executor_cap(executor_cap, test_helpers::intruder());
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

    ts::next_tx(&mut scenario, test_helpers::intruder());
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
        let executor_cap = ts::take_from_sender<ExecutorCap>(&scenario);
        let mut cap_opt = option::some(executor_cap);

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        test_helpers::attempt_treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut execution_tracker,
            approval, session, cap_opt, 50_000_000, test_helpers::recipient(), test_helpers::executor(),
            &clock, ts::ctx(&mut scenario),
        );
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
#[expected_failure(abort_code = 35)]
fun test_agent_expired_cap_rejected() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                test_helpers::owner(), test_helpers::executor(), 1_000_000_000, 500_000_000, 1_000_000_000, 1000, 0, test_helpers::recipient(), 1,
                &clock, ts::ctx(&mut scenario),
            );
        let mandate_id = object::id(&mandate);
        let authority = delegation::agent_authority(
            mandate_id, test_helpers::agent(), clock.timestamp_ms() + 1_000, 200_000_000, 1_000_000_000,
            vector[types::action_treasury()], 32,
        );
        let executor_cap = delegation::issue_executor_cap(&delegation_cap, &constitution, authority, ts::ctx(&mut scenario));
        delegation::transfer_executor_cap(executor_cap, test_helpers::agent());
        treasury_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, execution_tracker, config,
        );
        clock::share_for_testing(clock);
    };
    test_helpers::fund_treasury(&mut scenario, 500_000_000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mut clock = ts::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, 5_000);
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
        let approval = test_helpers::simulate_and_approve(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            types::action_treasury(), 50_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::transfer_approval(approval, test_helpers::agent());
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

    ts::next_tx(&mut scenario, test_helpers::agent());
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
        let executor_cap = ts::take_from_sender<ExecutorCap>(&scenario);
        let mut cap_opt = option::some(executor_cap);

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        test_helpers::attempt_treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut execution_tracker,
            approval, session, cap_opt, 50_000_000, test_helpers::recipient(), test_helpers::executor(),
            &clock, ts::ctx(&mut scenario),
        );
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
fun test_delegation_cap_matches_mandate() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let delegation_cap = ts::take_from_sender<DelegationCap>(&scenario);
        assert!(delegation::cap_mandate_id(&delegation_cap) == object::id(&mandate), 0);
        delegation::transfer_delegation_cap(delegation_cap, test_helpers::owner());
        ts::return_shared(mandate);
    };

    ts::end(scenario);
}
