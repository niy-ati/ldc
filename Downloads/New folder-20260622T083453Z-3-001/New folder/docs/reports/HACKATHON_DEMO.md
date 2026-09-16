# MandateOS — Hackathon Demo Script (5 minutes)

## Setup (before judges arrive)

1. Open [Command Center](http://localhost:5173) — `npm run dev:cc` from repo root.
2. Confirm green **LIVE TESTNET** banner and vault balance ~0.15 SUI on mandate `0x0537…e5ed`.
3. Keep Suiscan tabs ready:
   - [Package](https://suiscan.xyz/testnet/object/0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713)
   - [Create treasury tx](https://suiscan.xyz/testnet/tx/aq4tnkazAA7XmjefBofi6G1KtWPuFmLXhyK3HJ85MpQ)
   - [Simulate + approve tx](https://suiscan.xyz/testnet/tx/GBESgwHnd7gvAgVnYg5RCe4PzSAQvErQ45n72FPtYhHa)

## Beat 1 — Problem (30s)

> "Treasury and agent systems move money with keys and scripts. MandateOS replaces that with **on-chain financial mandates**: constitution, simulation, guardian policy, and receipts — all verifiable on Sui testnet."

## Beat 2 — Architecture (45s)

Show `proof/DIAGRAMS.md` architecture diagram. Emphasize:

- **Frozen Move package** `0x96e7…3713` (26 modules, all SDK targets verified)
- **PTB shim** `0x6214…a00b` composes simulation inside Move (required because `FinancialObjectives` cannot cross PTB commands)
- **Command Center** reads live shared objects via `MandateOSReader`

## Beat 3 — Live mandate (60s)

Command Center → **Overview**

- Package ID matches deployment
- Vault: 150M MIST funded ([fund tx](https://suiscan.xyz/testnet/tx/C9TBmhgSA6BHnUYHq78bj4GE23RuH9asexhAgovWMDvh))
- Guardian policy + mandate status ACTIVE

**Capital** tab → ALMM buckets  
**Objectives** tab → preservation / 90-day runway / 10% reserve covenant

## Beat 4 — Simulation gate (60s)

Open [simulate tx](https://suiscan.xyz/testnet/tx/GBESgwHnd7gvAgVnYg5RCe4PzSAQvErQ45n72FPtYhHa):

- `simulate_and_approve` via PTB shim
- Shared `ProjectedOutcome` + `SimulationSession`
- Owned `SimulationApproval` transferred to executor role

> "No disbursement without governor-approved simulation. This is the constitutional gate."

## Beat 5 — Execute + agent (60s)

If full proof completed (`proof/testnet-results.json` without `partial`):

- Show treasury execute tx + `FinancialReceipt`
- Show delegated payment success (30M) and rejection (100M > cap)

Otherwise narrate from `AGENT_DEMO.md` and run:

```powershell
$env:MANDATEOS_PACKAGE_ID='0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713'
$env:MANDATEOS_PTB_SHIM_PACKAGE_ID='0x62148461af79d28034bee14c7300fe873d878eab11cc92d3bd869eefc8c7a00b'
npm run testnet:proof
```

## Beat 6 — Guardian (45s)

**Guardian** tab → AUTO_RESTRICT policy thresholds  
Show guardian evaluate + restrict flow from `GUARDIAN_DEMO.md` or live proof txs.

## Beat 7 — Close (30s)

- All demos link to Suiscan — no mocked balances in live mode
- Move contracts unchanged since publish; shim is additive infrastructure only
- `proof/entrypoint-verification.json` — 20/20 SDK targets present on-chain

## Q&A cheat sheet

| Question | Answer |
|----------|--------|
| Why a PTB shim? | Sui PTBs cannot pass `&FinancialObjectives` across commands; shim composes simulation in one Move call |
| Who can execute? | Separate governor + executor roles; agent uses `ExecutorCap` |
| Upgrade path? | `UpgradeCap` held by deployer; package ID unchanged |
