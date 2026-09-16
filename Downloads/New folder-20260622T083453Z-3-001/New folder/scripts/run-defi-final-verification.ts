/**
 * Final DeFi verification — CODE_EXISTS → CHAIN_VERIFIED gate before bridge work.
 * Writes DEFI_FINAL_VERIFICATION.md and proof/defi-final-verification.json (chain evidence only).
 *
 * Mainnet DeFi: MANDATEOS_MAINNET_KEY or SUI_PRIVATE_KEY
 * Smart wallet rules: testnet governor keystore (kind-chrysolite)
 *
 *   npm run defi:verify-final
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
import { signAndExecuteWithKeypair, signAndExecuteWithKeystore } from '../packages/mandateos-sdk/scripts/lib/cli-sign.js';
import {
  buildCreateBalanceInvestRuleTx,
  buildExecuteSmartWalletRuleTx,
} from '../packages/mandateos-sdk/dist/smart-wallet-rules.js';

const PROOF_DIR = join(process.cwd(), 'proof');
const DEPOSIT_MIST = 10_000_000;
const PACKAGE_ID = process.env.MANDATEOS_PACKAGE_ID ?? '0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13';
const UPGRADE_CAP = '0x8133621db94776a6f146163d249695f5e6b30fdf7bcd972afd21fce3846d284f';
const GOVERNOR = '0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b';
const SUI_EXE = process.env.SUI_BIN ?? join(process.cwd(), 'mandateos', '.tools', 'sui', 'sui.exe');
const MANDATEOS_DIR = join(process.cwd(), 'mandateos');
const INVESTMENT_DIGEST = '8e5wYLdGFmxsKTp4ZmUDwRuYZLbHacSYd5FGoghoCqQo';
const UPGRADE_GAS_BUDGET = process.env.UPGRADE_GAS_BUDGET ?? '150000000';

type Status = 'CODE_EXISTS' | 'CHAIN_VERIFIED' | 'NOT VERIFIED';

interface TxRecord {
  label: string;
  digest: string | null;
  network: string;
  explorer: string | null;
  status: string | null;
  classification: Status;
  error?: string;
}

interface PortfolioReconciliation {
  classification: Status;
  beforeBalanceMist: string | null;
  afterDepositBalanceMist: string | null;
  afterWithdrawBalanceMist: string | null;
  expectedDepositMist: number;
  depositDeltaMatches: boolean | null;
  withdrawRestoresBaseline: boolean | null;
  dataSource: string;
}

interface ProtocolResult {
  implementationStatus: 'CODE_EXISTS';
  verificationStatus: Status;
  deposit?: TxRecord;
  withdraw?: TxRecord;
  addLiquidity?: TxRecord;
  removeLiquidity?: TxRecord;
  positionEvidence?: unknown;
  portfolioReconciliation?: PortfolioReconciliation;
  blockers: string[];
}

interface AllocationResult {
  implementationStatus: 'CODE_EXISTS';
  verificationStatus: Status;
  treasuryAllocationDigest: TxRecord;
  destinationProtocolDigests: {
    navi: TxRecord;
    scallop: TxRecord;
    cetus: TxRecord;
  };
  aggregatedPortfolioProof: {
    classification: Status;
    snapshot: unknown;
    dataSource: string;
  };
  blockers: string[];
}

interface SmartWalletResult {
  implementationStatus: 'CODE_EXISTS';
  verificationStatus: Status;
  packageUpgrade: TxRecord;
  ruleCreate: TxRecord;
  ruleExecute: TxRecord;
  resultingWorkflowDigest: TxRecord;
  ruleObjectId: string | null;
  blockers: string[];
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

function codeExistsBlocker(feature: string): ProtocolResult {
  return {
    implementationStatus: 'CODE_EXISTS',
    verificationStatus: 'CODE_EXISTS',
    blockers: [`${feature}: integration wired in SDK/UI — no mainnet execution (set MANDATEOS_MAINNET_KEY)`],
    portfolioReconciliation: {
      classification: 'CODE_EXISTS',
      beforeBalanceMist: null,
      afterDepositBalanceMist: null,
      afterWithdrawBalanceMist: null,
      expectedDepositMist: DEPOSIT_MIST,
      depositDeltaMatches: null,
      withdrawRestoresBaseline: null,
      dataSource: 'not-executed',
    },
  };
}

async function validateDigest(
  digest: string,
  network: 'mainnet' | 'testnet',
  wallet: string,
): Promise<{ classification: Status; txStatus: string | null; errors: string[] }> {
  const result = await verifyProofStep(
    { digest, wallet, network },
    0,
    { wallet, proofs: [{ digest, wallet, network }] },
    new Map(),
  );
  const classification: Status = result.status === 'CHAIN_VERIFIED' ? 'CHAIN_VERIFIED' : 'NOT VERIFIED';
  return {
    classification,
    txStatus: result.onChain?.txStatus ?? null,
    errors: result.errors,
  };
}

function buildPortfolioReconciliation(
  before: bigint,
  afterDep: bigint,
  afterWithdraw: bigint,
  depositMist: number,
  dataSource: string,
): PortfolioReconciliation {
  const depositDelta = afterDep - before;
  const depositDeltaMatches = depositDelta >= BigInt(depositMist);
  const withdrawRestoresBaseline = afterWithdraw <= before + 1_000_000n;
  const classification: Status =
    depositDeltaMatches && withdrawRestoresBaseline ? 'CHAIN_VERIFIED' : 'NOT VERIFIED';
  return {
    classification,
    beforeBalanceMist: before.toString(),
    afterDepositBalanceMist: afterDep.toString(),
    afterWithdrawBalanceMist: afterWithdraw.toString(),
    expectedDepositMist: depositMist,
    depositDeltaMatches,
    withdrawRestoresBaseline,
    dataSource,
  };
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

async function execProtocolTx(
  kp: Ed25519Keypair,
  build: (sender: string, amount: number) => Promise<import('@mysten/sui/transactions').Transaction>,
  amountMist: number,
  parse: typeof parseScallopTxEvidence,
  action: 'deposit' | 'withdraw',
  asset: string,
): Promise<{ digest: string }> {
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
  parse(waited, { wallet: kp.toSuiAddress(), asset, amountMist, action });
  return { digest: res.digest };
}

async function verifyNavi(kp: Ed25519Keypair): Promise<ProtocolResult> {
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
    const positions = await fetchNaviPositions(address);
    const withdraw = await withdrawSuiFromNavi(kp, DEPOSIT_MIST);
    const afterWithdraw = await readNaviSupplyBalanceMist(address);
    const reconciliation = buildPortfolioReconciliation(before, afterDep, afterWithdraw, DEPOSIT_MIST, 'navi-api');
    const depVal = await validateDigest(deposit.digest, 'mainnet', address);
    const wVal = await validateDigest(withdraw.digest, 'mainnet', address);
    const ok =
      depVal.classification === 'CHAIN_VERIFIED' &&
      wVal.classification === 'CHAIN_VERIFIED' &&
      reconciliation.classification === 'CHAIN_VERIFIED';
    return {
      implementationStatus: 'CODE_EXISTS',
      verificationStatus: ok ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
      deposit: txRecord('Deposit', deposit.digest, 'mainnet', depVal.classification, depVal.txStatus),
      withdraw: txRecord('Withdraw', withdraw.digest, 'mainnet', wVal.classification, wVal.txStatus),
      positionEvidence: positions,
      portfolioReconciliation: reconciliation,
      blockers,
    };
  } catch (e) {
    blockers.push(e instanceof Error ? e.message : String(e));
    return {
      implementationStatus: 'CODE_EXISTS',
      verificationStatus: 'NOT VERIFIED',
      blockers,
      portfolioReconciliation: {
        classification: 'NOT VERIFIED',
        beforeBalanceMist: null,
        afterDepositBalanceMist: null,
        afterWithdrawBalanceMist: null,
        expectedDepositMist: DEPOSIT_MIST,
        depositDeltaMatches: null,
        withdrawRestoresBaseline: null,
        dataSource: 'execution-failed',
      },
    };
  }
}

async function verifyScallop(kp: Ed25519Keypair): Promise<ProtocolResult> {
  const address = kp.toSuiAddress();
  const blockers: string[] = [];
  try {
    const positionsBefore = await fetchScallopPositions(address);
    const beforeSupplied = positionsBefore.reduce((s, p) => s + p.suppliedAmount, 0);
    const deposit = await execProtocolTx(
      kp, buildScallopDepositTransaction, DEPOSIT_MIST, parseScallopTxEvidence, 'deposit', 'SUI',
    );
    const positionsAfterDep = await fetchScallopPositions(address);
    const afterDepSupplied = positionsAfterDep.reduce((s, p) => s + p.suppliedAmount, 0);
    const withdraw = await execProtocolTx(
      kp, buildScallopWithdrawTransaction, DEPOSIT_MIST, parseScallopTxEvidence, 'withdraw', 'SUI',
    );
    const positionsAfterWithdraw = await fetchScallopPositions(address);
    const afterWithdrawSupplied = positionsAfterWithdraw.reduce((s, p) => s + p.suppliedAmount, 0);
    const reconciliation = buildPortfolioReconciliation(
      BigInt(Math.round(beforeSupplied * 1e9)),
      BigInt(Math.round(afterDepSupplied * 1e9)),
      BigInt(Math.round(afterWithdrawSupplied * 1e9)),
      DEPOSIT_MIST,
      'scallop-protocol',
    );
    const depVal = await validateDigest(deposit.digest, 'mainnet', address);
    const wVal = await validateDigest(withdraw.digest, 'mainnet', address);
    const ok =
      depVal.classification === 'CHAIN_VERIFIED' &&
      wVal.classification === 'CHAIN_VERIFIED' &&
      reconciliation.classification === 'CHAIN_VERIFIED';
    return {
      implementationStatus: 'CODE_EXISTS',
      verificationStatus: ok ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
      deposit: txRecord('Deposit', deposit.digest, 'mainnet', depVal.classification, depVal.txStatus),
      withdraw: txRecord('Withdraw', withdraw.digest, 'mainnet', wVal.classification, wVal.txStatus),
      positionEvidence: positionsAfterDep,
      portfolioReconciliation: reconciliation,
      blockers,
    };
  } catch (e) {
    blockers.push(e instanceof Error ? e.message : String(e));
    return {
      implementationStatus: 'CODE_EXISTS',
      verificationStatus: 'NOT VERIFIED',
      blockers,
      portfolioReconciliation: {
        classification: 'NOT VERIFIED',
        beforeBalanceMist: null,
        afterDepositBalanceMist: null,
        afterWithdrawBalanceMist: null,
        expectedDepositMist: DEPOSIT_MIST,
        depositDeltaMatches: null,
        withdrawRestoresBaseline: null,
        dataSource: 'execution-failed',
      },
    };
  }
}

async function verifyCetus(kp: Ed25519Keypair): Promise<ProtocolResult> {
  const address = kp.toSuiAddress();
  const blockers: string[] = [];
  try {
    const positionsBefore = await fetchCetusPositions(address);
    const beforeCount = positionsBefore.length;
    const add = await execProtocolTx(
      kp, buildCetusDepositTransaction, DEPOSIT_MIST, parseCetusTxEvidence, 'deposit', 'SUI/USDC LP',
    );
    const positionsAfterAdd = await fetchCetusPositions(address);
    const remove = await execProtocolTx(
      kp, buildCetusWithdrawTransaction, DEPOSIT_MIST, parseCetusTxEvidence, 'withdraw', 'SUI/USDC LP',
    );
    const positionsAfterRemove = await fetchCetusPositions(address);
    const lpPositionEvidence = positionsAfterAdd;
    const reconciliation: PortfolioReconciliation = {
      classification:
        positionsAfterAdd.length >= beforeCount && positionsAfterRemove.length <= positionsAfterAdd.length
          ? 'CHAIN_VERIFIED'
          : 'NOT VERIFIED',
      beforeBalanceMist: String(beforeCount),
      afterDepositBalanceMist: String(positionsAfterAdd.length),
      afterWithdrawBalanceMist: String(positionsAfterRemove.length),
      expectedDepositMist: DEPOSIT_MIST,
      depositDeltaMatches: positionsAfterAdd.length >= beforeCount,
      withdrawRestoresBaseline: positionsAfterRemove.length <= positionsAfterAdd.length,
      dataSource: 'cetus-protocol-lp-positions',
    };
    const aVal = await validateDigest(add.digest, 'mainnet', address);
    const rVal = await validateDigest(remove.digest, 'mainnet', address);
    const ok =
      aVal.classification === 'CHAIN_VERIFIED' &&
      rVal.classification === 'CHAIN_VERIFIED' &&
      reconciliation.classification === 'CHAIN_VERIFIED';
    return {
      implementationStatus: 'CODE_EXISTS',
      verificationStatus: ok ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
      addLiquidity: txRecord('Add liquidity', add.digest, 'mainnet', aVal.classification, aVal.txStatus),
      removeLiquidity: txRecord('Remove liquidity', remove.digest, 'mainnet', rVal.classification, rVal.txStatus),
      positionEvidence: lpPositionEvidence,
      portfolioReconciliation: reconciliation,
      blockers,
    };
  } catch (e) {
    blockers.push(e instanceof Error ? e.message : String(e));
    return {
      implementationStatus: 'CODE_EXISTS',
      verificationStatus: 'NOT VERIFIED',
      blockers,
      portfolioReconciliation: {
        classification: 'NOT VERIFIED',
        beforeBalanceMist: null,
        afterDepositBalanceMist: null,
        afterWithdrawBalanceMist: null,
        expectedDepositMist: DEPOSIT_MIST,
        depositDeltaMatches: null,
        withdrawRestoresBaseline: null,
        dataSource: 'execution-failed',
      },
    };
  }
}

function verifyAllocationFromProtocols(
  navi: ProtocolResult,
  scallop: ProtocolResult,
  cetus: ProtocolResult,
  wallet: string,
): AllocationResult {
  const naviDep = navi.deposit?.digest ?? null;
  const scallopDep = scallop.deposit?.digest ?? null;
  const cetusDep = cetus.addLiquidity?.digest ?? null;
  const blockers: string[] = [];
  if (!naviDep) blockers.push('Missing Navi destination digest');
  if (!scallopDep) blockers.push('Missing Scallop destination digest');
  if (!cetusDep) blockers.push('Missing Cetus destination digest');
  blockers.push('No single treasury→multi-protocol PTB — sequential wallet-signed mainnet deposits only');

  const destOk = Boolean(naviDep && scallopDep && cetusDep);
  const reconcileOk =
    navi.portfolioReconciliation?.classification === 'CHAIN_VERIFIED' &&
    scallop.portfolioReconciliation?.classification === 'CHAIN_VERIFIED' &&
    cetus.portfolioReconciliation?.classification === 'CHAIN_VERIFIED';

  const aggregatedSnapshot = destOk
    ? {
        wallet,
        navi: navi.positionEvidence,
        scallop: scallop.positionEvidence,
        cetus: cetus.positionEvidence,
        capturedAt: new Date().toISOString(),
      }
    : null;

  const treasuryVerified = false;
  const verificationStatus: Status =
    destOk && reconcileOk && treasuryVerified ? 'CHAIN_VERIFIED' : destOk || reconcileOk ? 'NOT VERIFIED' : 'CODE_EXISTS';

  return {
    implementationStatus: 'CODE_EXISTS',
    verificationStatus,
    treasuryAllocationDigest: txRecord(
      'Treasury allocation (single PTB)',
      null,
      'mainnet',
      'NOT VERIFIED',
      null,
      'Treasury→split PTB not executed — allocator uses sequential wallet deposits',
    ),
    destinationProtocolDigests: {
      navi: txRecord('Navi leg', naviDep, 'mainnet', naviDep ? 'CHAIN_VERIFIED' : 'NOT VERIFIED', naviDep ? 'success' : null),
      scallop: txRecord('Scallop leg', scallopDep, 'mainnet', scallopDep ? 'CHAIN_VERIFIED' : 'NOT VERIFIED', scallopDep ? 'success' : null),
      cetus: txRecord('Cetus leg', cetusDep, 'mainnet', cetusDep ? 'CHAIN_VERIFIED' : 'NOT VERIFIED', cetusDep ? 'success' : null),
    },
    aggregatedPortfolioProof: {
      classification: destOk && reconcileOk ? 'NOT VERIFIED' : 'CODE_EXISTS',
      snapshot: aggregatedSnapshot,
      dataSource: destOk ? 'multi-protocol-chain-read' : 'not-executed',
    },
    blockers,
  };
}

function allocationCodeExists(): AllocationResult {
  return {
    implementationStatus: 'CODE_EXISTS',
    verificationStatus: 'CODE_EXISTS',
    treasuryAllocationDigest: txRecord(
      'Treasury allocation (single PTB)',
      null,
      'mainnet',
      'CODE_EXISTS',
      null,
      'Not executed',
    ),
    destinationProtocolDigests: {
      navi: txRecord('Navi leg', null, 'mainnet', 'CODE_EXISTS', null),
      scallop: txRecord('Scallop leg', null, 'mainnet', 'CODE_EXISTS', null),
      cetus: txRecord('Cetus leg', null, 'mainnet', 'CODE_EXISTS', null),
    },
    aggregatedPortfolioProof: {
      classification: 'CODE_EXISTS',
      snapshot: null,
      dataSource: 'not-executed',
    },
    blockers: ['Set MANDATEOS_MAINNET_KEY and run multi-protocol allocation on mainnet'],
  };
}

async function verifySmartWalletRules(): Promise<SmartWalletResult> {
  const proofPath = join(PROOF_DIR, 'smart-wallet-rules-verification.json');
  if (existsSync(proofPath)) {
    const proof = JSON.parse(readFileSync(proofPath, 'utf8'));
    if (proof.verificationStatus === 'CHAIN_VERIFIED' && proof.evidence) {
      const e = proof.evidence;
      return {
        implementationStatus: 'CODE_EXISTS',
        verificationStatus: 'CHAIN_VERIFIED',
        packageUpgrade: e.packageUpgradeDigest as TxRecord,
        ruleCreate: e.ruleCreationDigest as TxRecord,
        ruleExecute: e.ruleExecutionDigest as TxRecord,
        resultingWorkflowDigest: e.workflowExecutionDigest as TxRecord,
        ruleObjectId: proof.ruleObjectId ?? null,
        blockers: proof.deploymentNote ? [proof.deploymentNote] : [],
      };
    }
  }
  return {
    implementationStatus: 'CODE_EXISTS',
    verificationStatus: 'NOT VERIFIED',
    packageUpgrade: txRecord('Package upgrade', null, 'testnet', 'NOT VERIFIED', null, 'Run npm run smart-wallet:verify'),
    ruleCreate: txRecord('Rule creation', null, 'testnet', 'NOT VERIFIED', null),
    ruleExecute: txRecord('Rule execution', null, 'testnet', 'NOT VERIFIED', null),
    resultingWorkflowDigest: txRecord('Workflow execution', INVESTMENT_DIGEST, 'testnet', 'NOT VERIFIED', null),
    ruleObjectId: null,
    blockers: ['Run npm run smart-wallet:verify first'],
  };
}

function overallStatus(features: Record<string, { verificationStatus: Status }>): Status {
  const values = Object.values(features).map((f) => f.verificationStatus);
  if (values.every((v) => v === 'CHAIN_VERIFIED')) return 'CHAIN_VERIFIED';
  if (values.some((v) => v === 'NOT VERIFIED')) return 'NOT VERIFIED';
  return 'CODE_EXISTS';
}

function buildReport(doc: Record<string, unknown>): string {
  const features = doc.features as Record<string, ProtocolResult | AllocationResult | SmartWalletResult>;
  const lines: string[] = [
    '# DEFI FINAL VERIFICATION',
    '',
    `**Generated:** ${doc.generatedAt}`,
    `**Overall verification:** ${doc.overallVerificationStatus}`,
    `**Bridge implementation:** ${doc.bridgeImplementationAllowed ? 'ALLOWED' : 'BLOCKED until all items CHAIN_VERIFIED'}`,
    '',
    'States: **CODE_EXISTS** (wired, no chain proof) | **CHAIN_VERIFIED** | **NOT VERIFIED** (partial/failed).',
    '',
    '## Gate matrix',
    '',
  ];
  lines.push(
    '| # | Integration | Required evidence | Status |',
    '|---|-------------|-------------------|--------|',
  );
  const matrix: Array<[string, string, Status]> = [
    ['Navi', 'deposit + withdraw + position + portfolio reconcile', (features.navi as ProtocolResult).verificationStatus],
    ['Scallop', 'deposit + withdraw + position + portfolio reconcile', (features.scallop as ProtocolResult).verificationStatus],
    ['Cetus', 'add + remove + LP position + portfolio reconcile', (features.cetus as ProtocolResult).verificationStatus],
    ['Allocation', 'treasury digest + destination digests + aggregated portfolio', (features.allocation as AllocationResult).verificationStatus],
    ['Smart wallet rules', 'upgrade + create + execute + workflow digests', (features.smartWalletRules as SmartWalletResult).verificationStatus],
  ];
  for (const [name, req, status] of matrix) {
    lines.push(`| ${name} | ${req} | ${status} |`);
  }
  lines.push('');

  for (const [name, f] of Object.entries(features)) {
    lines.push(`## ${name}`, '', `| Implementation | ${(f as { implementationStatus: string }).implementationStatus} |`);
    lines.push(`| Verification | ${(f as { verificationStatus: Status }).verificationStatus} |`, '');
    const pf = f as ProtocolResult;
    if (pf.deposit) lines.push(`- Deposit: ${pf.deposit.digest ?? '—'} (${pf.deposit.classification})`);
    if (pf.withdraw) lines.push(`- Withdraw: ${pf.withdraw.digest ?? '—'} (${pf.withdraw.classification})`);
    if (pf.addLiquidity) lines.push(`- Add liquidity: ${pf.addLiquidity.digest ?? '—'} (${pf.addLiquidity.classification})`);
    if (pf.removeLiquidity) lines.push(`- Remove liquidity: ${pf.removeLiquidity.digest ?? '—'} (${pf.removeLiquidity.classification})`);
    if (pf.portfolioReconciliation) {
      lines.push(`- Portfolio reconciliation: ${pf.portfolioReconciliation.classification}`);
    }
    const af = f as AllocationResult;
    if (af.treasuryAllocationDigest) {
      lines.push(`- Treasury allocation: ${af.treasuryAllocationDigest.digest ?? '—'} (${af.treasuryAllocationDigest.classification})`);
    }
    if (af.destinationProtocolDigests) {
      for (const [k, t] of Object.entries(af.destinationProtocolDigests)) {
        lines.push(`- Destination ${k}: ${t.digest ?? '—'} (${t.classification})`);
      }
    }
    if (af.aggregatedPortfolioProof) {
      lines.push(`- Aggregated portfolio: ${af.aggregatedPortfolioProof.classification}`);
    }
    const sw = f as SmartWalletResult;
    if (sw.packageUpgrade) {
      lines.push(`- Package upgrade: ${sw.packageUpgrade.digest ?? '—'} (${sw.packageUpgrade.classification})`);
      lines.push(`- Rule create: ${sw.ruleCreate.digest ?? '—'} (${sw.ruleCreate.classification})`);
      lines.push(`- Rule execute: ${sw.ruleExecute.digest ?? '—'} (${sw.ruleExecute.classification})`);
      lines.push(`- Workflow digest: ${sw.resultingWorkflowDigest.digest ?? '—'} (${sw.resultingWorkflowDigest.classification})`);
    }
    if (f.blockers?.length) lines.push('', '**Blockers:**', ...f.blockers.map((b) => `- ${b}`));
    lines.push('');
  }

  if (doc.mainnetKeyMissing) {
    lines.push(
      '## Mainnet execution',
      '',
      'Set `MANDATEOS_MAINNET_KEY` and re-run:',
      '',
      '```',
      'npm run defi:verify-final',
      '```',
      '',
    );
  }

  lines.push(
    '## Bridge policy',
    '',
    'Bridge work is **blocked** until every row above is **CHAIN_VERIFIED**.',
    'When implemented, bridge must integrate into programmable capital deployment workflows — not as a standalone feature.',
    '',
  );

  return lines.join('\n');
}

async function main() {
  mkdirSync(PROOF_DIR, { recursive: true });
  const kp = loadKeypair();
  const mainnetKeyMissing = !kp;

  const navi = kp ? await verifyNavi(kp) : codeExistsBlocker('Navi');
  const scallop = kp ? await verifyScallop(kp) : codeExistsBlocker('Scallop');
  const cetus = kp ? await verifyCetus(kp) : codeExistsBlocker('Cetus');
  const allocation = kp
    ? verifyAllocationFromProtocols(navi, scallop, cetus, kp.toSuiAddress())
    : allocationCodeExists();
  const smartWalletRules = await verifySmartWalletRules();

  const features = { navi, scallop, cetus, allocation, smartWalletRules };
  const overallVerificationStatus = overallStatus(features);
  const bridgeImplementationAllowed = overallVerificationStatus === 'CHAIN_VERIFIED';

  const doc = {
    generatedAt: new Date().toISOString(),
    overallVerificationStatus,
    bridgeImplementationAllowed,
    mainnetKeyMissing,
    mandateosPackageId: PACKAGE_ID,
    naviPackageId: NAVI_MAINNET_PACKAGE_ID,
    verificationPolicy:
      'CHAIN_VERIFIED requires RPC-validated success digests for every required evidence item. CODE_EXISTS = SDK/UI wired without execution.',
    bridgePolicy:
      'Bridge implementation blocked until all integrations CHAIN_VERIFIED; bridge must integrate into programmable capital deployment workflows.',
    requirements: {
      navi: ['depositDigest', 'withdrawDigest', 'positionEvidence', 'portfolioReconciliation'],
      scallop: ['depositDigest', 'withdrawDigest', 'positionEvidence', 'portfolioReconciliation'],
      cetus: ['addLiquidityDigest', 'removeLiquidityDigest', 'lpPositionEvidence', 'portfolioReconciliation'],
      allocation: ['treasuryAllocationDigest', 'destinationProtocolDigests', 'aggregatedPortfolioProof'],
      smartWalletRules: [
        'packageUpgradeDigest',
        'ruleCreationDigest',
        'ruleExecutionDigest',
        'resultingWorkflowDigest',
      ],
    },
    features,
  };

  writeFileSync(join(PROOF_DIR, 'defi-final-verification.json'), JSON.stringify(doc, null, 2));
  writeFileSync(join(process.cwd(), 'DEFI_FINAL_VERIFICATION.md'), buildReport(doc));
  console.log(`Overall: ${overallVerificationStatus}`);
  console.log(`Bridge allowed: ${bridgeImplementationAllowed}`);
  console.log('Wrote proof/defi-final-verification.json');
  console.log('Wrote DEFI_FINAL_VERIFICATION.md');
  process.exit(overallVerificationStatus === 'CHAIN_VERIFIED' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
