#[test_only]
module mandateos::mandate_tests;

use std::option;
use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use mandateos::mandateos;
use mandateos::treasury_mandate::{Self, TreasuryConfig};
use mandateos::payroll_mandate::{Self, PayrollConfig, PayrollEntry};
use mandateos::financial_mandate::{Self, FinancialMandate};
use mandateos::constitutional::FinancialConstitution;
use mandateos::objectives::ObligationRegistry;
use mandateos::operational_risk::OperationalRiskProfile;
use mandateos::adaptive_liquidity::LiquidityEngine;
use mandateos::deepbook_forecast::{MarketForecast, DeepBookHook};
use mandateos::vault::{Self, MandateVault};
use mandateos::workflow::{Self, WorkflowSession};
use mandateos::simulation::{Self, SimulationSession, ProjectedOutcome, SimulationApproval};
use mandateos::intent::{Self, IntentObject};
use mandateos::intent_compiler;
use mandateos::templates::{Self, MandateTemplate, TemplateRegistry};
use mandateos::delegation::{Self, ExecutorCap, DailyExecutionTracker};
use mandateos::types;
use mandateos::receipts;
use mandateos::test_helpers;

const OWNER: address = @0xA11CE;
const EXECUTOR: address = @0xB0B;
const RECIPIENT: address = @0xCAFE;
const AGENT: address = @0xDEAD;

fun simulate_and_approve_treasury(
    mandate: &FinancialMandate,
    constitution: &FinancialConstitution,
    risk: &mut OperationalRiskProfile,
    engine: &LiquidityEngine,
    obligations: &ObligationRegistry,
    forecast: &MarketForecast,
    hook: &DeepBookHook,
    vault: &MandateVault<SUI>,
    amount: u64,
    recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
): SimulationApproval {
    let mut sim = simulation::open_simulation(
        object::id(mandate),
        types::action_treasury(),
        amount,
        recipient,
        0,
        clock,
        ctx,
    );
    let mut outcome = simulation::run_projection(
        &mut sim,
        object::id(mandate),
        financial_mandate::status(mandate),
        constitution,
        risk,
        engine,
        obligations,
        financial_mandate::objectives(mandate),
        forecast,
        hook,
        vault,
        EXECUTOR,
        clock,
        ctx,
    );
    let approval = simulation::approve_simulation(&mut outcome, constitution, clock, ctx);
    simulation::share_outcome(outcome);
    simulation::share_session(sim);
    approval
}

#[test]
fun test_treasury_os_pipeline() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                test_helpers::owner(),
                test_helpers::executor(),
                10_000_000_000,
                1_000_000_000,
                10_000_000_000,
                1000,
                500,
                test_helpers::recipient(),
                2,
                &clock,
                ts::ctx(&mut scenario),
            );
        treasury_mandate::share_all(mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config);
        clock::share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let coin = coin::mint_for_testing<SUI>(5_000_000_000, ts::ctx(&mut scenario));
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        treasury_mandate::fund(&mut vault, coin);
        ts::return_shared(vault);
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

        let approval = simulate_and_approve_treasury(
            &mandate,
            &constitution,
            &mut risk,
            &engine,
            &obligations,
            &forecast,
            &hook,
            &vault,
            500_000_000,
            test_helpers::recipient(),
            &clock,
            ts::ctx(&mut scenario),
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
            &mut mandate,
            &mut constitution,
            &mut risk,
            &mut engine,
            &mut obligations,
            &forecast,
            &hook,
            &config,
            &mut vault,
            &mut session,
            &mut execution_tracker,
            &mut approval,
            &cap_opt,
            500_000_000,
            test_helpers::recipient(),
            &clock,
            ts::ctx(&mut scenario),
        );

        assert!(receipts::financial_receipt_mandate_id(&receipt) == object::id(&mandate), 0);
        assert!(vault::balance_value(&vault) == 4_500_000_000, 1);

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
fun test_intent_compile_activate() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let registry = ts::take_shared<TemplateRegistry>(&scenario);
        let mut template = ts::take_shared<MandateTemplate>(&scenario);
        while (templates::template_id(&template) != types::template_startup_treasury()) {
            ts::return_shared(template);
            template = ts::take_shared<MandateTemplate>(&scenario);
        };
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));

        let intent_template = intent::intent_template_from_mandate_template(&template);
        let inputs = intent::inputs_from_template(
            &template,
            test_helpers::owner(),
            test_helpers::executor(),
            1_000_000_000,
            10_000_000_000,
            5_000_000_000,
            b"startup-treasury-intent",
        );
        let mut intent = intent::draft_intent(intent_template, inputs, clock.timestamp_ms(), ts::ctx(&mut scenario));
        intent::submit_for_review(&mut intent, ts::ctx(&mut scenario));
        intent::approve_intent(&mut intent, test_helpers::owner(), ts::ctx(&mut scenario));

        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker) =
            intent_compiler::compile<SUI>(&mut intent, &template, &clock, ts::ctx(&mut scenario));
        intent_compiler::activate(
            &mut intent,
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
        );

        intent::share_intent(intent);
        clock::share_for_testing(clock);
        ts::return_shared(template);
        ts::return_shared(registry);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let intent = ts::take_shared<IntentObject>(&scenario);
        assert!(intent::status(&intent) == types::intent_activated(), 1);
        ts::return_shared(intent);
    };

    ts::end(scenario);
}

