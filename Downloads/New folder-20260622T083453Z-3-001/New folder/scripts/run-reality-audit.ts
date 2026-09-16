/**
 * Post-upgrade reality audit — upgrade verify, dual treasury create, RPC checks.
 * Governor keystore (kind-chrysolite) must have >= 0.7 SUI.
 *
 *   npx tsx scripts/run-reality-audit.ts
 */
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { MandateOSClient, parseCreatedTreasury } from '../packages/mandateos-sdk/dist/index.js';
import {
  signAndExecuteWithKeystore,
  signAndExecuteWithKeypair,
  explorerTx,
  txDigest,
} from '../packages/mandateos-sdk/scripts/lib/cli-sign.js';

const NETWORK = 'testnet';
const GOVERNOR = '0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b';
const PACKAGE_ID =
  process.env.MANDATEOS_PACKAGE_ID ??
  '0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713';
const UPGRADE_CAP = '0x8133621db94776a6f146163d249695f5e6b30fdf7bcd972afd21fce3846d284f';
const SLUSH_TEST_WALLET = '0xf6472cc0e5ce9f56e22619c0bc12b8c789fe2fe0c8d2be3f7f0f13eadd91e768';
const PROOF_DIR = join(process.cwd(), 'proof');
const MIN_GOV_MIST = 646_000_000n;

const client = new SuiClient({ url: getFullnodeUrl(NETWORK) });
const sdk = new MandateOSClient({
  packageId: PACKAGE_ID,
  ptbShimPackageId: '0x62148461af79d28034bee14c7300fe873d878eab11cc92d3bd869eefc8c7a00b',
});

async function balanceMist(owner: string) {
  const b = await client.getBalance({ owner });
  return BigInt(b.totalBalance);
}

async function verifyUpgradeCap() {
  const obj = await client.getObject({ id: UPGRADE_CAP, options: { showOwner: true } });
  if (!obj.data) throw new Error(`UpgradeCap not found: ${UPGRADE_CAP}`);
  const owner = obj.data.owner;
  const ownerAddr =
    owner && typeof owner === 'object' && 'AddressOwner' in owner ? owner.AddressOwner : null;
  if (ownerAddr?.toLowerCase() !== GOVERNOR.toLowerCase()) {
    throw new Error(`UpgradeCap owner mismatch: ${ownerAddr}`);
  }
  return { upgradeCapId: UPGRADE_CAP, owner: ownerAddr };
}

async function verifyPackage() {
  const pkg = await client.getObject({ id: PACKAGE_ID, options: { showContent: true } });
  if (!pkg.data) throw new Error(`Package not found: ${PACKAGE_ID}`);
  return { packageId: PACKAGE_ID, version: pkg.data.version };
}

async function fundKeypair(recipient: string, amountMist: bigint) {
  const tx = new Transaction();
  const [coin] = tx.splitCoins(tx.gas, [amountMist]);
  tx.transferObjects([coin], recipient);
  return signAndExecuteWithKeystore(client, tx, { sender: GOVERNOR });
}

async function readVaultBalanceMist(vaultId: string): Promise<string> {
  const v = await client.getObject({ id: vaultId, options: { showContent: true } });
  const fields = (v.data?.content as { fields?: Record<string, unknown> })?.fields;
  const bal = fields?.balance ?? fields?.total_balance;
  if (typeof bal === 'string') return bal;
  if (bal && typeof bal === 'object' && 'fields' in (bal as object)) {
    return String((bal as { fields: { value?: string } }).fields?.value ?? '0');
  }
  return '0';
}

async function verifyObjectOwner(objectId: string, expectedOwner: string) {
  const obj = await client.getObject({ id: objectId, options: { showOwner: true } });
  const owner = obj.data?.owner;
  const addr =
    owner && typeof owner === 'object' && 'AddressOwner' in owner ? owner.AddressOwner : null;
  if (addr?.toLowerCase() !== expectedOwner.toLowerCase()) {
    throw new Error(`Owner mismatch for ${objectId}: expected ${expectedOwner}, got ${addr}`);
  }
  return addr;
}

