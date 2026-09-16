# EXECUTION_AUDIT

**Generated:** 2026-06-21T08:24:47.284Z
**Active package:** `0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13`

| Action | Move Function | Digest | Timestamp | Owner | Object Changes | Events | Status |
|--------|---------------|--------|-----------|-------|----------------|--------|--------|
| Package Upgrade | sui::upgrade | [`6vzEqvHNQWLA6BSTfreiT1YdET5XwSf7XnGkwdN6kGsb`](https://suiscan.xyz/testnet/tx/6vzEqvHNQWLA6BSTfreiT1YdET5XwSf7XnGkwdN6kGsb) | 2026-06-21T06:42:32.780Z | 0xd0de6a0c… | 3 | 0 | VERIFIED |
| Fund wallet from governor | sui::transfer | [`26arjby2trikNNyWJJqAvTCJppqWRDjZ5FThdZ8zV23m`](https://suiscan.xyz/testnet/tx/26arjby2trikNNyWJJqAvTCJppqWRDjZ5FThdZ8zV23m) | 2026-06-21T08:23:55.535Z | 0xd0de6a0c… | 3 | 0 | VERIFIED |
| Create Treasury — Wallet A | treasury_mandate::create + share_all | [`8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL`](https://suiscan.xyz/testnet/tx/8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL) | 2026-06-21T08:23:55.678Z | 0x02bcebcf… | 14 | 2 | VERIFIED |
| Fund wallet from governor | sui::transfer | [`BE1HYTg6RgoJtkgjkWSWF93qPz3J8Kt1taoHwgYutAZ`](https://suiscan.xyz/testnet/tx/BE1HYTg6RgoJtkgjkWSWF93qPz3J8Kt1taoHwgYutAZ) | 2026-06-21T08:24:01.216Z | 0xd0de6a0c… | 2 | 0 | VERIFIED |
| Create Treasury — Wallet B | treasury_mandate::create + share_all | [`zVcVG2k8X2qUbPPAu3PGDpJ3JfvobRqsFv5fytJQZvq`](https://suiscan.xyz/testnet/tx/zVcVG2k8X2qUbPPAu3PGDpJ3JfvobRqsFv5fytJQZvq) | 2026-06-21T08:24:01.706Z | 0x70688d82… | 14 | 2 | VERIFIED |
| Fund Treasury | treasury_mandate::fund | [`3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX`](https://suiscan.xyz/testnet/tx/3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX) | 2026-06-21T08:24:03.993Z | 0x02bcebcf… | 2 | 1 | VERIFIED |
| Evaluate Guardian | guardian::evaluate + share_evaluation | [`4m9S1RhMMbn3DypHUF8Q7QEVYRHvt4GpcmjzohQZv7T7`](https://suiscan.xyz/testnet/tx/4m9S1RhMMbn3DypHUF8Q7QEVYRHvt4GpcmjzohQZv7T7) | 2026-06-21T08:24:06.092Z | 0x02bcebcf… | 2 | 1 | VERIFIED |
| Create Obligation | financial_mandate::register_obligation | [`2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ`](https://suiscan.xyz/testnet/tx/2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ) | 2026-06-21T08:24:08.310Z | 0x02bcebcf… | 2 | 1 | VERIFIED |
| Authorize Treasury Payment (PTB) | financial_mandate::simulate_and_approve | [`6rzs1ypLteygUQjqw6wv3aR8CTQDy9Vr6HWgB17KKyyN`](https://suiscan.xyz/testnet/tx/6rzs1ypLteygUQjqw6wv3aR8CTQDy9Vr6HWgB17KKyyN) | 2026-06-21T08:24:10.487Z | 0x02bcebcf… | 5 | 0 | VERIFIED |
| Execute Treasury Payment | treasury_mandate::treasury_disbursement | [`9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9`](https://suiscan.xyz/testnet/tx/9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9) | 2026-06-21T08:24:13.948Z | 0x02bcebcf… | 14 | 2 | VERIFIED |
| Create Payroll Mandate | payroll_mandate::create + share_all | [`6c5qZUgZkyubbqgmCvv91EximFVAetp41ADGzXVWtroc`](https://suiscan.xyz/testnet/tx/6c5qZUgZkyubbqgmCvv91EximFVAetp41ADGzXVWtroc) | 2026-06-21T08:24:17.504Z | 0x70688d82… | 14 | 2 | VERIFIED |
| Fund Payroll Vault | payroll_mandate::fund | [`EkvXDGM8eHvHbE9YLPTh1fGbsTSUNDbBCzVCq3qWmd29`](https://suiscan.xyz/testnet/tx/EkvXDGM8eHvHbE9YLPTh1fGbsTSUNDbBCzVCq3qWmd29) | 2026-06-21T08:24:19.692Z | 0x70688d82… | 2 | 1 | VERIFIED |
| Simulate Payroll | financial_mandate::simulate_and_approve | [`9aZw9ZV6zjaZY3Xd6xk2GEX8cTC4TU2SKeQGDFdGwujK`](https://suiscan.xyz/testnet/tx/9aZw9ZV6zjaZY3Xd6xk2GEX8cTC4TU2SKeQGDFdGwujK) | 2026-06-21T08:24:21.427Z | 0x70688d82… | 5 | 0 | VERIFIED |
| Execute Payroll | payroll_mandate::run_payroll | [`Hm3MRXjJ7fTFTBRnS9jumGn497NM6mpMUJbmKdH5RbiU`](https://suiscan.xyz/testnet/tx/Hm3MRXjJ7fTFTBRnS9jumGn497NM6mpMUJbmKdH5RbiU) | 2026-06-21T08:24:25.042Z | 0x70688d82… | 16 | 3 | VERIFIED |
| Create Revenue Mandate | revenue_allocation_mandate::create + share_all | [`5ubysM95F18JaUARgGrx1xGbQ7G6uqeZDEqf9hCU9dmC`](https://suiscan.xyz/testnet/tx/5ubysM95F18JaUARgGrx1xGbQ7G6uqeZDEqf9hCU9dmC) | 2026-06-21T08:24:26.639Z | 0x70688d82… | 14 | 2 | VERIFIED |
| Fund Revenue Vault | revenue_allocation_mandate::fund | [`G1mZ1aMZHJXtA95Qao4YdQkuF7TQg1ThikYmsZD2vnzW`](https://suiscan.xyz/testnet/tx/G1mZ1aMZHJXtA95Qao4YdQkuF7TQg1ThikYmsZD2vnzW) | 2026-06-21T08:24:28.743Z | 0x70688d82… | 2 | 1 | VERIFIED |
| Simulate Revenue Distribution | financial_mandate::simulate_and_approve | [`7vsmSoDmgcmdBtc8ig3T3JRq86EuEYe4RkHtPD6JL1td`](https://suiscan.xyz/testnet/tx/7vsmSoDmgcmdBtc8ig3T3JRq86EuEYe4RkHtPD6JL1td) | 2026-06-21T08:24:32.718Z | 0x70688d82… | 5 | 0 | VERIFIED |
| Execute Revenue Distribution | revenue_allocation_mandate::distribute | [`6J1b2SGHC65p66hK1QBDYxy4aJfd2UNjMAKtGqHTHR2x`](https://suiscan.xyz/testnet/tx/6J1b2SGHC65p66hK1QBDYxy4aJfd2UNjMAKtGqHTHR2x) | 2026-06-21T08:24:34.843Z | 0x70688d82… | 15 | 3 | VERIFIED |
| Create Investment Mandate | auto_investment_mandate::create + share_all | [`EBY5LNhB6zvgV6bPFgcmqAqE31YF17d5CSB4zbGMF462`](https://suiscan.xyz/testnet/tx/EBY5LNhB6zvgV6bPFgcmqAqE31YF17d5CSB4zbGMF462) | 2026-06-21T08:24:37.151Z | 0x70688d82… | 14 | 2 | VERIFIED |
| Fund Investment Vault | auto_investment_mandate::fund | [`DSaHaxfuiyvj2nMjLwXaJtGYyZ1rtJyPJQRqu6BsVuAf`](https://suiscan.xyz/testnet/tx/DSaHaxfuiyvj2nMjLwXaJtGYyZ1rtJyPJQRqu6BsVuAf) | 2026-06-21T08:24:40.327Z | 0x70688d82… | 2 | 1 | VERIFIED |
| Simulate Investment | financial_mandate::simulate_and_approve | [`91pA73NfZY6r97mvaJuZwncFJq2yhjdDYyVxt6ziJ8ap`](https://suiscan.xyz/testnet/tx/91pA73NfZY6r97mvaJuZwncFJq2yhjdDYyVxt6ziJ8ap) | 2026-06-21T08:24:43.995Z | 0x70688d82… | 5 | 0 | VERIFIED |
| Execute Investment | auto_investment_mandate::execute_investment | [`8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo`](https://suiscan.xyz/testnet/tx/8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo) | 2026-06-21T08:24:47.280Z | 0x70688d82… | 15 | 2 | VERIFIED |

## Phase 2 treasury verification

- **Create Treasury — Wallet A:** VERIFIED — [`Age51HzRe8kkTRXHGKLv3WzJQis5eTLAp8NJaik9a4wP`](https://suiscan.xyz/testnet/tx/Age51HzRe8kkTRXHGKLv3WzJQis5eTLAp8NJaik9a4wP)
- **Create Treasury — Wallet B:** VERIFIED

- **Fund Treasury:** VERIFIED
- **Create Obligation:** VERIFIED
- **Authorize Treasury Payment (PTB):** VERIFIED
- **Execute Treasury Payment:** VERIFIED
- **Create Payroll Mandate:** VERIFIED
- **Fund Payroll Vault:** VERIFIED
- **Simulate Payroll:** VERIFIED
- **Execute Payroll:** VERIFIED
- **Create Revenue Mandate:** VERIFIED
- **Fund Revenue Vault:** VERIFIED
- **Simulate Revenue Distribution:** VERIFIED
- **Execute Revenue Distribution:** VERIFIED
- **Create Investment Mandate:** VERIFIED
- **Fund Investment Vault:** VERIFIED
- **Simulate Investment:** VERIFIED
- **Execute Investment:** VERIFIED
- **Evaluate Guardian:** VERIFIED

**All recorded actions VERIFIED on-chain**