#[test]
fun test_agent_executor_cap() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                test_helpers::owner(), test_helpers::executor(), 1_000_000_000, 500_000_000, 5_000_000_000, 1000, 0, test_helpers::recipient(), 1, &clock,
                ts::ctx(&mut scenario),
            );
        let mandate_id = object::id(&mandate);
        let authority = delegation::agent_authority(
            mandate_id,
            test_helpers::agent(),
            clock.timestamp_ms() + 86_400_000,
            200_000_000,
            1_000_000_000,
            vector[types::action_treasury()],
            32,
        );
        let executor_cap = delegation::issue_executor_cap(&delegation_cap, &constitution, authority, ts::ctx(&mut scenario));
        delegation::transfer_executor_cap(executor_cap, test_helpers::agent());
        treasury_mandate::share_all(mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config);
        clock::share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let coin = coin::mint_for_testing<SUI>(1_000_000_000, ts::ctx(&mut scenario));
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        treasury_mandate::fund(&mut vault, coin);
        ts::return_shared(vault);
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

        let approval = simulate_and_approve_treasury(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            100_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
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
        let receipt = treasury_mandate::treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut session, &mut execution_tracker, &mut approval,
            &cap_opt, 100_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
        );
        test_helpers::consume_receipt(receipt, test_helpers::executor());
        test_helpers::finish_settlement_with_cap(approval, session, cap_opt, test_helpers::executor(), &mut scenario);

        assert!(vault::balance_value(&vault) == 900_000_000, 0);

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
fun test_payroll_fulfills_obligation() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let employees = vector[payroll_mandate::new_payroll_entry(RECIPIENT, 100_000_000)];
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            payroll_mandate::create<SUI>(test_helpers::owner(), test_helpers::executor(), 500_000_000, 0, employees, &clock, ts::ctx(&mut scenario));
        payroll_mandate::share_all(mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config);
        clock::share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let coin = coin::mint_for_testing<SUI>(1_000_000_000, ts::ctx(&mut scenario));
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        payroll_mandate::fund(&mut vault, coin);
        ts::return_shared(vault);
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

        let mut sim = simulation::open_simulation(
            object::id(&mandate), types::action_payroll(), 100_000_000, test_helpers::recipient(), 1, &clock, ts::ctx(&mut scenario),
        );
        let mut outcome = simulation::run_projection(
            &mut sim, object::id(&mandate), financial_mandate::status(&mandate), &constitution, &mut risk, &engine,
            &obligations, financial_mandate::objectives(&mandate), &forecast, &hook, &vault, test_helpers::executor(), &clock,
            ts::ctx(&mut scenario),
        );
        let approval = simulation::approve_simulation(&mut outcome, &constitution, &clock, ts::ctx(&mut scenario));
        simulation::share_outcome(outcome);
        simulation::share_session(sim);
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
        let mut config = ts::take_shared<PayrollConfig>(&scenario);
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        let mut execution_tracker = ts::take_shared<DailyExecutionTracker>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let mut approval = ts::take_from_sender<SimulationApproval>(&scenario);
        let cap_opt = option::none<ExecutorCap>();

        let mut session = workflow::open_session(object::id(&mandate), &clock, ts::ctx(&mut scenario));
        let receipt = payroll_mandate::run_payroll(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &mut config, &mut vault, &mut session, &mut execution_tracker, &mut approval,
            &cap_opt, 0, &clock, ts::ctx(&mut scenario),
        );
        test_helpers::consume_receipt(receipt, test_helpers::executor());
        test_helpers::finish_settlement_tx(approval, session, cap_opt, test_helpers::executor());

        assert!(vault::balance_value(&vault) == 900_000_000, 0);

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
#[expected_failure(abort_code = 3)]
fun test_constitutional_spending_limit() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                test_helpers::owner(), test_helpers::executor(), 1_000_000_000, 100_000_000, 500_000_000, 1000, 0, test_helpers::recipient(), 1, &clock,
                ts::ctx(&mut scenario),
            );
        treasury_mandate::share_all(mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config);
        clock::share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let coin = coin::mint_for_testing<SUI>(1_000_000_000, ts::ctx(&mut scenario));
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        treasury_mandate::fund(&mut vault, coin);
        ts::return_shared(vault);
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

        let approval = simulate_and_approve_treasury(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            200_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
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
            approval, session, cap_opt, 200_000_000, test_helpers::recipient(), test_helpers::executor(),
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
#[expected_failure(abort_code = 36)]
fun test_agent_daily_limit_exceeded() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                test_helpers::owner(), test_helpers::executor(), 1_000_000_000, 500_000_000, 5_000_000_000, 1000, 0, test_helpers::recipient(), 1, &clock,
                ts::ctx(&mut scenario),
            );
        let mandate_id = object::id(&mandate);
        let authority = delegation::agent_authority(
            mandate_id,
            test_helpers::agent(),
            clock.timestamp_ms() + 86_400_000,
            200_000_000,
            150_000_000,
            vector[types::action_treasury()],
            32,
        );
        let executor_cap = delegation::issue_executor_cap(&delegation_cap, &constitution, authority, ts::ctx(&mut scenario));
        delegation::transfer_executor_cap(executor_cap, test_helpers::agent());
        treasury_mandate::share_all(mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config);
        clock::share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let coin = coin::mint_for_testing<SUI>(1_000_000_000, ts::ctx(&mut scenario));
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        treasury_mandate::fund(&mut vault, coin);
        ts::return_shared(vault);
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

        let approval = simulate_and_approve_treasury(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            100_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
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
        let receipt = treasury_mandate::treasury_disbursement(
            &mut mandate, &mut constitution, &mut risk, &mut engine, &mut obligations,
            &forecast, &hook, &config, &mut vault, &mut session, &mut execution_tracker, &mut approval,
            &cap_opt, 100_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
        );
        test_helpers::consume_receipt(receipt, test_helpers::executor());
        test_helpers::finish_settlement_with_cap(approval, session, cap_opt, test_helpers::executor(), &mut scenario);
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

        let approval = simulate_and_approve_treasury(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            100_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
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
#[expected_failure(abort_code = 41)]
fun test_agent_protocol_mask_rejected() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config) =
            treasury_mandate::create<SUI>(
                test_helpers::owner(), test_helpers::executor(), 1_000_000_000, 500_000_000, 5_000_000_000, 1000, 0, test_helpers::recipient(), 1, &clock,
                ts::ctx(&mut scenario),
            );
        let mandate_id = object::id(&mandate);
        let authority = delegation::agent_authority(
            mandate_id,
            test_helpers::agent(),
            clock.timestamp_ms() + 86_400_000,
            200_000_000,
            1_000_000_000,
            vector[types::action_treasury()],
            8,
        );
        let executor_cap = delegation::issue_executor_cap(&delegation_cap, &constitution, authority, ts::ctx(&mut scenario));
        delegation::transfer_executor_cap(executor_cap, test_helpers::agent());
        treasury_mandate::share_all(mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, execution_tracker, config);
        clock::share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let coin = coin::mint_for_testing<SUI>(1_000_000_000, ts::ctx(&mut scenario));
        let mut vault = ts::take_shared<MandateVault<SUI>>(&scenario);
        treasury_mandate::fund(&mut vault, coin);
        ts::return_shared(vault);
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

        let approval = simulate_and_approve_treasury(
            &mandate, &constitution, &mut risk, &engine, &obligations, &forecast, &hook, &vault,
            100_000_000, test_helpers::recipient(), &clock, ts::ctx(&mut scenario),
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