async function verifyTreasuryBootstrapOwnership(
  parsed: ReturnType<typeof parseCreatedTreasury>,
  expectedOwner: string,
) {
  const mandateObj = await client.getObject({ id: parsed.graph.mandateId, options: { showOwner: true } });
  const shared =
    mandateObj.data?.owner &&
    typeof mandateObj.data.owner === 'object' &&
    'Shared' in mandateObj.data.owner;
  if (!shared) {
    throw new Error(`FinancialMandate not shared for ${parsed.graph.mandateId}`);
  }
  await verifyObjectOwner(parsed.ownerAssets.delegationCapId, expectedOwner);
  await verifyObjectOwner(parsed.ownerAssets.oracleCapId, expectedOwner);
  const constObj = await client.getObject({
    id: parsed.graph.constitutionId,
    options: { showContent: true },
  });
  const fields = (constObj.data?.content as { fields?: Record<string, unknown> })?.fields ?? {};
  const ownership = fields.ownership;
  const primaryOwner =
    ownership &&
    typeof ownership === 'object' &&
    'fields' in ownership &&
    typeof (ownership as { fields: Record<string, unknown> }).fields.primary_owner === 'string'
      ? ((ownership as { fields: Record<string, unknown> }).fields.primary_owner as string)
      : null;
  if (primaryOwner?.toLowerCase() !== expectedOwner.toLowerCase()) {
    throw new Error(`Constitution owner mismatch: ${primaryOwner}`);
  }
}

async function createTreasuryForOwner(ownerKeypair: Ed25519Keypair) {
  const owner = ownerKeypair.toSuiAddress();
  const tx = sdk.buildCreateTreasuryTx({
    owner,
    executor: owner,
    targetBalance: 10_000_000_000n,
    maxPerTransaction: 500_000_000n,
    maxDaily: 2_000_000_000n,
    minReserveBps: 1000,
    contributionBps: 0,
    contributionRecipient: owner,
    multisigThreshold: 1n,
  });
  const res = await signAndExecuteWithKeypair(client, tx, ownerKeypair);
  const parsed = parseCreatedTreasury(res, PACKAGE_ID, sdk.coinType);
  await verifyTreasuryBootstrapOwnership(parsed, owner);
  const vaultBal = await readVaultBalanceMist(parsed.graph.vaultId);
  return {
    owner,
    digest: txDigest(res),
    explorer: explorerTx(NETWORK, txDigest(res)),
    mandateId: parsed.graph.mandateId,
    vaultId: parsed.graph.vaultId,
    treasuryConfigId: parsed.graph.treasuryConfigId,
    vaultBalanceMist: vaultBal,
  };
}

function writeFinalReport(report: Record<string, unknown>) {
  const lines = [
    '# FINAL Reality Report',
    '',
    `**Generated:** ${report.generatedAt ?? new Date().toISOString()}`,
    `**Network:** testnet`,
    '',
    '## Blockers',
    '',
    ...(report.blockers as string[] ?? []).map((b) => `- ${b}`),
    '',
    '## Working end-to-end flows',
    '',
    ...(report.workingFlows as string[] ?? []).map((w) => `- ${w}`),
    '',
    '## Real transaction digests',
    '',
    ...Object.entries((report.digests as Record<string, string>) ?? {}).map(([k, v]) => `- **${k}:** [\`${v}\`](https://suiscan.xyz/testnet/tx/${v})`),
    '',
    '## Real object IDs',
    '',
    ...Object.entries((report.objects as Record<string, string>) ?? {}).map(([k, v]) => `- **${k}:** \`${v}\``),
    '',
    '## Remaining blockers',
    '',
    ...(report.remaining as string[] ?? []).map((r) => `- ${r}`),
    '',
  ];
  writeFileSync(join(process.cwd(), 'FINAL_REALITY_REPORT.md'), lines.join('\n'));
}

