/**
 * Verify chain sync fix: create treasury, fund, refresh reader, print proof IDs.
 * Usage: npx tsx scripts/verify-chain-sync-fix.mjs
 */
import { writeFileSync } from 'node:fs';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { MandateOSClient } from '../packages/mandateos-sdk/dist/client.js';
import { MandateOSReader } from '../packages/mandateos-sdk/dist/reader/mandate-reader.js';
import { parseCreatedTreasury } from '../packages/mandateos-sdk/dist/parsers.js';
import {
  signAndExecuteWithKeystore,
  txDigest,
} from '../packages/mandateos-sdk/scripts/lib/cli-sign.ts';

const PACKAGE = process.env.MANDATEOS_PACKAGE_ID
  ?? '0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13';
const SHIM = process.env.MANDATEOS_PTB_SHIM_PACKAGE_ID
  ?? '0x70cba71ba84b852a83c66f3cddad429c98d082cffdc7638fa21e98faecf26af9';
const GOVERNOR = process.env.MANDATEOS_GOVERNOR_ADDRESS
  ?? '0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b';
const FUND_SUI = 0.15;

const client = new SuiClient({ url: getFullnodeUrl('testnet') });
const sdk = new MandateOSClient({ packageId: PACKAGE, ptbShimPackageId: SHIM });

console.log('1. Create Mandate PTB...');
const createTx = sdk.buildCreateTreasuryTx({
  owner: GOVERNOR,
  executor: GOVERNOR,
  targetBalance: 10_000_000_000n,
  maxPerTransaction: 500_000_000n,
  maxDaily: 2_000_000_000n,
  minReserveBps: 1000,
  contributionBps: 0,
  contributionRecipient: GOVERNOR,
  multisigThreshold: 1n,
});
const createRes = await signAndExecuteWithKeystore(client, createTx, { sender: GOVERNOR });
const createDigest = txDigest(createRes);
const parsed = parseCreatedTreasury(createRes, PACKAGE, sdk.coinType);
console.log('   create digest:', createDigest);
console.log('   mandate id:', parsed.graph.mandateId);

console.log('2. Fund Treasury PTB...');
const fundTx = sdk.buildFundVaultTx(parsed.graph, {
  amount: BigInt(Math.round(FUND_SUI * 1e9)),
});
const fundRes = await signAndExecuteWithKeystore(client, fundTx, { sender: GOVERNOR });
const fundDigest = txDigest(fundRes);
console.log('   fund digest:', fundDigest);

console.log('3. MandateOSReader.fetchMandateView...');
const reader = new MandateOSReader(client, { packageId: PACKAGE, ptbShimPackageId: SHIM });
const view = await reader.fetchMandateView({
  ...parsed.graph,
  configId: parsed.graph.treasuryConfigId,
});
console.log('   obligations:', view.obligations.length);
console.log('   objectives compliance:', view.objectives.complianceScore);

const proofId = `${createDigest}-template-chain-sync-verify`;
const report = {
  network: 'testnet',
  wallet: GOVERNOR,
  treasuryObjectId: parsed.graph.mandateId,
  vaultId: parsed.graph.vaultId,
  createMandateDigest: createDigest,
  fundTreasuryDigest: fundDigest,
  obligationIds: view.obligations.map((o) => o.id),
  objectiveSummary: {
    primaryObjective: view.objectives.primaryObjective,
    targetBalanceMist: view.objectives.targetBalanceMist.toString(),
    minRunwayDays: view.objectives.minRunwayDays,
    reserveCovenantBps: view.objectives.reserveCovenantBps,
    complianceScore: view.objectives.complianceScore,
  },
  proofCenterRecordId: proofId,
  chainSync: 'ok',
};
writeFileSync('proof/chain-sync-verify.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
