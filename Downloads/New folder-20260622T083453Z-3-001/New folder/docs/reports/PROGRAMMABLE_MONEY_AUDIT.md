# PROGRAMMABLE MONEY AUDIT

**Generated:** 2026-06-21T08:24:47.285Z

## Canonical judge flow (Wallet A)

Treasury → Fund → Obligation → Simulate PTB → Execute PTB → Receipt

### Create Treasury — Wallet A
- **Digest:** [`8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL`](https://suiscan.xyz/testnet/tx/8V4umtQuDoK7m3GfaFLhq2PMBBEFDD7RTosdZeEBV5jL)
- **Owner:** `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
- **Objects:** mandateId=`0x25f5942ae242acfe4ec7987e5878dd84a8039a604608221ce8d61ff404b348f8`, vaultId=`0xe282d9d0277342eef0646f69ffdff583a0107622416b741da537b9dfdec7a4be`, treasuryConfigId=`0x5d7b587af4c1556b33d575d490d7411ace717689e7311bd15dc6c51473891343`, delegationCapId=`0xebe0fb1594e6c844635d4d2038aaadff12541bca1f353d5a1a4d23d95a8000f8`, oracleCapId=`0xa1565773848c2e5841aaf6d4f832d49853730164009db4f301d191ecba87467f`, constitutionOwner=`0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`

### Fund Treasury
- **Digest:** [`3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX`](https://suiscan.xyz/testnet/tx/3ge1qdz2V9g3BeqkYBEY18VYQxHK6d9m6WMrGpFFT3VX)
- **Owner:** `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
- **Objects:** vaultId=`0xe282d9d0277342eef0646f69ffdff583a0107622416b741da537b9dfdec7a4be`, vaultBeforeMist=`0`, vaultAfterMist=`15000000`

### Create Obligation
- **Digest:** [`2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ`](https://suiscan.xyz/testnet/tx/2pZgo8J3ifK5K2WjKCWK1D7ro6qEcY17Q9SoAgyQsYCJ)
- **Owner:** `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
- **Objects:** obligationsId=`0xbe653154f10ee1df7256bfc030c1d549f7fd03d8970f62f103f782c0776702a5`

### Execute Treasury Payment
- **Digest:** [`9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9`](https://suiscan.xyz/testnet/tx/9JNpcrJUyesEGrqyBdzV1iUVkWymB8K8iddMCnRzcYc9)
- **Owner:** `0x02bcebcfc7a6a62a5b3c0ebce5da259cd4fdccf4ca994fcf0e21a1cb0eb16e4e`
- **Objects:** FinancialReceipt=`0x57a9b98d7e35bd7c83bd14c0a5c1475c6d6c932a1f619bf29511a3df87789e2d`, SimulationApproval=`0xd745e5d9de21ad375a3c39efd98035d392f9a1927907ccbffa66bf8b15c549ad`, vaultBeforeMist=`15000000`, vaultAfterMist=`15000000`, recipient=`0x897d602448fa352fb712056abdbfed27b353108962a4cc3db2f56102b38dc0cc`

**Flow: VERIFIED on-chain**
