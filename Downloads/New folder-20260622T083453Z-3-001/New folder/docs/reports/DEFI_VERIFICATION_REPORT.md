# DEFI VERIFICATION REPORT

**Generated:** 2026-06-21T09:41:25.896Z
**Overall:** NOT VERIFIED

Allowed states: **CHAIN_VERIFIED** | **NOT VERIFIED** only. No digest → NOT VERIFIED.

## Requirement matrix

| Feature | Required evidence | Status |
|---------|-------------------|--------|
| Navi | deposit + withdraw + position digests | NOT VERIFIED |
| Scallop | deposit + withdraw + position digests | NOT VERIFIED |
| Cetus | add + remove + LP position digests | NOT VERIFIED |
| Allocation | treasury + protocol digests + portfolio reconcile | NOT VERIFIED |
| Programmable chains | all step digests + portfolio | NOT VERIFIED |
| Smart wallet rules | upgrade + create + execute + workflow digests | NOT VERIFIED |

## navi

| Classification | NOT VERIFIED |


**Blockers:**
- MANDATEOS_MAINNET_KEY not set

## scallop

| Classification | NOT VERIFIED |


**Blockers:**
- MANDATEOS_MAINNET_KEY not set

## cetus

| Classification | NOT VERIFIED |


**Blockers:**
- MANDATEOS_MAINNET_KEY not set

## allocation

| Classification | NOT VERIFIED |


**Blockers:**
- MANDATEOS_MAINNET_KEY not set

## programmableChains

| Classification | NOT VERIFIED |

- revenueExecute: 6J1b2SGHC65p66hK1QBDYxy4aJfd2UNjMAKtGqHTHR2x (CHAIN_VERIFIED)
- investmentExecute: 8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo (CHAIN_VERIFIED)
- naviDeposit: — (NOT VERIFIED) — Not executed

**Blockers:**
- Mainnet Navi deposit digest missing — chain spans testnet MandateOS + mainnet DeFi
- No single orchestrated programmable chain run with final portfolio snapshot

## smartWalletRules

| Classification | NOT VERIFIED |

- packageUpgrade: Ecx13xVKC8rRmWM2NU5CkbjftcjjtZkmUSDovqZU9YJf (NOT VERIFIED)
- ruleCreate: — (NOT VERIFIED)
- ruleExecute: — (NOT VERIFIED)
- workflowProof: 8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo (CHAIN_VERIFIED)

**Blockers:**
- Error executing transaction 'Ecx13xVKC8rRmWM2NU5CkbjftcjjtZkmUSDovqZU9YJf': InsufficientGas
- Upgrade on-chain status: failure — InsufficientGas
- smart_wallet_rules module not on-chain — upgrade required before rule creation

## Mainnet blocker

Set `MANDATEOS_MAINNET_KEY` (suiprivkey…) and re-run:

```
npm run build:sdk && npx tsx scripts/run-defi-verification-sprint.ts
```
