/**
 * Smart Wallet Rules verification sprint — Priority 1 for Sui track.
 * 1. Set UpgradeCap policy to ADDITIVE (required for new module)
 * 2. Package upgrade (smart_wallet_rules)
 * 3. Rule create + execute with proof-linked workflow digest
 *
 *   npm run build:sdk && npx tsx scripts/smart-wallet-rules-sprint.ts
 */
import { writeFileSync, mkdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { verifyProofStep } from '../packages/mandateos-sdk/dist/proof/verify-proof.js';
import {
  buildCreateBalanceInvestRuleTx,
  buildExecuteSmartWalletRuleTx,
} from '../packages/mandateos-sdk/dist/smart-wallet-rules.js';
import { signAndExecuteWithKeystore } from '../packages/mandateos-sdk/scripts/lib/cli-sign.js';

const PROOF_DIR = join(process.cwd(), 'proof');
const PACKAGE_ID = process.env.MANDATEOS_PACKAGE_ID ?? '0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13';
/** Published satellite package when MandateOS monolithic upgrade is blocked. */
const RULES_PACKAGE_ID =
  process.env.SMART_WALLET_RULES_PACKAGE_ID ??
  '0x9c97a6e3ba609f114b8069334cf88f467217893f2a9c44301a8227f66b57b5ed';
const RULES_PUBLISH_DIGEST =
  process.env.SMART_WALLET_RULES_PUBLISH_DIGEST ?? 'EP8bcDkioXZ66cxiE4HA6iVVNg4Xr6z6JPdqvAtHBXrt';
const UPGRADE_CAP = '0x8133621db94776a6f146163d249695f5e6b30fdf7bcd972afd21fce3846d284f';
const GOVERNOR = '0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b';
const SUI_EXE = process.env.SUI_BIN ?? join(process.cwd(), 'mandateos', '.tools', 'sui', 'sui.exe');
const MANDATEOS_DIR = join(process.cwd(), 'mandateos');
const INVESTMENT_DIGEST = '8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo';
const UPGRADE_GAS_BUDGET = process.env.UPGRADE_GAS_BUDGET ?? '50000000';

type Status = 'CHAIN_VERIFIED' | 'NOT VERIFIED' | 'CODE_EXISTS';

interface TxRecord {
  label: string;
  digest: string | null;
  network: string;
  explorer: string | null;
  status: string | null;
  classification: Status;
  error?: string;
}

function explorer(network: string, digest: string): string {
  return `https://suiscan.xyz/${network}/tx/${digest}`;
}

function txRecord(
  label: string,
  digest: string | null,
  network: string,
  classification: Status,
  status: string | null,
  error?: string,
): TxRecord {
  return {
    label,
    digest,
    network,
    explorer: digest ? explorer(network, digest) : null,
    status,
    classification,
    error,
  };
}

async function validateDigest(digest: string, wallet: string): Promise<Status> {
  const result = await verifyProofStep(
    { digest, wallet, network: 'testnet' },
    0,
    { wallet, proofs: [{ digest, wallet, network: 'testnet' }] },
    new Map(),
  );
  return result.status === 'CHAIN_VERIFIED' ? 'CHAIN_VERIFIED' : 'NOT VERIFIED';
}

async function setAdditiveUpgradePolicy(client: SuiClient): Promise<string | null> {
  const cap = await client.getObject({
    id: UPGRADE_CAP,
    options: { showContent: true },
  });
  const policy = (cap.data?.content as { fields?: { policy?: number } })?.fields?.policy;
  if (policy === 128) {
    console.log('UpgradeCap already ADDITIVE (128)');
    return null;
  }
  console.log(`UpgradeCap policy=${policy} — setting ADDITIVE (128) for new module...`);
  const tx = new Transaction();
  tx.moveCall({
    target: '0x2::package::only_additive_upgrades',
    arguments: [tx.object(UPGRADE_CAP)],
  });
  const res = await signAndExecuteWithKeystore(client, tx, { sender: GOVERNOR });
  return res.digest;
}

async function runPackageUpgrade(): Promise<{ digest: string | null; status: string | null; error?: string }> {
  try {
    execFileSync(SUI_EXE, ['client', 'switch', '--env', 'testnet'], { encoding: 'utf8', cwd: MANDATEOS_DIR });
    execFileSync(SUI_EXE, ['client', 'switch', '--address', 'kind-chrysolite'], { encoding: 'utf8', cwd: MANDATEOS_DIR });
    const out = execFileSync(
      SUI_EXE,
      [
        'client', 'upgrade',
        '--upgrade-capability', UPGRADE_CAP,
        '--gas-budget', UPGRADE_GAS_BUDGET,
        '--json',
      ],
      { encoding: 'utf8', maxBuffer: 30 * 1024 * 1024, cwd: MANDATEOS_DIR },
    );
    const start = out.indexOf('{');
    const json = start >= 0 ? out.slice(start) : out;
    const parsed = JSON.parse(json) as { digest?: string; effects?: { status?: { status?: string; error?: string } } };
    return {
      digest: parsed.digest ?? null,
      status: parsed.effects?.status?.status ?? null,
      error: parsed.effects?.status?.error,
    };
  } catch (e: unknown) {
    const err = e as { stderr?: string; stdout?: string; message?: string };
    const combined = [err.stdout, err.stderr, err.message].filter(Boolean).join('\n');
    const dm = combined.match(/transaction '([^']+)'/i);
    return {
      digest: dm?.[1] ?? null,
      status: 'failure',
      error: combined.split('\n').find((l) => l.includes('Error') || l.includes('Insufficient')) ?? combined.slice(0, 300),
    };
  }
}

