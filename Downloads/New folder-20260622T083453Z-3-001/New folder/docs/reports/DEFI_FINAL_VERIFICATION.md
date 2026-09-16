# DEFI FINAL VERIFICATION

**Generated:** 2026-06-21T10:05:31.871Z
**Overall verification:** CODE_EXISTS
**Bridge implementation:** BLOCKED until all items CHAIN_VERIFIED

States: **CODE_EXISTS** (wired, no chain proof) | **CHAIN_VERIFIED** | **NOT VERIFIED** (partial/failed).

## Gate matrix

| # | Integration | Required evidence | Status |
|---|-------------|-------------------|--------|
| Navi | deposit + withdraw + position + portfolio reconcile | CODE_EXISTS |
| Scallop | deposit + withdraw + position + portfolio reconcile | CODE_EXISTS |
| Cetus | add + remove + LP position + portfolio reconcile | CODE_EXISTS |
| Allocation | treasury digest + destination digests + aggregated portfolio | CODE_EXISTS |
| Smart wallet rules | upgrade + create + execute + workflow digests | CHAIN_VERIFIED |

## navi

| Implementation | CODE_EXISTS |
| Verification | CODE_EXISTS |

- Portfolio reconciliation: CODE_EXISTS

**Blockers:**
- Navi: integration wired in SDK/UI — no mainnet execution (set MANDATEOS_MAINNET_KEY)

## scallop

| Implementation | CODE_EXISTS |
| Verification | CODE_EXISTS |

- Portfolio reconciliation: CODE_EXISTS

**Blockers:**
- Scallop: integration wired in SDK/UI — no mainnet execution (set MANDATEOS_MAINNET_KEY)

## cetus

| Implementation | CODE_EXISTS |
| Verification | CODE_EXISTS |

- Portfolio reconciliation: CODE_EXISTS

**Blockers:**
- Cetus: integration wired in SDK/UI — no mainnet execution (set MANDATEOS_MAINNET_KEY)

## allocation

| Implementation | CODE_EXISTS |
| Verification | CODE_EXISTS |

- Treasury allocation: — (CODE_EXISTS)
- Destination navi: — (CODE_EXISTS)
- Destination scallop: — (CODE_EXISTS)
- Destination cetus: — (CODE_EXISTS)
- Aggregated portfolio: CODE_EXISTS

**Blockers:**
- Set MANDATEOS_MAINNET_KEY and run multi-protocol allocation on mainnet

## smartWalletRules

| Implementation | CODE_EXISTS |
| Verification | CHAIN_VERIFIED |

- Package upgrade: EP8bcDkioXZ66cxiE4HA6iVVNg4Xr6z6JPdqvAtHBXrt (CHAIN_VERIFIED)
- Rule create: 7AT2EGgGxvUQ9qDQRCWThjqkYtivrhh2wUJxZ4jkxSXk (CHAIN_VERIFIED)
- Rule execute: CjLHsD9hGy1SMw7NfJFxkkMWVkNzmLqVc1qZYEu4gke6 (CHAIN_VERIFIED)
- Workflow digest: 8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo (CHAIN_VERIFIED)

**Blockers:**
- Satellite rules package published — MandateOS monolithic upgrade blocked (InsufficientGas on full package)

## Mainnet execution

Set `MANDATEOS_MAINNET_KEY` and re-run:

```
npm run defi:verify-final
```

## Bridge policy

Bridge work is **blocked** until every row above is **CHAIN_VERIFIED**.
When implemented, bridge must integrate into programmable capital deployment workflows — not as a standalone feature.
