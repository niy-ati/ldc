# FINAL JUDGE DEMO

**Generated:** 2026-06-21T08:24:47.564Z
**Production URL:** https://command-center-five-eta.vercel.app
**Package:** `0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13`
**Slush test wallet (reference):** `0xf6472cc0e5ce9f56e22619c0bc12b8c789fe2fe0c8d2be3f7f0f13eadd91e768`

## Production-only path (no CLI, no admin, no /demo sandbox)

| Step | Route | Action | Chain evidence |
|------|-------|--------|----------------|
| 1 | Connect Slush | Authorize origin | Wallet address on explorer |
| 2 | `/app/account` | Create Treasury | Digest in wallet tx list |
| 3 | `/app/account` | Fund vault | `treasury_mandate::fund` digest |
| 4 | `/obligations` | Register obligation | `register_obligation` digest |
| 5 | `/app/account` | Simulate + Execute payment | PTB simulate + execute digests |
| 6 | Sui Explorer | Verify object + balance changes | Independent verification |
| 7 | `/app/portfolio` | Vault + wallet balances from RPC | Matches explorer |
| 8 | `/proof` | Transaction proof panel | Same digests as explorer |

## UI verification record

- **NOT VERIFIED** — no digests in `proof/ui-judge-demo.json` (browser judge run pending)

## CLI cross-check (reference only — not part of judge demo)

- Create Treasury — Wallet A: [`8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL`](https://suiscan.xyz/testnet/tx/8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL)
- Fund Treasury: [`3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX`](https://suiscan.xyz/testnet/tx/3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX)
- Create Obligation: [`2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ`](https://suiscan.xyz/testnet/tx/2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ)
- Execute Treasury Payment: [`9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9`](https://suiscan.xyz/testnet/tx/9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9)


## Gate status

- `VITE_UPGRADE_VERIFIED=true` required for PTB buttons (upgrade digest verified on-chain)
- `VITE_MANDATEOS_PACKAGE_ID=0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13`
