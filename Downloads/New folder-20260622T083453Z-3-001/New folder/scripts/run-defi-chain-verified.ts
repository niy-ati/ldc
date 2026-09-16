/**
 * DeFi chain verification from wallet-signed Proof Center exports — no private keys.
 *
 *   npm run defi:chain-verify -- --wallet=0xYOUR... --proof=proof/proof.json
 *
 * Execute transactions in production UI (Slush mainnet), export proof.json, then run this.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { verifyProofStep } from '../packages/mandateos-sdk/dist/proof/verify-proof.js';
import {
  fetchNaviPositions,
  readNaviSupplyBalanceMist,
  NAVI_MAINNET_PACKAGE_ID,
} from '../packages/mandateos-sdk/dist/defi/navi-integration.js';
import { fetchScallopPositions } from '../packages/mandateos-sdk/dist/defi/scallop-integration.js';
import { fetchCetusPositions } from '../packages/mandateos-sdk/dist/defi/cetus-integration.js';

const PROOF_DIR = join(process.cwd(), 'proof');
const WEIGHTS = { navi: 40, scallop: 40, cetus: 20 };

type Status = 'CODE_EXISTS' | 'CHAIN_VERIFIED' | 'NOT VERIFIED';

interface ExportedProofStep {
  digest: string;
  wallet: string;
  network: string;
  protocol?: string;
  naviAction?: 'deposit' | 'withdraw';
  workflowType?: string;
  action?: string;
  amountMist?: number;
  status?: string;
  explorerUrl?: string;
  allocationUnified?: boolean;
  objectIds?: Record<string, string>;
}

interface ProofExportDocument {
  wallet: string;
  proofs: ExportedProofStep[];
}

interface TxRecord {
  label: string;
  digest: string | null;
  network: string;
  explorer: string | null;
  status: string | null;
  classification: Status;
  amountMist?: number;
  error?: string;
  rpcVerified?: boolean;
}

interface PortfolioReconciliation {
  classification: Status;
  walletAddress: string;
  walletBalanceSui: number | null;
  positionSnapshot: unknown;
  depositProofCount: number;
  withdrawProofCount: number;
  dataSource: string;
}

interface ProtocolResult {
  verificationStatus: Status;
  verificationMethod: 'wallet-signed-ui';
  depositDigest?: TxRecord;
  withdrawDigest?: TxRecord;
  addLiquidityDigest?: TxRecord;
  removeLiquidityDigest?: TxRecord;
  positionProof?: unknown;
  portfolioReconciliation?: PortfolioReconciliation;
  blockers: string[];
}

interface AllocationResult {
  verificationStatus: Status;
  verificationMethod: 'wallet-signed-ui';
  policy: { naviPct: number; scallopPct: number; cetusPct: number };
  treasurySplitDigest: TxRecord;
  protocolDepositDigests: { navi: TxRecord; scallop: TxRecord; cetus: TxRecord };
  finalPortfolioProof: { classification: Status; snapshot: unknown; dataSource: string };
  blockers: string[];
}

function parseArgs(): { wallet: string | null; proofPath: string | null } {
  let wallet: string | null = process.env.DEFI_VERIFY_WALLET ?? null;
  let proofPath: string | null = null;
  for (const arg of process.argv.slice(2)) {
    if (arg.startsWith('--wallet=')) wallet = arg.slice('--wallet='.length);
    if (arg.startsWith('--proof=')) proofPath = arg.slice('--proof='.length);
  }
  if (!proofPath && existsSync(join(PROOF_DIR, 'proof.json'))) {
    proofPath = join(PROOF_DIR, 'proof.json');
  }
  return { wallet, proofPath };
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
  extra?: { error?: string; amountMist?: number; rpcVerified?: boolean },
): TxRecord {
  return {
    label,
    digest,
    network,
    explorer: digest ? explorer(network, digest) : null,
    status,
    classification,
    error: extra?.error,
    amountMist: extra?.amountMist,
    rpcVerified: extra?.rpcVerified,
  };
}

function loadProofExport(path: string | null): ProofExportDocument | null {
  if (!path || !existsSync(path)) return null;
  return JSON.parse(readFileSync(path, 'utf8')) as ProofExportDocument;
}

function normWallet(w: string): string {
  return w.toLowerCase();
}

function isSuccessProof(p: ExportedProofStep, wallet: string): boolean {
  return (
    normWallet(p.wallet) === normWallet(wallet) &&
    p.network === 'mainnet' &&
    (p.status === 'success' || !p.status) &&
    !!p.digest
  );
}

function findProtocolProof(
  proofs: ExportedProofStep[],
  wallet: string,
  protocol: string,
  action: 'deposit' | 'withdraw',
  workflowType?: string,
): ExportedProofStep | undefined {
  const matches = proofs.filter((p) => {
    if (!isSuccessProof(p, wallet)) return false;
    const proto = p.protocol ?? p.workflowType;
    if (proto !== protocol) return false;
    if (p.naviAction !== action) return false;
    if (workflowType && p.workflowType !== workflowType) return false;
    if (!workflowType && p.workflowType === 'allocation') return false;
    return true;
  });
  return matches.sort((a, b) => (b as { timestampMs?: number }).timestampMs! - (a as { timestampMs?: number }).timestampMs!)[0]
    ?? matches[0];
}

function findUnifiedAllocationProof(
  proofs: ExportedProofStep[],
  wallet: string,
): ExportedProofStep | undefined {
  return proofs.find(
    (p) =>
      isSuccessProof(p, wallet) &&
      p.workflowType === 'allocation' &&
      (p.allocationUnified === true ||
        p.action?.includes('Treasury Multi-Protocol Allocation') ||
        p.action?.includes('Multi-Protocol Allocation')),
  );
}

async function validateDigest(
  digest: string,
  wallet: string,
): Promise<{ classification: Status; txStatus: string | null; rpcVerified: boolean }> {
  const result = await verifyProofStep(
    { digest, wallet, network: 'mainnet' },
    0,
    { wallet, proofs: [{ digest, wallet, network: 'mainnet' }] },
    new Map(),
  );
  return {
    classification: result.status === 'CHAIN_VERIFIED' ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
    txStatus: result.onChain?.txStatus ?? null,
    rpcVerified: result.status === 'CHAIN_VERIFIED',
  };
}

async function proofToTxRecord(
  label: string,
  proof: ExportedProofStep | undefined,
  wallet: string,
): Promise<TxRecord> {
  if (!proof?.digest) {
    return txRecord(label, null, 'mainnet', 'CODE_EXISTS', null, {
      error: 'Missing wallet-signed digest — complete production UI flow and export proof.json',
    });
  }
  const v = await validateDigest(proof.digest, wallet);
  return txRecord(label, proof.digest, 'mainnet', v.classification, v.txStatus, {
    amountMist: proof.amountMist,
    rpcVerified: v.rpcVerified,
  });
}

async function verifyProtocolPair(
  proofs: ExportedProofStep[],
  wallet: string,
  protocol: string,
  depositLabel: string,
  withdrawLabel: string,
  readPosition: () => Promise<unknown>,
): Promise<ProtocolResult> {
  const blockers: string[] = [];
  const depProof = findProtocolProof(proofs, wallet, protocol, 'deposit');
  const wProof = findProtocolProof(proofs, wallet, protocol, 'withdraw');

  if (!depProof) blockers.push(`${protocol}: missing wallet-signed deposit in proof.json`);
  if (!wProof) blockers.push(`${protocol}: missing wallet-signed withdraw in proof.json`);

  const depositDigest = await proofToTxRecord(depositLabel, depProof, wallet);
  const withdrawDigest = await proofToTxRecord(withdrawLabel, wProof, wallet);

  let positionProof: unknown = null;
  try {
    positionProof = await readPosition();
  } catch (e) {
    blockers.push(`${protocol}: position read failed — ${e instanceof Error ? e.message : String(e)}`);
  }

  const client = new SuiClient({ url: getFullnodeUrl('mainnet') });
  let walletBalanceSui: number | null = null;
  try {
    const bal = await client.getBalance({ owner: wallet });
    walletBalanceSui = Number(bal.totalBalance) / 1e9;
  } catch {
    blockers.push(`${protocol}: wallet balance read failed`);
  }

  const depositProofCount = proofs.filter(
    (p) => isSuccessProof(p, wallet) && (p.protocol ?? p.workflowType) === protocol && p.naviAction === 'deposit',
  ).length;
  const withdrawProofCount = proofs.filter(
    (p) => isSuccessProof(p, wallet) && (p.protocol ?? p.workflowType) === protocol && p.naviAction === 'withdraw',
  ).length;

  const portfolioReconciliation: PortfolioReconciliation = {
    classification:
      depositDigest.classification === 'CHAIN_VERIFIED' &&
      withdrawDigest.classification === 'CHAIN_VERIFIED'
        ? 'CHAIN_VERIFIED'
        : depositDigest.digest && withdrawDigest.digest
          ? 'NOT VERIFIED'
          : 'CODE_EXISTS',
    walletAddress: wallet,
    walletBalanceSui,
    positionSnapshot: positionProof,
    depositProofCount,
    withdrawProofCount,
    dataSource: 'proof-export-rpc-and-live-protocol-read',
  };

  const ok =
    depositDigest.classification === 'CHAIN_VERIFIED' &&
    withdrawDigest.classification === 'CHAIN_VERIFIED' &&
    portfolioReconciliation.classification === 'CHAIN_VERIFIED';

  return {
    verificationStatus: ok ? 'CHAIN_VERIFIED' : blockers.length || !depProof || !wProof ? 'CODE_EXISTS' : 'NOT VERIFIED',
    verificationMethod: 'wallet-signed-ui',
    depositDigest,
    withdrawDigest,
    positionProof,
    portfolioReconciliation,
    blockers,
  };
}

async function verifyCetus(
  proofs: ExportedProofStep[],
  wallet: string,
): Promise<ProtocolResult> {
  const result = await verifyProtocolPair(
    proofs,
    wallet,
    'cetus',
    'Add liquidity',
    'Remove liquidity',
    () => fetchCetusPositions(wallet),
  );
  return {
    ...result,
    addLiquidityDigest: result.depositDigest,
    removeLiquidityDigest: result.withdrawDigest,
    depositDigest: undefined,
    withdrawDigest: undefined,
  };
}

function findAllocationDeposit(
  proofs: ExportedProofStep[],
  wallet: string,
  protocol: string,
): ExportedProofStep | undefined {
  return proofs.find(
    (p) =>
      isSuccessProof(p, wallet) &&
      p.workflowType === 'allocation' &&
      p.protocol === protocol &&
      p.naviAction === 'deposit',
  );
}

async function verifyAllocation(
  proofs: ExportedProofStep[],
  wallet: string,
): Promise<AllocationResult> {
  const policy = { naviPct: WEIGHTS.navi, scallopPct: WEIGHTS.scallop, cetusPct: WEIGHTS.cetus };
  const blockers: string[] = [];
  const unified = findUnifiedAllocationProof(proofs, wallet);

  let treasurySplitDigest: TxRecord;
  let navi: TxRecord;
  let scallop: TxRecord;
  let cetus: TxRecord;

  if (unified?.digest) {
    const naviDigest = unified.objectIds?.naviDigest ?? unified.digest;
    const scallopDigest = unified.objectIds?.scallopDigest;
    const cetusDigest = unified.objectIds?.cetusDigest;

    const naviVal = await validateDigest(naviDigest, wallet);
    const scallopVal = scallopDigest ? await validateDigest(scallopDigest, wallet) : naviVal;
    const cetusVal = cetusDigest ? await validateDigest(cetusDigest, wallet) : naviVal;

    const bundleOk =
      naviVal.classification === 'CHAIN_VERIFIED' &&
      scallopVal.classification === 'CHAIN_VERIFIED' &&
      cetusVal.classification === 'CHAIN_VERIFIED';

    treasurySplitDigest = txRecord(
      'Treasury split (allocation bundle)',
      unified.digest,
      'mainnet',
      bundleOk ? 'CHAIN_VERIFIED' : 'NOT VERIFIED',
      naviVal.txStatus,
      { amountMist: unified.amountMist, rpcVerified: bundleOk },
    );
    navi = txRecord('Navi 40%', naviDigest, 'mainnet', naviVal.classification, naviVal.txStatus, { rpcVerified: naviVal.rpcVerified });
    scallop = txRecord('Scallop 40%', scallopDigest ?? null, 'mainnet', scallopVal.classification, scallopVal.txStatus, { rpcVerified: scallopVal.rpcVerified });
    cetus = txRecord('Cetus 20%', cetusDigest ?? null, 'mainnet', cetusVal.classification, cetusVal.txStatus, { rpcVerified: cetusVal.rpcVerified });
  } else {
    treasurySplitDigest = txRecord(
      'Treasury split (allocation bundle)',
      null,
      'mainnet',
      'CODE_EXISTS',
      null,
      { error: 'Execute allocation on /app/allocation and export proof.json' },
    );
    const naviProof = findAllocationDeposit(proofs, wallet, 'navi');
    const scallopProof = findAllocationDeposit(proofs, wallet, 'scallop');
    const cetusProof = findAllocationDeposit(proofs, wallet, 'cetus');
    if (!naviProof) blockers.push('Allocation: missing Navi deposit proof (workflowType=allocation)');
    if (!scallopProof) blockers.push('Allocation: missing Scallop deposit proof (workflowType=allocation)');
    if (!cetusProof) blockers.push('Allocation: missing Cetus deposit proof (workflowType=allocation)');
    navi = await proofToTxRecord('Navi 40%', naviProof, wallet);
    scallop = await proofToTxRecord('Scallop 40%', scallopProof, wallet);
    cetus = await proofToTxRecord('Cetus 20%', cetusProof, wallet);
  }

  let snapshot: unknown = null;
  try {
    snapshot = {
      wallet,
      capturedAt: new Date().toISOString(),
      navi: await fetchNaviPositions(wallet),
      scallop: await fetchScallopPositions(wallet),
      cetus: await fetchCetusPositions(wallet),
    };
  } catch (e) {
    blockers.push(`Allocation portfolio snapshot failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  const depositsOk =
    navi.classification === 'CHAIN_VERIFIED' &&
    scallop.classification === 'CHAIN_VERIFIED' &&
    cetus.classification === 'CHAIN_VERIFIED';

  const treasuryOk = treasurySplitDigest.classification === 'CHAIN_VERIFIED';

  const finalPortfolioProof = {
    classification: (depositsOk && snapshot ? 'CHAIN_VERIFIED' : 'CODE_EXISTS') as Status,
    snapshot: depositsOk && snapshot ? snapshot : null,
    dataSource: 'proof-export-rpc-and-live-protocol-read',
  };

  let verificationStatus: Status = 'CODE_EXISTS';
  if (treasuryOk && depositsOk && finalPortfolioProof.classification === 'CHAIN_VERIFIED') {
    verificationStatus = 'CHAIN_VERIFIED';
  } else if (treasuryOk || depositsOk) {
    verificationStatus = 'NOT VERIFIED';
    if (!treasuryOk) blockers.push('Treasury unified PTB digest not RPC-verified');
    if (!depositsOk) blockers.push('Allocation protocol deposit proofs not all RPC-verified');
  } else if (blockers.length === 0 && !unified) {
    blockers.push('Complete allocation on /app/allocation and export proof.json');
  }

  return {
    verificationStatus,
    verificationMethod: 'wallet-signed-ui',
    policy,
    treasurySplitDigest,
    protocolDepositDigests: { navi, scallop, cetus },
    finalPortfolioProof,
    blockers,
  };
}

function overallStatus(features: Record<string, { verificationStatus: Status }>): Status {
  const values = Object.values(features).map((f) => f.verificationStatus);
  if (values.every((v) => v === 'CHAIN_VERIFIED')) return 'CHAIN_VERIFIED';
  if (values.some((v) => v === 'NOT VERIFIED')) return 'NOT VERIFIED';
  return 'CODE_EXISTS';
}

function buildReport(doc: Record<string, unknown>): string {
  const f = doc.integrations as {
    navi: ProtocolResult;
    scallop: ProtocolResult;
    cetus: ProtocolResult;
    allocation: AllocationResult;
  };
  const lines = [
    '# DEFI CHAIN VERIFIED REPORT',
    '',
    `**Generated:** ${doc.generatedAt}`,
    `**Overall:** ${doc.overallClassification}`,
    `**Verification method:** Wallet-signed Slush transactions via production UI — no private keys`,
    `**Reference wallet:** ${doc.verifyWallet ?? '—'}`,
    `**Proof source:** ${doc.proofSource ?? '—'}`,
    `**Bridge:** ${doc.bridgeImplementationAllowed ? 'ALLOWED' : 'BLOCKED — DeFi integrations must all be CHAIN_VERIFIED first'}`,
    '',
    'See `DEFI_WALLET_VERIFICATION_FLOW.md` for the exact production UI steps.',
    '',
    '| Integration | Required | Status |',
    '|-------------|----------|--------|',
    `| Navi | deposit + withdraw + position + portfolio reconcile | ${f.navi.verificationStatus} |`,
    `| Scallop | deposit + withdraw + position + portfolio reconcile | ${f.scallop.verificationStatus} |`,
    `| Cetus | add + remove + LP position + portfolio reconcile | ${f.cetus.verificationStatus} |`,
    `| Allocation | treasury split + protocol deposits + final portfolio | ${f.allocation.verificationStatus} |`,
    '',
    '## Navi',
    '',
    `- Deposit: ${f.navi.depositDigest?.digest ?? '—'} (${f.navi.depositDigest?.classification ?? '—'})`,
    `- Withdraw: ${f.navi.withdrawDigest?.digest ?? '—'} (${f.navi.withdrawDigest?.classification ?? '—'})`,
    `- Portfolio reconciliation: ${f.navi.portfolioReconciliation?.classification ?? '—'}`,
    '',
    '## Scallop',
    '',
    `- Deposit: ${f.scallop.depositDigest?.digest ?? '—'} (${f.scallop.depositDigest?.classification ?? '—'})`,
    `- Withdraw: ${f.scallop.withdrawDigest?.digest ?? '—'} (${f.scallop.withdrawDigest?.classification ?? '—'})`,
    `- Portfolio reconciliation: ${f.scallop.portfolioReconciliation?.classification ?? '—'}`,
    '',
    '## Cetus',
    '',
    `- Add liquidity: ${f.cetus.addLiquidityDigest?.digest ?? '—'} (${f.cetus.addLiquidityDigest?.classification ?? '—'})`,
    `- Remove liquidity: ${f.cetus.removeLiquidityDigest?.digest ?? '—'} (${f.cetus.removeLiquidityDigest?.classification ?? '—'})`,
    `- Portfolio reconciliation: ${f.cetus.portfolioReconciliation?.classification ?? '—'}`,
    '',
    '## Allocation (40% Navi / 40% Scallop / 20% Cetus)',
    '',
    `- Treasury split: ${f.allocation.treasurySplitDigest.digest ?? '—'} (${f.allocation.treasurySplitDigest.classification})`,
    `- Navi deposit: ${f.allocation.protocolDepositDigests.navi.digest ?? '—'} (${f.allocation.protocolDepositDigests.navi.classification})`,
    `- Scallop deposit: ${f.allocation.protocolDepositDigests.scallop.digest ?? '—'} (${f.allocation.protocolDepositDigests.scallop.classification})`,
    `- Cetus deposit: ${f.allocation.protocolDepositDigests.cetus.digest ?? '—'} (${f.allocation.protocolDepositDigests.cetus.classification})`,
    `- Final portfolio: ${f.allocation.finalPortfolioProof.classification}`,
    '',
    '## Export verification (after UI flow)',
    '',
    '```bash',
    'npm run defi:chain-verify -- --wallet=0xYOUR_WALLET --proof=proof/proof.json',
    '```',
    '',
  ];

  const allBlockers = [
    ...(doc.globalBlockers as string[] ?? []),
    ...f.navi.blockers,
    ...f.scallop.blockers,
    ...f.cetus.blockers,
    ...f.allocation.blockers,
  ].filter(Boolean);
  if (allBlockers.length) {
    lines.push('## Blockers', '', ...allBlockers.map((b) => `- ${b}`), '');
  }

  return lines.join('\n');
}

async function main() {
  mkdirSync(PROOF_DIR, { recursive: true });
  const { wallet, proofPath } = parseArgs();
  const globalBlockers: string[] = [];

  if (!wallet) {
    globalBlockers.push('Provide --wallet=0x... (wallet that signed DeFi transactions in production UI)');
  }

  const proofDoc = loadProofExport(proofPath);
  if (!proofDoc) {
    globalBlockers.push(
      'No proof.json found — export from Proof Center after completing Slush-signed DeFi transactions',
    );
  } else if (wallet && normWallet(proofDoc.wallet) !== normWallet(wallet)) {
    globalBlockers.push(
      `proof.json wallet ${proofDoc.wallet} does not match --wallet=${wallet}`,
    );
  }

  const proofs = proofDoc?.proofs ?? [];
  const verifyWallet = wallet ?? proofDoc?.wallet ?? '';

  const emptyProtocol = (name: string): ProtocolResult => ({
    verificationStatus: 'CODE_EXISTS',
    verificationMethod: 'wallet-signed-ui',
    blockers: [`${name}: complete production UI flow and export proof.json`],
    portfolioReconciliation: {
      classification: 'CODE_EXISTS',
      walletAddress: verifyWallet,
      walletBalanceSui: null,
      positionSnapshot: null,
      depositProofCount: 0,
      withdrawProofCount: 0,
      dataSource: 'not-executed',
    },
  });

  let navi: ProtocolResult;
  let scallop: ProtocolResult;
  let cetus: ProtocolResult;
  let allocation: AllocationResult;

  if (!verifyWallet || proofs.length === 0) {
    navi = emptyProtocol('Navi');
    scallop = emptyProtocol('Scallop');
    cetus = { ...emptyProtocol('Cetus'), addLiquidityDigest: undefined, removeLiquidityDigest: undefined };
    allocation = {
      verificationStatus: 'CODE_EXISTS',
      verificationMethod: 'wallet-signed-ui',
      policy: { naviPct: 40, scallopPct: 40, cetusPct: 20 },
      treasurySplitDigest: txRecord('Treasury split', null, 'mainnet', 'CODE_EXISTS', null),
      protocolDepositDigests: {
        navi: txRecord('Navi 40%', null, 'mainnet', 'CODE_EXISTS', null),
        scallop: txRecord('Scallop 40%', null, 'mainnet', 'CODE_EXISTS', null),
        cetus: txRecord('Cetus 20%', null, 'mainnet', 'CODE_EXISTS', null),
      },
      finalPortfolioProof: { classification: 'CODE_EXISTS', snapshot: null, dataSource: 'not-executed' },
      blockers: ['Export proof.json from Proof Center after Slush-signed transactions'],
    };
  } else {
    navi = await verifyProtocolPair(
      proofs,
      verifyWallet,
      'navi',
      'Deposit',
      'Withdraw',
      async () => ({
        supplyBalanceMist: (await readNaviSupplyBalanceMist(verifyWallet)).toString(),
        positions: await fetchNaviPositions(verifyWallet),
      }),
    );
    scallop = await verifyProtocolPair(
      proofs,
      verifyWallet,
      'scallop',
      'Deposit',
      'Withdraw',
      () => fetchScallopPositions(verifyWallet),
    );
    cetus = await verifyCetus(proofs, verifyWallet);
    allocation = await verifyAllocation(proofs, verifyWallet);
  }

  const integrations = { navi, scallop, cetus, allocation };
  const overallClassification = globalBlockers.length ? 'CODE_EXISTS' : overallStatus(integrations);

  const doc = {
    generatedAt: new Date().toISOString(),
    overallClassification,
    bridgeImplementationAllowed: overallClassification === 'CHAIN_VERIFIED',
    verifyWallet: verifyWallet || null,
    proofSource: proofPath,
    proofStepCount: proofs.length,
    verificationMethod: 'wallet-signed-ui-slush',
    privateKeyRequired: false,
    naviPackageId: NAVI_MAINNET_PACKAGE_ID,
    verificationPolicy:
      'CHAIN_VERIFIED requires Slush wallet-signed digests in proof.json, RPC validation, and live protocol position reads. No CLI private keys.',
    bridgePolicy:
      'Bridge blocked until all DeFi integrations CHAIN_VERIFIED; bridge integrates into programmable capital deployment — not standalone.',
    globalBlockers,
    requirements: {
      navi: ['depositDigest', 'withdrawDigest', 'positionProof', 'portfolioReconciliation'],
      scallop: ['depositDigest', 'withdrawDigest', 'positionProof', 'portfolioReconciliation'],
      cetus: ['addLiquidityDigest', 'removeLiquidityDigest', 'lpPositionProof', 'portfolioReconciliation'],
      allocation: ['treasurySplitDigest', 'protocolDepositDigests', 'finalPortfolioProof'],
    },
    integrations,
  };

  writeFileSync(join(PROOF_DIR, 'defi-chain-verified.json'), JSON.stringify(doc, null, 2));
  writeFileSync(join(process.cwd(), 'DEFI_CHAIN_VERIFIED_REPORT.md'), buildReport(doc));
  console.log(`Overall: ${overallClassification}`);
  console.log(`Bridge allowed: ${doc.bridgeImplementationAllowed}`);
  console.log(`Wallet: ${verifyWallet || '(none)'}`);
  console.log(`Proof steps: ${proofs.length}`);
  console.log('Wrote proof/defi-chain-verified.json');
  console.log('Wrote DEFI_CHAIN_VERIFIED_REPORT.md');
  process.exit(overallClassification === 'CHAIN_VERIFIED' ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
