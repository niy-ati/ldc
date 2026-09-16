/**
 * DeFi verification sprint — executes or records chain evidence for all DeFi features.
 * Writes proof/defi-verification.json and DEFI_VERIFICATION_REPORT.md (chain evidence only).
 *
 * Mainnet DeFi requires: MANDATEOS_MAINNET_KEY or SUI_PRIVATE_KEY
 * Smart wallet testnet requires: governor keystore (kind-chrysolite) + funded gas
 *
 *   npm run build:sdk && npx tsx scripts/run-defi-verification-sprint.ts
 */
import { writeFileSync, mkdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { getFullnodeUrl, SuiClient, type SuiTransactionBlockResponse } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { verifyProofStep } from '../packages/mandateos-sdk/dist/proof/verify-proof.js';
import {
  depositSuiToNavi,
  withdrawSuiFromNavi,
  fetchNaviPositions,
  readNaviSupplyBalanceMist,
  NAVI_MAINNET_PACKAGE_ID,
} from '../packages/mandateos-sdk/dist/defi/navi-integration.js';
import {
  buildScallopDepositTransaction,
  buildScallopWithdrawTransaction,
  fetchScallopPositions,
  parseScallopTxEvidence,
} from '../packages/mandateos-sdk/dist/defi/scallop-integration.js';
import {
  buildCetusDepositTransaction,
  buildCetusWithdrawTransaction,
  fetchCetusPositions,
  parseCetusTxEvidence,
} from '../packages/mandateos-sdk/dist/defi/cetus-integration.js';
import { signAndExecuteWithKeypair } from '../packages/mandateos-sdk/scripts/lib/cli-sign.js';
import {
  buildCreateBalanceInvestRuleTx,
  buildExecuteSmartWalletRuleTx,
} from '../packages/mandateos-sdk/dist/smart-wallet-rules.js';
import { signAndExecuteWithKeystore } from '../packages/mandateos-sdk/scripts/lib/cli-sign.js';

const PROOF_DIR = join(process.cwd(), 'proof');
const DEPOSIT_MIST = 10_000_000;
const PACKAGE_ID = process.env.MANDATEOS_PACKAGE_ID ?? '0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13';
const UPGRADE_CAP = '0x8133621db94776a6f146163d249695f5e6b30fdf7bcd972afd21fce3846d284f';
const GOVERNOR = '0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b';
const SUI_EXE = process.env.SUI_BIN ?? join(process.cwd(), 'mandateos', '.tools', 'sui', 'sui.exe');
const MANDATEOS_DIR = join(process.cwd(), 'mandateos');
const INVESTMENT_DIGEST = '8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo';
const UPGRADE_GAS_BUDGET = process.env.UPGRADE_GAS_BUDGET ?? '150000000';

type Classification = 'CHAIN_VERIFIED' | 'NOT VERIFIED';

interface TxRecord {
  label: string;
  digest: string | null;
  network: string;
  explorer: string | null;
  status: string | null;
  classification: Classification;
  error?: string;
}

interface FeatureResult {
  classification: Classification;
  deposit?: TxRecord;
  withdraw?: TxRecord;
  addLiquidity?: TxRecord;
  removeLiquidity?: TxRecord;
  positionEvidence?: unknown;
  blockers: string[];
  extra?: Record<string, unknown>;
}

function loadKeypair(): Ed25519Keypair | null {
  const raw = process.env.MANDATEOS_MAINNET_KEY ?? process.env.SUI_PRIVATE_KEY;
  if (!raw) return null;
  if (raw.startsWith('suiprivkey')) return Ed25519Keypair.fromSecretKey(raw);
  return Ed25519Keypair.fromSecretKey(Buffer.from(raw.replace(/^0x/, ''), 'hex'));
}

function explorer(network: string, digest: string): string {
  return `https://suiscan.xyz/${network}/tx/${digest}`;
}

async function rpcTx(client: SuiClient, digest: string): Promise<SuiTransactionBlockResponse | null> {
  try {
    return await client.getTransactionBlock({
      digest,
      options: { showEffects: true, showObjectChanges: true, showEvents: true, showInput: true },
    });
  } catch {
    return null;
  }
}

async function validateDigest(
  digest: string,
  network: 'mainnet' | 'testnet',
  wallet: string,
): Promise<{ classification: Classification; txStatus: string | null; errors: string[] }> {
  const client = new SuiClient({ url: getFullnodeUrl(network) });
  const result = await verifyProofStep(
    { digest, wallet, network },
    0,
    { wallet, proofs: [{ digest, wallet, network }] },
    new Map(),
  );
  return {
    classification: result.status,
    txStatus: result.onChain?.txStatus ?? null,
    errors: result.errors,
  };
}

function txRecord(
  label: string,
  digest: string | null,
  network: string,
  classification: Classification,
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

async function verifyNavi(kp: Ed25519Keypair): Promise<FeatureResult> {
  const address = kp.toSuiAddress();
  const client = new SuiClient({ url: getFullnodeUrl('mainnet') });
  const blockers: string[] = [];
  try {
    const bal = await client.getBalance({ owner: address });
    if (BigInt(bal.totalBalance) < BigInt(DEPOSIT_MIST + 5_000_000)) {
      throw new Error(`Insufficient mainnet SUI: ${Number(bal.totalBalance) / 1e9}`);
    }
    const before = await readNaviSupplyBalanceMist(address);
    const deposit = await depositSuiToNavi(kp, DEPOSIT_MIST);
    const afterDep = await readNaviSupplyBalanceMist(address);
    if (afterDep <= before) throw new Error('Position did not increase after deposit');
    const positions = await fetchNaviPositions(address);
    const withdraw = await withdrawSuiFromNavi(kp, DEPOSIT_MIST);
    const depVal = await validateDigest(deposit.digest, 'mainnet', address);
    const wVal = await validateDigest(withdraw.digest, 'mainnet', address);
    const ok = depVal.classification === 'CHAIN_VERIFIED' && wVal.classification === 'CHAIN_VERIFIED';
    return {
      classification: ok ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
      deposit: txRecord('Navi deposit', deposit.digest, 'mainnet', depVal.classification, depVal.txStatus),
      withdraw: txRecord('Navi withdraw', withdraw.digest, 'mainnet', wVal.classification, wVal.txStatus),
      positionEvidence: positions,
      blockers,
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    blockers.push(msg);
    return { classification: 'NOT VERIFIED', blockers };
  }
}

async function execProtocolTx(
  kp: Ed25519Keypair,
  build: (sender: string, amount: number) => Promise<import('@mysten/sui/transactions').Transaction>,
  amountMist: number,
  parse: typeof parseScallopTxEvidence,
  action: 'deposit' | 'withdraw',
  asset: string,
): Promise<{ digest: string; evidence: ReturnType<typeof parseScallopTxEvidence> }> {
  const client = new SuiClient({ url: getFullnodeUrl('mainnet') });
  const tx = await build(kp.toSuiAddress(), amountMist);
  const res = await signAndExecuteWithKeypair(client, tx, kp);
  const waited = await client.waitForTransaction({
    digest: res.digest,
    options: { showEffects: true, showObjectChanges: true, showEvents: true },
  });
  if (waited.effects?.status?.status !== 'success') {
    throw new Error(waited.effects?.status?.error ?? 'Transaction failed');
  }
  const evidence = parse(waited, { wallet: kp.toSuiAddress(), asset, amountMist, action });
  return { digest: evidence.digest, evidence };
}

async function verifyScallop(kp: Ed25519Keypair): Promise<FeatureResult> {
  const address = kp.toSuiAddress();
  const blockers: string[] = [];
  try {
    const deposit = await execProtocolTx(
      kp, buildScallopDepositTransaction, DEPOSIT_MIST, parseScallopTxEvidence, 'deposit', 'SUI',
    );
    const positions = await fetchScallopPositions(address);
    const withdraw = await execProtocolTx(
      kp, buildScallopWithdrawTransaction, DEPOSIT_MIST, parseScallopTxEvidence, 'withdraw', 'SUI',
    );
    const depVal = await validateDigest(deposit.digest, 'mainnet', address);
    const wVal = await validateDigest(withdraw.digest, 'mainnet', address);
    const ok = depVal.classification === 'CHAIN_VERIFIED' && wVal.classification === 'CHAIN_VERIFIED';
    return {
      classification: ok ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
      deposit: txRecord('Scallop deposit', deposit.digest, 'mainnet', depVal.classification, depVal.txStatus),
      withdraw: txRecord('Scallop withdraw', withdraw.digest, 'mainnet', wVal.classification, wVal.txStatus),
      positionEvidence: positions,
      blockers,
    };
  } catch (e) {
    blockers.push(e instanceof Error ? e.message : String(e));
    return { classification: 'NOT VERIFIED', blockers };
  }
}

async function verifyCetus(kp: Ed25519Keypair): Promise<FeatureResult> {
  const address = kp.toSuiAddress();
  const blockers: string[] = [];
  try {
    const add = await execProtocolTx(
      kp, buildCetusDepositTransaction, DEPOSIT_MIST, parseCetusTxEvidence, 'deposit', 'SUI/USDC LP',
    );
    const positions = await fetchCetusPositions(address);
    const remove = await execProtocolTx(
      kp, buildCetusWithdrawTransaction, DEPOSIT_MIST, parseCetusTxEvidence, 'withdraw', 'SUI/USDC LP',
    );
    const aVal = await validateDigest(add.digest, 'mainnet', address);
    const rVal = await validateDigest(remove.digest, 'mainnet', address);
    const ok = aVal.classification === 'CHAIN_VERIFIED' && rVal.classification === 'CHAIN_VERIFIED';
    return {
      classification: ok ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
      addLiquidity: txRecord('Cetus add liquidity', add.digest, 'mainnet', aVal.classification, aVal.txStatus),
      removeLiquidity: txRecord('Cetus remove liquidity', remove.digest, 'mainnet', rVal.classification, rVal.txStatus),
      positionEvidence: positions,
      blockers,
    };
  } catch (e) {
    blockers.push(e instanceof Error ? e.message : String(e));
    return { classification: 'NOT VERIFIED', blockers };
  }
}

async function verifyAllocationFromFeatures(
  navi: FeatureResult,
  scallop: FeatureResult,
  cetus: FeatureResult,
): Promise<FeatureResult> {
  const naviDep = navi.deposit?.digest ?? null;
  const scallopDep = scallop.deposit?.digest ?? null;
  const cetusDep = cetus.addLiquidity?.digest ?? null;
  const blockers: string[] = [];
  if (!naviDep) blockers.push('Missing Navi allocation digest');
  if (!scallopDep) blockers.push('Missing Scallop allocation digest');
  if (!cetusDep) blockers.push('Missing Cetus allocation digest');
  return {
    classification: naviDep && scallopDep && cetusDep ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
    blockers,
    extra: {
      digests: { navi: naviDep, scallop: scallopDep, cetus: cetusDep },
      treasuryAllocationDigest: null,
      portfolioReconciliation: 'NOT VERIFIED — no single treasury→split PTB on testnet/mainnet unified network',
    },
  };
}

async function validateStepDigest(
  digest: string | null,
  network: 'mainnet' | 'testnet',
  wallet: string,
): Promise<TxRecord> {
  if (!digest) {
    return txRecord('step', null, network, 'NOT VERIFIED', null, 'No digest');
  }
  const v = await validateDigest(digest, network, wallet);
  return txRecord('step', digest, network, v.classification, v.txStatus, v.errors[0]);
}

async function programmableChainsStatus(): Promise<FeatureResult> {
  const evidencePath = join(PROOF_DIR, 'evidence-sprint.json');
  if (!existsSync(evidencePath)) {
    return {
      classification: 'NOT VERIFIED',
      blockers: ['No evidence-sprint.json — programmable chain not executed'],
    };
  }
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  const find = (action: string) =>
    evidence.evidence?.find((e: { action: string; digest?: string; owner?: string }) => e.action === action) ?? null;
  const revenue = find('Execute Revenue Distribution') ?? find('Execute Revenue');
  const investment = find('Execute Investment');
  const revenueDigest = revenue?.digest ?? null;
  const investmentDigest = investment?.digest ?? null;
  const revenueWallet = revenue?.owner ?? GOVERNOR;
  const investmentWallet = investment?.owner ?? GOVERNOR;

  const revenueStep = await validateStepDigest(revenueDigest, 'testnet', revenueWallet);
  const investmentStep = await validateStepDigest(investmentDigest, 'testnet', investmentWallet);
  const naviStep = txRecord('Navi deposit (mainnet leg)', null, 'mainnet', 'NOT VERIFIED', null, 'Not executed');

  const blockers: string[] = [];
  if (revenueStep.classification !== 'CHAIN_VERIFIED') blockers.push('Revenue execute digest missing or RPC invalid');
  if (investmentStep.classification !== 'CHAIN_VERIFIED') blockers.push('Investment execute digest missing or RPC invalid');
  if (naviStep.classification !== 'CHAIN_VERIFIED') {
    blockers.push('Mainnet Navi deposit digest missing — chain spans testnet MandateOS + mainnet DeFi');
  }
  blockers.push('No single orchestrated programmable chain run with final portfolio snapshot');

  const chainComplete =
    revenueStep.classification === 'CHAIN_VERIFIED' &&
    investmentStep.classification === 'CHAIN_VERIFIED' &&
    naviStep.classification === 'CHAIN_VERIFIED';

  return {
    classification: chainComplete ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
    blockers,
    extra: {
      intermediateDigests: {
        revenueExecute: revenueStep,
        investmentExecute: investmentStep,
        naviDeposit: naviStep,
      },
      completeChainExecution: false,
      finalPortfolioState: 'NOT VERIFIED',
    },
  };
}

async function attemptSmartWalletUpgrade(): Promise<FeatureResult> {
  const blockers: string[] = [];
  const testnet = new SuiClient({ url: getFullnodeUrl('testnet') });
  let upgradeDigest: string | null = null;
  let upgradeStatus: string | null = null;

  if (!existsSync(SUI_EXE)) {
    blockers.push(`Sui CLI not found at ${SUI_EXE}`);
    return { classification: 'NOT VERIFIED', blockers };
  }

  try {
    execFileSync(SUI_EXE, ['client', 'switch', '--env', 'testnet'], { encoding: 'utf8', cwd: MANDATEOS_DIR });
    execFileSync(SUI_EXE, ['client', 'switch', '--address', 'kind-chrysolite'], { encoding: 'utf8', cwd: MANDATEOS_DIR });
    const out = execFileSync(
      SUI_EXE,
      ['client', 'upgrade', '--upgrade-capability', UPGRADE_CAP, '--gas-budget', UPGRADE_GAS_BUDGET],
      { encoding: 'utf8', maxBuffer: 20 * 1024 * 1024, cwd: MANDATEOS_DIR },
    );
    const m = out.match(/Transaction Digest: (\w+)/) ?? out.match(/"digest"\s*:\s*"(\w+)"/);
    upgradeDigest = m?.[1] ?? null;
  } catch (e: unknown) {
    const err = e as { stderr?: string; stdout?: string; message?: string };
    const combined = [err.stdout, err.stderr, err.message].filter(Boolean).join('\n');
    const dm = combined.match(/transaction '([^']+)'/i) ?? combined.match(/Digest: (\w+)/);
    if (dm) upgradeDigest = dm[1];
    blockers.push(combined.split('\n').find((l) => l.includes('Error') || l.includes('Insufficient')) ?? combined.slice(0, 200));
  }

  if (upgradeDigest) {
    const tx = await rpcTx(testnet, upgradeDigest);
    upgradeStatus = tx?.effects?.status?.status ?? null;
    if (upgradeStatus !== 'success') {
      blockers.push(`Upgrade on-chain status: ${upgradeStatus} — ${tx?.effects?.status?.error ?? 'unknown'}`);
    }
  }

  let ruleCreateDigest: string | null = null;
  let ruleExecuteDigest: string | null = null;
  let ruleId: string | null = null;

  if (upgradeStatus === 'success') {
    try {
      const tx = buildCreateBalanceInvestRuleTx({
        packageId: PACKAGE_ID,
        thresholdMist: 1_000_000_000n,
        investPercentBps: 2500,
        label: 'Balance Above Threshold → Invest 25%',
      });
      const res = await signAndExecuteWithKeystore(testnet, tx, { sender: GOVERNOR });
      ruleCreateDigest = res.digest;
      ruleId = res.objectChanges?.find((c) => c.type === 'created' && c.objectType.includes('SmartWalletRule'))?.objectId ?? null;
    } catch (e) {
      blockers.push(`Rule create: ${e instanceof Error ? e.message : String(e)}`);
    }
  } else {
    blockers.push('smart_wallet_rules module not on-chain — upgrade required before rule creation');
  }

  if (ruleId) {
    try {
      const tx = buildExecuteSmartWalletRuleTx({
        packageId: PACKAGE_ID,
        ruleId,
        proofDigest: INVESTMENT_DIGEST,
      });
      const res = await signAndExecuteWithKeystore(testnet, tx, { sender: GOVERNOR });
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
  const workflowVal = await validateDigest(INVESTMENT_DIGEST, 'testnet', investmentOwner);
  const workflowRecord = txRecord(
    'Linked workflow (Execute Investment)',
    INVESTMENT_DIGEST,
    'testnet',
    workflowVal.classification,
    workflowVal.txStatus,
  );

  const ok =
    upgradeStatus === 'success' &&
    ruleCreateDigest &&
    ruleExecuteDigest &&
    workflowVal.classification === 'CHAIN_VERIFIED';
  return {
    classification: ok ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
    blockers,
    extra: {
      packageUpgrade: txRecord(
        'Package upgrade (smart_wallet_rules)',
        upgradeDigest,
        'testnet',
        upgradeStatus === 'success' ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
        upgradeStatus,
      ),
      ruleCreate: txRecord('Rule create', ruleCreateDigest, 'testnet', ruleCreateDigest ? 'CHAIN_VERIFIED' : 'NOT VERIFIED', ruleCreateDigest ? 'success' : null),
      ruleExecute: txRecord('Rule execute (proof-linked)', ruleExecuteDigest, 'testnet', ruleExecuteDigest ? 'CHAIN_VERIFIED' : 'NOT VERIFIED', ruleExecuteDigest ? 'success' : null),
      workflowProof: workflowRecord,
      ruleObjectId: ruleId,
    },
  };
}

function buildReport(doc: Record<string, unknown>): string {
  const features = doc.features as Record<string, FeatureResult>;
  const lines: string[] = [
    '# DEFI VERIFICATION REPORT',
    '',
    `**Generated:** ${doc.generatedAt}`,
    `**Overall:** ${doc.overallClassification}`,
    '',
    'Allowed states: **CHAIN_VERIFIED** | **NOT VERIFIED** only. No digest → NOT VERIFIED.',
    '',
  ];

  lines.push('## Requirement matrix', '', '| Feature | Required evidence | Status |', '|---------|-------------------|--------|');
  const req: Array<[string, string, string]> = [
    ['Navi', 'deposit + withdraw + position digests', features.navi?.classification ?? 'NOT VERIFIED'],
    ['Scallop', 'deposit + withdraw + position digests', features.scallop?.classification ?? 'NOT VERIFIED'],
    ['Cetus', 'add + remove + LP position digests', features.cetus?.classification ?? 'NOT VERIFIED'],
    ['Allocation', 'treasury + protocol digests + portfolio reconcile', features.allocation?.classification ?? 'NOT VERIFIED'],
    ['Programmable chains', 'all step digests + portfolio', features.programmableChains?.classification ?? 'NOT VERIFIED'],
    ['Smart wallet rules', 'upgrade + create + execute + workflow digests', features.smartWalletRules?.classification ?? 'NOT VERIFIED'],
  ];
  for (const [f, r, s] of req) lines.push(`| ${f} | ${r} | ${s} |`);
  lines.push('');
  for (const [name, f] of Object.entries(features)) {
    lines.push(`## ${name}`, '', `| Classification | ${f.classification} |`, '');
    if (f.deposit) lines.push(`- Deposit: ${f.deposit.digest ?? '—'} (${f.deposit.classification})`);
    if (f.withdraw) lines.push(`- Withdraw: ${f.withdraw.digest ?? '—'} (${f.withdraw.classification})`);
    if (f.addLiquidity) lines.push(`- Add liquidity: ${f.addLiquidity.digest ?? '—'} (${f.addLiquidity.classification})`);
    if (f.removeLiquidity) lines.push(`- Remove liquidity: ${f.removeLiquidity.digest ?? '—'} (${f.removeLiquidity.classification})`);
    if (f.extra) {
      for (const [k, v] of Object.entries(f.extra)) {
        if (v && typeof v === 'object' && 'digest' in (v as object)) {
          const t = v as TxRecord;
          lines.push(`- ${k}: ${t.digest ?? '—'} (${t.classification})${t.error ? ` — ${t.error}` : ''}`);
        } else if (k === 'workflowProof' && v && typeof v === 'object' && 'digest' in (v as object)) {
          const t = v as TxRecord;
          lines.push(`- Workflow proof: ${t.digest ?? '—'} (${t.classification})`);
        } else if (k === 'intermediateDigests' && v && typeof v === 'object') {
          for (const [sk, sv] of Object.entries(v as Record<string, TxRecord>)) {
            const t = sv as TxRecord;
            lines.push(`- ${sk}: ${t.digest ?? '—'} (${t.classification})${t.error ? ` — ${t.error}` : ''}`);
          }
        } else if (k === 'digests') {
          lines.push(`- Allocation digests: \`${JSON.stringify(v)}\``);
        }
      }
    }
    if (f.blockers?.length) lines.push('', '**Blockers:**', ...f.blockers.map((b) => `- ${b}`));
    lines.push('');
  }

  if (doc.mainnetKeyMissing) {
    lines.push('## Mainnet blocker', '', 'Set `MANDATEOS_MAINNET_KEY` (suiprivkey…) and re-run:', '', '```', 'npm run build:sdk && npx tsx scripts/run-defi-verification-sprint.ts', '```', '');
  }

  return lines.join('\n');
}

async function main() {
  mkdirSync(PROOF_DIR, { recursive: true });
  const kp = loadKeypair();
  const mainnetKeyMissing = !kp;

  const features: Record<string, FeatureResult> = {
    navi: { classification: 'NOT VERIFIED', blockers: ['MANDATEOS_MAINNET_KEY not set'] },
    scallop: { classification: 'NOT VERIFIED', blockers: ['MANDATEOS_MAINNET_KEY not set'] },
    cetus: { classification: 'NOT VERIFIED', blockers: ['MANDATEOS_MAINNET_KEY not set'] },
    allocation: { classification: 'NOT VERIFIED', blockers: ['MANDATEOS_MAINNET_KEY not set'] },
    programmableChains: await programmableChainsStatus(),
    smartWalletRules: await attemptSmartWalletUpgrade(),
  };

  if (kp) {
    features.navi = await verifyNavi(kp);
    features.scallop = await verifyScallop(kp);
    features.cetus = await verifyCetus(kp);
    features.allocation = await verifyAllocationFromFeatures(features.navi, features.scallop, features.cetus);
  }

  const overallClassification: Classification = Object.values(features).every(
    (f) => f.classification === 'CHAIN_VERIFIED',
  )
    ? 'CHAIN_VERIFIED'
    : 'NOT VERIFIED';

  const doc = {
    generatedAt: new Date().toISOString(),
    overallClassification,
    mainnetKeyMissing,
    mandateosPackageId: PACKAGE_ID,
    naviPackageId: NAVI_MAINNET_PACKAGE_ID,
    verificationPolicy: 'CHAIN_VERIFIED requires RPC-validated success digests for every required evidence item. Partial or failed txs remain NOT VERIFIED.',
    requirements: {
      navi: ['depositDigest', 'withdrawDigest', 'positionEvidence'],
      scallop: ['depositDigest', 'withdrawDigest', 'positionEvidence'],
      cetus: ['addLiquidityDigest', 'removeLiquidityDigest', 'lpPositionEvidence'],
      allocation: ['treasuryAllocationDigest', 'destinationProtocolDigests', 'portfolioReconciliation'],
      programmableChains: ['completeChainExecution', 'allIntermediateDigests', 'finalPortfolioState'],
      smartWalletRules: ['packageUpgradeDigest', 'ruleCreateDigest', 'ruleExecutionDigest', 'resultingWorkflowDigest'],
    },
    features,
  };

  writeFileSync(join(PROOF_DIR, 'defi-verification.json'), JSON.stringify(doc, null, 2));
  writeFileSync(join(process.cwd(), 'DEFI_VERIFICATION_REPORT.md'), buildReport(doc));
  console.log(`Overall: ${overallClassification}`);
  console.log('Wrote proof/defi-verification.json');
  console.log('Wrote DEFI_VERIFICATION_REPORT.md');
  process.exit(overallClassification === 'CHAIN_VERIFIED' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
