#[test_only]
module mandateos::bootstrap_tests;

use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use sui::sui::SUI;
use mandateos::mandateos;
use mandateos::test_helpers;
use mandateos::treasury_mandate;
use mandateos::payroll_mandate::{Self, PayrollEntry};
use mandateos::subscription_mandate;
use mandateos::auto_investment_mandate::{Self, InvestmentTarget};
use mandateos::revenue_allocation_mandate::{Self, AllocationRecipient};
use mandateos::dao_treasury_mandate;

#[test]
fun test_bootstrap_treasury_canonical_graph() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, tracker, config) =
            treasury_mandate::create<SUI>(test_helpers::owner(), test_helpers::executor(), 1_000_000_000, 100_000_000, 500_000_000, 1000, 0, test_helpers::recipient(), 1, &clock, ts::ctx(&mut scenario));
        test_helpers::assert_canonical_graph(
            &mandate, &vault, &constitution, &obligations, &risk, &engine, &forecast, &hook,
            &guardian, &delegation_cap, &tracker,
        );
        treasury_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, tracker, config,
        );
        clock::share_for_testing(clock);
    };
    ts::end(scenario);
}

#[test]
fun test_bootstrap_payroll_canonical_graph() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let employees = vector[payroll_mandate::new_payroll_entry(test_helpers::recipient(), 50_000_000)];
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, tracker, config) =
            payroll_mandate::create<SUI>(test_helpers::owner(), test_helpers::executor(), 100_000_000, 0, employees, &clock, ts::ctx(&mut scenario));
        test_helpers::assert_canonical_graph(
            &mandate, &vault, &constitution, &obligations, &risk, &engine, &forecast, &hook,
            &guardian, &delegation_cap, &tracker,
        );
        payroll_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, tracker, config,
        );
        clock::share_for_testing(clock);
    };
    ts::end(scenario);
}

#[test]
fun test_bootstrap_subscription_canonical_graph() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, tracker, config) =
            subscription_mandate::create<SUI>(test_helpers::owner(), test_helpers::executor(), test_helpers::recipient(), 10_000_000, 2_592_000_000, 12, true, &clock, ts::ctx(&mut scenario));
        test_helpers::assert_canonical_graph(
            &mandate, &vault, &constitution, &obligations, &risk, &engine, &forecast, &hook,
            &guardian, &delegation_cap, &tracker,
        );
        subscription_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, tracker, config,
        );
        clock::share_for_testing(clock);
    };
    ts::end(scenario);
}

#[test]
fun test_bootstrap_auto_investment_canonical_graph() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let targets = vector[auto_investment_mandate::new_investment_target(1, 10000, 1_000_000)];
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, tracker, config) =
            auto_investment_mandate::create<SUI>(test_helpers::owner(), test_helpers::executor(), 50_000_000, 2_592_000_000, targets, &clock, ts::ctx(&mut scenario));
        test_helpers::assert_canonical_graph(
            &mandate, &vault, &constitution, &obligations, &risk, &engine, &forecast, &hook,
            &guardian, &delegation_cap, &tracker,
        );
        auto_investment_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, tracker, config,
        );
        clock::share_for_testing(clock);
    };
    ts::end(scenario);
}

#[test]
fun test_bootstrap_revenue_allocation_canonical_graph() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let recipients = vector[
            revenue_allocation_mandate::new_allocation_recipient(test_helpers::recipient(), 6000),
            revenue_allocation_mandate::new_allocation_recipient(test_helpers::executor(), 4000),
        ];
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, tracker, config) =
            revenue_allocation_mandate::create<SUI>(test_helpers::owner(), test_helpers::executor(), recipients, 1_000_000, &clock, ts::ctx(&mut scenario));
        test_helpers::assert_canonical_graph(
            &mandate, &vault, &constitution, &obligations, &risk, &engine, &forecast, &hook,
            &guardian, &delegation_cap, &tracker,
        );
        revenue_allocation_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, tracker, config,
        );
        clock::share_for_testing(clock);
    };
    ts::end(scenario);
}

#[test]
fun test_bootstrap_dao_treasury_canonical_graph() {
    let mut scenario = ts::begin(test_helpers::owner());
    mandateos::init_for_testing(ts::ctx(&mut scenario));
    ts::next_tx(&mut scenario, test_helpers::owner());
    {
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let governors = vector[test_helpers::executor(), test_helpers::recipient()];
        let (mandate, vault, constitution, obligations, risk, engine, forecast, hook, oracle_cap, guardian, delegation_cap, tracker, config) =
            dao_treasury_mandate::create<SUI>(test_helpers::owner(), governors, 2, 100_000_000, 1_000_000_000, 604_800_000, &clock, ts::ctx(&mut scenario));
        test_helpers::assert_canonical_graph(
            &mandate, &vault, &constitution, &obligations, &risk, &engine, &forecast, &hook,
            &guardian, &delegation_cap, &tracker,
        );
        dao_treasury_mandate::share_all(
            mandate, vault, constitution, obligations, risk, engine, forecast, hook,
            oracle_cap, guardian, delegation_cap, tracker, config,
        );
        clock::share_for_testing(clock);
    };
    ts::end(scenario);
}
