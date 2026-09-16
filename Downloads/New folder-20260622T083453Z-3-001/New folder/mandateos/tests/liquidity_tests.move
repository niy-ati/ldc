#[test_only]
module mandateos::liquidity_tests;

use std::option;
use sui::test_scenario::{Self as ts};
use sui::clock::Clock;
use sui::sui::SUI;
use mandateos::test_helpers;
use mandateos::treasury_mandate::{Self, TreasuryConfig};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::{Self, ObligationRegistry};
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::{Self, LiquidityEngine};
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::vault::{Self, MandateVault};
use mandateos::delegation::{DailyExecutionTracker, ExecutorCap};
use mandateos::workflow::{Self, WorkflowSession};
use mandateos::simulation::SimulationApproval;
use mandateos::types;

#[test]
fun test_liquidity_rebalance_updates_buffer() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 1000);
    test_helpers::fund_treasury(&mut scenario, 1_000_000_000);

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

        assert!(adaptive_liquidity::total_required_buffer(&engine) == 0, 0);
        financial_mandate::rebalance_liquidity(
            &mandate, &constitution, &mut engine, &obligations, &forecast, &hook, &vault, &clock,
            ts::ctx(&mut scenario),
        );
        assert!(adaptive_liquidity::total_required_buffer(&engine) > 0, 1);

        ts::return_shared(mandate);
        ts::return_shared(constitution);
        ts::return_shared(obligations);
        ts::return_shared(engine);
        ts::return_shared(forecast);
        ts::return_shared(hook);
        ts::return_shared(vault);
        ts::return_shared(clock);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 5)]
fun test_insufficient_liquidity_blocks_settlement() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 0);
    test_helpers::fund_treasury(&mut scenario, 50_000_000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let mandate = ts::take_shared<FinancialMandate>(&scenario);
        let constitution = ts::take_shared<FinancialConstitution>(&scenario);
        let mut obligations = ts::take_shared<ObligationRegistry>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);

        financial_mandate::register_obligation(
            &mandate, &constitution, &mut obligations, objectives::obligation_payment(), test_helpers::recipient(),
            500_000_000, clock.timestamp_ms() + 86_400_000, 0, 1, ts::ctx(&mut scenario),
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
            types::action_treasury(), 10_000_000, test_helpers::recipient(), 0, &clock, ts::ctx(&mut scenario),
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
        test_helpers::attempt_treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut execution_tracker,
            approval, session, cap_opt, 10_000_000, test_helpers::recipient(), test_helpers::executor(),
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
fun test_liquid_balance_reflects_illiquid_allocation() {
    let mut scenario = ts::begin(test_helpers::owner());
    test_helpers::init_treasury_scenario(&mut scenario, 0);
    test_helpers::fund_treasury(&mut scenario, 100_000_000);

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        assert!(vault::balance_value(&vault) == 100_000_000, 0);
        assert!(vault::liquid_balance_after_debit(&vault, 0) == 100_000_000, 1);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}
