# MandateOS — Judge Walkthrough

## What to verify (2 minutes)

### 1. Package is live

| Artifact | Link |
|----------|------|
| MandateOS package | [0x96e7…3713](https://suiscan.xyz/testnet/object/0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713) |
| Publish tx | [GHfrSjC…](https://suiscan.xyz/testnet/tx/GHfrSjCwEWq4GESHgGc8Y6UQeGuKmQXZnB9GSVt6vsCJ) |
| Entrypoint report | `proof/entrypoint-verification.json` — **allSdkTargetsPresent: true** |

### 2. Proof transactions (on-chain)

| Step | Explorer |
|------|----------|
| Create treasury mandate | [aq4tnkaz…](https://suiscan.xyz/testnet/tx/aq4tnkazAA7XmjefBofi6G1KtWPuFmLXhyK3HJ85MpQ) |
| Fund vault (150M MIST) | [C9TBmhg…](https://suiscan.xyz/testnet/tx/C9TBmhgSA6BHnUYHq78bj4GE23RuH9asexhAgovWMDvh) |
| Simulate + approve (30M disburse) | [GBESgwH…](https://suiscan.xyz/testnet/tx/GBESgwHnd7gvAgVnYg5RCe4PzSAQvErQ45n72FPtYhHa) |
| PTB shim publish | [9dE1h3…](https://suiscan.xyz/testnet/tx/9dE1h3ukxeoMWahFaLAMUdPWHCW5zssB3y1adB164u4o) |

### 3. Live object graph

| Object | ID |
|--------|-----|
| FinancialMandate | `0x0537293ee980082cc55c2a623ce243a78b34f897b7b422e6aa83545ad556e5ed` |
| MandateVault (150M MIST) | `0x862c4b7cfd5988e55d5f72b7dfc8ab797895831f3ec97a48268ff004a0b8594f` |
| SimulationApproval (pending execute) | `0xf20bc84dbff1a5b39c4b2b076c0da98572541571bca2c2db78739c44f173e318` |

### 4. Command Center (live mode)

```powershell
npm run dev:cc
```

Configured via `packages/command-center/.env.local` — reads on-chain state, no demo mocks.

## Design decisions judges should notice

1. **Simulation before execution** — `SimulationApproval` is consumed by `treasury_disbursement`; governor must approve projections first.
2. **Role separation** — Governor (`0xd0de…e10b`) ≠ executor (ephemeral role holder per proof run).
3. **Agent delegation** — `ExecutorCap` enforces per-tx and daily limits without sharing owner keys.
4. **Guardian** — `AUTO_RESTRICT` triggers when concentration / liquidity thresholds breach policy.
5. **PTB shim** — Additive package `0x6214…a00b`; MandateOS bytecode untouched.

## Reproduce full proof

```powershell
# Fund governor to >= 0.25 SUI via https://faucet.sui.io
$env:MANDATEOS_PACKAGE_ID='0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713'
$env:MANDATEOS_PTB_SHIM_PACKAGE_ID='0x62148461af79d28034bee14c7300fe873d878eab11cc92d3bd869eefc8c7a00b'
npm run build:sdk
npm run testnet:proof
npm run testnet:docs
npm run testnet:verify
```

## Diagrams

See `proof/DIAGRAMS.md` for architecture, object graph, and PTB execution flow.