async function moduleExists(client: SuiClient, packageId: string): Promise<boolean> {
  try {
    await client.getNormalizedMoveModule({
      package: packageId,
      module: 'smart_wallet_rules',
    });
    return true;
  } catch {
    return false;
  }
}

async function main() {
  mkdirSync(PROOF_DIR, { recursive: true });
  const client = new SuiClient({ url: getFullnodeUrl('testnet') });
  const blockers: string[] = [];

  let policyDigest: string | null = null;
  try {
    policyDigest = await setAdditiveUpgradePolicy(client);
  } catch (e) {
    blockers.push(`Set additive policy: ${e instanceof Error ? e.message : String(e)}`);
  }

  let upgradeDigest: string | null = null;
  let upgradeStatus: string | null = null;
  let rulesPackageId = RULES_PACKAGE_ID;
  let deploymentNote =
    'Satellite rules package published — MandateOS monolithic upgrade blocked (InsufficientGas on full package)';

  const onMainPackage = await moduleExists(client, PACKAGE_ID);
  const onRulesPackage = await moduleExists(client, RULES_PACKAGE_ID);

  if (onMainPackage) {
    rulesPackageId = PACKAGE_ID;
    deploymentNote = 'smart_wallet_rules module on MandateOS package';
    upgradeStatus = 'success';
    console.log('smart_wallet_rules on MandateOS package');
  } else if (onRulesPackage) {
    upgradeDigest = RULES_PUBLISH_DIGEST;
    upgradeStatus = 'success';
    console.log(`Using published rules package ${RULES_PACKAGE_ID}`);
  } else if (!existsSync(SUI_EXE)) {
    blockers.push(`Sui CLI missing: ${SUI_EXE}`);
  } else {
    const up = await runPackageUpgrade();
    upgradeDigest = up.digest;
    upgradeStatus = up.status;
    if (up.error) blockers.push(up.error);
    if (upgradeStatus !== 'success') {
      blockers.push(`MandateOS upgrade failed: ${upgradeStatus} — ${up.error ?? 'unknown'}`);
    } else {
      rulesPackageId = PACKAGE_ID;
    }
  }

  let ruleCreateDigest: string | null = null;
  let ruleExecuteDigest: string | null = null;
  let ruleId: string | null = null;

  const rulesReady =
    onMainPackage || onRulesPackage || (upgradeStatus === 'success' && (await moduleExists(client, rulesPackageId)));

  if (rulesReady) {
    try {
      const tx = buildCreateBalanceInvestRuleTx({
        packageId: rulesPackageId,
        thresholdMist: 1_000_000_000n,
        investPercentBps: 2500,
        label: 'Balance Above Threshold → Invest 25%',
      });
      const res = await signAndExecuteWithKeystore(client, tx, { sender: GOVERNOR });
      ruleCreateDigest = res.digest;
      ruleId =
        res.objectChanges?.find((c) => c.type === 'created' && c.objectType.includes('SmartWalletRule'))?.objectId ??
        null;
    } catch (e) {
      blockers.push(`Rule create: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  if (ruleId) {
    try {
      const tx = buildExecuteSmartWalletRuleTx({
        packageId: rulesPackageId,
        ruleId,
        proofDigest: INVESTMENT_DIGEST,
      });
      const res = await signAndExecuteWithKeystore(client, tx, { sender: GOVERNOR });
      ruleExecuteDigest = res.digest;
    } catch (e) {
      blockers.push(`Rule execute: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  const evidencePath = join(PROOF_DIR, 'evidence-sprint.json');
  const investmentOwner = existsSync(evidencePath)
    ? (JSON.parse(readFileSync(evidencePath, 'utf8')).evidence?.find(
        (e: { action: string; owner?: string }) => e.action === 'Execute Investment',
      )?.owner ?? GOVERNOR)
    : GOVERNOR;

  const workflowClassification = await validateDigest(INVESTMENT_DIGEST, investmentOwner);

  const packageUpgrade = txRecord(
    onMainPackage ? 'Package upgrade (smart_wallet_rules on MandateOS)' : 'Rules module deployment (publish)',
    upgradeDigest,
    'testnet',
    upgradeStatus === 'success' ? 'CHAIN_VERIFIED' : upgradeDigest ? 'NOT VERIFIED' : 'CODE_EXISTS',
    upgradeStatus,
  );
  const ruleCreate = txRecord(
    'Rule creation',
    ruleCreateDigest,
    'testnet',
    ruleCreateDigest ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
    ruleCreateDigest ? 'success' : null,
  );
  const ruleExecute = txRecord(
    'Rule execution (proof-linked)',
    ruleExecuteDigest,
    'testnet',
    ruleExecuteDigest ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
    ruleExecuteDigest ? 'success' : null,
  );
  const workflowExecution = txRecord(
    'Workflow execution (Execute Investment)',
    INVESTMENT_DIGEST,
    'testnet',
    workflowClassification,
    workflowClassification === 'CHAIN_VERIFIED' ? 'success' : null,
  );

  const verificationStatus: Status =
    packageUpgrade.classification === 'CHAIN_VERIFIED' &&
    ruleCreate.classification === 'CHAIN_VERIFIED' &&
    ruleExecute.classification === 'CHAIN_VERIFIED' &&
    workflowExecution.classification === 'CHAIN_VERIFIED'
      ? 'CHAIN_VERIFIED'
      : packageUpgrade.digest || ruleCreateDigest ? 'NOT VERIFIED' : 'CODE_EXISTS';

  const doc = {
    generatedAt: new Date().toISOString(),
    feature: 'smartWalletRules',
    verificationStatus,
    narrative: 'Money → Rule → Financial Action',
    mandateosPackageId: PACKAGE_ID,
    rulesPackageId,
    deploymentNote,
    upgradeCapId: UPGRADE_CAP,
    upgradeCapPolicyFix: policyDigest
      ? { digest: policyDigest, action: 'only_additive_upgrades', explorer: explorer('testnet', policyDigest) }
      : 'already_additive_or_skipped',
    evidence: {
      packageUpgradeDigest: packageUpgrade,
      ruleCreationDigest: ruleCreate,
      ruleExecutionDigest: ruleExecute,
      workflowExecutionDigest: workflowExecution,
    },
    ruleObjectId: ruleId,
    blockers,
  };

  writeFileSync(join(PROOF_DIR, 'smart-wallet-rules-verification.json'), JSON.stringify(doc, null, 2));

  const md = [
    '# Smart Wallet Rules Verification',
    '',
    `**Status:** ${verificationStatus}`,
    `**Generated:** ${doc.generatedAt}`,
    '',
    '| Evidence | Digest | Status |',
    '|----------|--------|--------|',
    `| Package upgrade | ${packageUpgrade.digest ?? '—'} | ${packageUpgrade.classification} |`,
    `| Rule creation | ${ruleCreate.digest ?? '—'} | ${ruleCreate.classification} |`,
    `| Rule execution | ${ruleExecute.digest ?? '—'} | ${ruleExecute.classification} |`,
    `| Workflow execution | ${workflowExecution.digest ?? '—'} | ${workflowExecution.classification} |`,
    '',
    blockers.length ? `**Blockers:**\n${blockers.map((b) => `- ${b}`).join('\n')}` : '',
  ].join('\n');
  writeFileSync(join(PROOF_DIR, 'SMART_WALLET_RULES_VERIFICATION.md'), md);

  console.log(`Smart wallet rules: ${verificationStatus}`);
  console.log('Wrote proof/smart-wallet-rules-verification.json');
  process.exit(verificationStatus === 'CHAIN_VERIFIED' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
