# JUDGE FLOW

**Generated:** 2026-06-21T08:24:47.285Z
**Package:** `0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13`

## Production path

1. Connect wallet → `/app/account`
2. Create Treasury
3. Fund vault
4. View objectives → `/objectives`
5. Register obligation → `/obligations`
6. Simulate + Execute payment
7. Verify digest → `/proof`
8. Portfolio → `/app/portfolio`

## CLI proof (chain evidence)

1. **Package Upgrade** — [`6vzEqvHNQWLA6BSTfreiT1YdET5XwSf7XnGkwdN6kGsb`](https://suiscan.xyz/testnet/tx/6vzEqvHNQWLA6BSTfreiT1YdET5XwSf7XnGkwdN6kGsb) owner `0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b`
2. **Fund wallet from governor** — [`26arjby2trikNNyWJJqAvTCJppqWRDjZ5FThdZ8zV23m`](https://suiscan.xyz/testnet/tx/26arjby2trikNNyWJJqAvTCJppqWRDjZ5FThdZ8zV23m) owner `0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b`
3. **Create Treasury — Wallet A** — [`8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL`](https://suiscan.xyz/testnet/tx/8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL) owner `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
4. **Fund wallet from governor** — [`BE1HYTg6RgoJtkgjkWSWF93qPz3J8Kt1taoHwgYutAZ`](https://suiscan.xyz/testnet/tx/BE1HYTg6RgoJtkgjkWSWF93qPz3J8Kt1taoHwgYutAZ) owner `0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b`
5. **Create Treasury — Wallet B** — [`zVcVG2k8X2qUbPPAu3PGDpJ3JfvobRqsFv5fytJQZvq`](https://suiscan.xyz/testnet/tx/zVcVG2k8X2qUbPPAu3PGDpJ3JfvobRqsFv5fytJQZvq) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
6. **Fund Treasury** — [`3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX`](https://suiscan.xyz/testnet/tx/3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX) owner `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
7. **Evaluate Guardian** — [`4m9S1RhMMbn3DypHUF8Q7QEVYRHvt4GpcmjzohQZv7T7`](https://suiscan.xyz/testnet/tx/4m9S1RhMMbn3DypHUF8Q7QEVYRHvt4GpcmjzohQZv7T7) owner `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
8. **Create Obligation** — [`2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ`](https://suiscan.xyz/testnet/tx/2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ) owner `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
9. **Authorize Treasury Payment (PTB)** — [`6rzs1ypLteygUQjqw6wv3aR8CTQDy9Vr6HWgB17KKyyN`](https://suiscan.xyz/testnet/tx/6rzs1ypLteygUQjqw6wv3aR8CTQDy9Vr6HWgB17KKyyN) owner `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
10. **Execute Treasury Payment** — [`9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9`](https://suiscan.xyz/testnet/tx/9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9) owner `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
11. **Create Payroll Mandate** — [`6c5qZUgZkyubbqgmCvv91EximFVAetp41ADGzXVWtroc`](https://suiscan.xyz/testnet/tx/6c5qZUgZkyubbqgmCvv91EximFVAetp41ADGzXVWtroc) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
12. **Fund Payroll Vault** — [`EkvXDGM8eHvHbE9YLPTh1fGbsTSUNDbBCzVCq3qWmd29`](https://suiscan.xyz/testnet/tx/EkvXDGM8eHvHbE9YLPTh1fGbsTSUNDbBCzVCq3qWmd29) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
13. **Simulate Payroll** — [`9aZw9ZV6zjaZY3Xd6xk2GEX8cTC4TU2SKeQGDFdGwujK`](https://suiscan.xyz/testnet/tx/9aZw9ZV6zjaZY3Xd6xk2GEX8cTC4TU2SKeQGDFdGwujK) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
14. **Execute Payroll** — [`Hm3MRXjJ7fTFTBRnS9jumGn497NM6mpMUJbmKdH5RbiU`](https://suiscan.xyz/testnet/tx/Hm3MRXjJ7fTFTBRnS9jumGn497NM6mpMUJbmKdH5RbiU) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
15. **Create Revenue Mandate** — [`5ubysM95F18JaUARgGrx1xGbQ7G6uqeZDEqf9hCU9dmC`](https://suiscan.xyz/testnet/tx/5ubysM95F18JaUARgGrx1xGbQ7G6uqeZDEqf9hCU9dmC) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
16. **Fund Revenue Vault** — [`G1mZ1aMZHJXtA95Qao4YdQkuF7TQg1ThikYmsZD2vnzW`](https://suiscan.xyz/testnet/tx/G1mZ1aMZHJXtA95Qao4YdQkuF7TQg1ThikYmsZD2vnzW) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
17. **Simulate Revenue Distribution** — [`7vsmSoDmgcmdBtc8ig3T3JRq86EuEYe4RkHtPD6JL1td`](https://suiscan.xyz/testnet/tx/7vsmSoDmgcmdBtc8ig3T3JRq86EuEYe4RkHtPD6JL1td) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
18. **Execute Revenue Distribution** — [`6J1b2SGHC65p66hK1QBDYxy4aJfd2UNjMAKtGqHTHR2x`](https://suiscan.xyz/testnet/tx/6J1b2SGHC65p66hK1QBDYxy4aJfd2UNjMAKtGqHTHR2x) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
19. **Create Investment Mandate** — [`EBY5LNhB6zvgV6bPFgcmqAqE31YF17d5CSB4zbGMF462`](https://suiscan.xyz/testnet/tx/EBY5LNhB6zvgV6bPFgcmqAqE31YF17d5CSB4zbGMF462) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
20. **Fund Investment Vault** — [`DSaHaxfuiyvj2nMjLwXaJtGYyZ1rtJyPJQRqu6BsVuAf`](https://suiscan.xyz/testnet/tx/DSaHaxfuiyvj2nMjLwXaJtGYyZ1rtJyPJQRqu6BsVuAf) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
21. **Simulate Investment** — [`91pA73NfZY6r97mvaJuZwncFJq2yhjdDYyVxt6ziJ8ap`](https://suiscan.xyz/testnet/tx/91pA73NfZY6r97mvaJuZwncFJq2yhjdDYyVxt6ziJ8ap) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
22. **Execute Investment** — [`8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo`](https://suiscan.xyz/testnet/tx/8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo) owner `0x70688d823c16186714d0fb5b23678d9876715d27067fc2cd63ffff8cea8e65eb`
