# OBLIGATION AUDIT

**Generated:** 2026-06-21T08:24:47.385Z
**Package:** `0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13`

Obligation lifecycle maps to: register → fund vault → simulate → execute settlement.

| Step | Move function | Digest | Object changes | Events | Explorer | Status |
|------|---------------|--------|----------------|--------|----------|--------|
| Create Obligation | financial_mandate::register_obligation | [`2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ`](https://suiscan.xyz/testnet/tx/2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ) | 2 | 1 | [suiscan](https://suiscan.xyz/testnet/tx/2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ) | CHAIN_VERIFIED |
| Fund Obligation (treasury vault) | treasury_mandate::fund | [`3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX`](https://suiscan.xyz/testnet/tx/3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX) | 2 | 1 | [suiscan](https://suiscan.xyz/testnet/tx/3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX) | CHAIN_VERIFIED |
| Execute Obligation (simulate PTB) | financial_mandate::simulate_and_approve | [`6rzs1ypLteygUQjqw6wv3aR8CTQDy9Vr6HWgB17KKyyN`](https://suiscan.xyz/testnet/tx/6rzs1ypLteygUQjqw6wv3aR8CTQDy9Vr6HWgB17KKyyN) | 5 | 0 | [suiscan](https://suiscan.xyz/testnet/tx/6rzs1ypLteygUQjqw6wv3aR8CTQDy9Vr6HWgB17KKyyN) | CHAIN_VERIFIED |
| Execute Obligation (settlement PTB) | treasury_mandate::treasury_disbursement | [`9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9`](https://suiscan.xyz/testnet/tx/9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9) | 14 | 2 | [suiscan](https://suiscan.xyz/testnet/tx/9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9) | CHAIN_VERIFIED |

**Obligation lifecycle: CHAIN_VERIFIED**
