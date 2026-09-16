# DEFI CHAIN VERIFIED REPORT

**Generated:** 2026-06-21T10:28:28.628Z
**Overall:** CODE_EXISTS
**Verification method:** Wallet-signed Slush transactions via production UI — no private keys
**Reference wallet:** 0xa23a99091b2765ce9c07b7f6c75858518b949e27c9a22d01a754d0ad9914c749
**Proof source:** —
**Bridge:** BLOCKED — DeFi integrations must all be CHAIN_VERIFIED first

See `DEFI_WALLET_VERIFICATION_FLOW.md` for the exact production UI steps.

| Integration | Required | Status |
|-------------|----------|--------|
| Navi | deposit + withdraw + position + portfolio reconcile | CODE_EXISTS |
| Scallop | deposit + withdraw + position + portfolio reconcile | CODE_EXISTS |
| Cetus | add + remove + LP position + portfolio reconcile | CODE_EXISTS |
| Allocation | treasury split + protocol deposits + final portfolio | CODE_EXISTS |

## Navi

- Deposit: — (—)
- Withdraw: — (—)
- Portfolio reconciliation: CODE_EXISTS

## Scallop

- Deposit: — (—)
- Withdraw: — (—)
- Portfolio reconciliation: CODE_EXISTS

## Cetus

- Add liquidity: — (—)
- Remove liquidity: — (—)
- Portfolio reconciliation: CODE_EXISTS

## Allocation (40% Navi / 40% Scallop / 20% Cetus)

- Treasury split: — (CODE_EXISTS)
- Navi deposit: — (CODE_EXISTS)
- Scallop deposit: — (CODE_EXISTS)
- Cetus deposit: — (CODE_EXISTS)
- Final portfolio: CODE_EXISTS

## Export verification (after UI flow)

```bash
npm run defi:chain-verify -- --wallet=0xYOUR_WALLET --proof=proof/proof.json
```

## Blockers

- No proof.json found — export from Proof Center after completing Slush-signed DeFi transactions
- Navi: complete production UI flow and export proof.json
- Scallop: complete production UI flow and export proof.json
- Cetus: complete production UI flow and export proof.json
- Export proof.json from Proof Center after Slush-signed transactions