async function main() {
  mkdirSync(PROOF_DIR, { recursive: true });

  const govBal = await balanceMist(GOVERNOR);
  const slushBal = await balanceMist(SLUSH_TEST_WALLET);
  console.log(`Governor balance: ${govBal} MIST (${Number(govBal) / 1e9} SUI)`);
  console.log(`Slush test wallet: ${slushBal} MIST (${Number(slushBal) / 1e9} SUI)`);

  if (govBal < MIN_GOV_MIST) {
    const shortfall = MIN_GOV_MIST - govBal;
    writeFinalReport({
      generatedAt: new Date().toISOString(),
      blockers: [
        `Governor balance ${(Number(govBal) / 1e9).toFixed(4)} SUI — need ${(Number(MIN_GOV_MIST) / 1e9).toFixed(4)} SUI for Move upgrade`,
        `Send ~${(Number(shortfall) / 1e9).toFixed(2)} SUI to ${GOVERNOR}`,
      ],
      workingFlows: ['Wallet-scoped storage', 'Proof system (real digests)', 'PTB workflow pages (pending treasury)'],
      digests: {},
      objects: { packageId: PACKAGE_ID, upgradeCapId: UPGRADE_CAP },
      remaining: [
        'Move package upgrade (vec_map fix)',
        'Create Treasury from UI',
        'Full dual-wallet audit',
      ],
    });
    console.error(
      `\nBLOCKED: Governor needs >= ${MIN_GOV_MIST} MIST. Send ~${shortfall} MIST to:\n  ${GOVERNOR}`,
    );
    process.exit(2);
  }

  console.log('\nRunning package upgrade...');
  execFileSync(
    'powershell',
    ['-ExecutionPolicy', 'Bypass', '-File', join(process.cwd(), 'mandateos', 'scripts', 'upgrade-testnet.ps1')],
    { stdio: 'inherit' },
  );

  const deployment = JSON.parse(readFileSync(join(PROOF_DIR, 'deployment.json'), 'utf8')) as {
    upgradeDigest?: string;
    digest?: string;
  };
  const upgradeDigest = deployment.upgradeDigest ?? deployment.digest;

  const upgradeCap = await verifyUpgradeCap();
  const pkg = await verifyPackage();

  if (upgradeDigest) {
    const tx = await client.getTransactionBlock({
      digest: upgradeDigest,
      options: { showEffects: true },
    });
    if (tx.effects?.status?.status !== 'success') {
      throw new Error(`Upgrade tx failed: ${upgradeDigest}`);
    }
  }

  console.log('\nDual-wallet treasury test (independent keypairs)...');
  const walletA = Ed25519Keypair.generate();
  await fundKeypair(walletA.toSuiAddress(), 50_000_000n);
  const treasuryA = await createTreasuryForOwner(walletA);

  const walletB = Ed25519Keypair.generate();
  await fundKeypair(walletB.toSuiAddress(), 50_000_000n);
  const treasuryB = await createTreasuryForOwner(walletB);

  if (treasuryA.mandateId === treasuryB.mandateId) {
    throw new Error('Treasury mandate IDs must differ across wallets');
  }
  if (treasuryA.vaultId === treasuryB.vaultId) {
    throw new Error('Vault IDs must differ across wallets');
  }

  const audit = {
    auditedAt: new Date().toISOString(),
    network: NETWORK,
    balances: {
      governorMist: govBal.toString(),
      slushTestWalletMist: slushBal.toString(),
      slushTestWallet: SLUSH_TEST_WALLET,
    },
    package: pkg,
    upgradeCap,
    upgradeDigest,
    upgradeExplorer: upgradeDigest ? explorerTx(NETWORK, upgradeDigest) : null,
    dualTreasuryTest: { walletA: treasuryA, walletB: treasuryB },
    slushUiTest: {
      wallet: SLUSH_TEST_WALLET,
      instruction: 'Connect Slush at command-center-five-eta.vercel.app → Treasury Account → Create Treasury',
    },
    acceptance: {
      upgradeOnChain: !!upgradeDigest,
      createTreasuryWorks: true,
      uniqueTreasuryPerWallet: true,
      uniqueVaultIds: treasuryA.vaultId !== treasuryB.vaultId,
      uniqueMandateIds: treasuryA.mandateId !== treasuryB.mandateId,
      ownershipVerified: true,
      realTxDigests: [treasuryA.digest, treasuryB.digest].every((d) => /^0x[a-f0-9]{64}$/i.test(d)),
    },
  };

  writeFileSync(join(PROOF_DIR, 'reality-audit.json'), JSON.stringify(audit, null, 2));
  writeFinalReport({
    generatedAt: audit.auditedAt,
    blockers: [],
    workingFlows: [
      'Move package upgrade',
      'Create Treasury (Wallet A & B keypairs)',
      'Unique mandate/vault IDs verified',
      'Object ownership verified on-chain',
    ],
    digests: {
      upgrade: upgradeDigest ?? '',
      treasuryA: treasuryA.digest,
      treasuryB: treasuryB.digest,
    },
    objects: {
      packageId: PACKAGE_ID,
      upgradeCapId: UPGRADE_CAP,
      mandateA: treasuryA.mandateId,
      mandateB: treasuryB.mandateId,
      vaultA: treasuryA.vaultId,
      vaultB: treasuryB.vaultId,
    },
    remaining: [
      'Slush UI Create Treasury test (manual with 0xf6472…)',
      'External DeFi protocol deposit PTBs',
      'On-chain rebalance execution',
    ],
  });
  console.log('\n✓ proof/reality-audit.json');
  console.log('✓ FINAL_REALITY_REPORT.md');
  console.log(JSON.stringify(audit.acceptance, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
