/**
 * INTERNAL ONLY — Navi mainnet deposit/withdraw using MANDATEOS_MAINNET_KEY.
 * Not the production verification path. Judges use /app/navi-capital with Slush.
 *
 *   MANDATEOS_MAINNET_KEY=<suiprivkey> npm run internal:navi-verify
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import {
  NAVI_MAINNET_PACKAGE_ID,
  depositSuiToNavi,
  withdrawSuiFromNavi,
  fetchNaviPositions,
  readNaviSupplyBalanceMist,
  type NaviTxEvidence,
} from '../packages/mandateos-sdk/dist/defi/navi-integration.js';

const PROOF_DIR = join(process.cwd(), 'proof');
const DEPOSIT_MIST = 10_000_000; // 0.01 SUI
const dryRun = process.argv.includes('--dry-run');

function loadKeypair(): Ed25519Keypair {
  const raw = process.env.MANDATEOS_MAINNET_KEY ?? process.env.SUI_PRIVATE_KEY;
  if (!raw) {
    throw new Error(
      'Set MANDATEOS_MAINNET_KEY (suiprivkey…) for mainnet Navi verification.',
    );
  }
  if (raw.startsWith('suiprivkey')) return Ed25519Keypair.fromSecretKey(raw);
  const hex = raw.replace(/^0x/, '');
  return Ed25519Keypair.fromSecretKey(Buffer.from(hex, 'hex'));
}

function writeDepositProof(deposit: NaviTxEvidence, before: bigint, after: bigint) {
  const md = `# NAVI DEPOSIT PROOF

**Status:** CHAIN_VERIFIED

**Generated:** ${new Date().toISOString()}

## Transaction

| Field | Value |
|-------|-------|
| Digest | \`${deposit.digest}\` |
| Explorer | ${deposit.explorer} |
| Network | mainnet |
| Protocol | Navi |
| Package | \`${NAVI_MAINNET_PACKAGE_ID}\` |
| Signer / Owner | \`${deposit.wallet}\` |
| Asset | ${deposit.asset} |
| Amount | ${deposit.amountMist} MIST (${deposit.amountMist / 1e9} SUI) |
| Status | ${deposit.status} |
| Timestamp | ${new Date(deposit.timestampMs).toISOString()} |

## Position state

| Field | Value |
|-------|-------|
| Supply before | ${before.toString()} MIST |
| Supply after deposit | ${after.toString()} MIST |
| Position object | ${deposit.positionObjectId ?? 'Unavailable (account-indexed lending state)'} |

## Object changes

\`\`\`json
${JSON.stringify(deposit.objectIds, null, 2)}
\`\`\`
`;
  writeFileSync(join(process.cwd(), 'NAVI_DEPOSIT_PROOF.md'), md);
}

function writeWithdrawProof(withdraw: NaviTxEvidence, afterWithdraw: bigint) {
  const md = `# NAVI WITHDRAW PROOF

**Status:** CHAIN_VERIFIED

**Generated:** ${new Date().toISOString()}

## Transaction

| Field | Value |
|-------|-------|
| Digest | \`${withdraw.digest}\` |
| Explorer | ${withdraw.explorer} |
| Network | mainnet |
| Protocol | Navi |
| Signer / Owner | \`${withdraw.wallet}\` |
| Asset | ${withdraw.asset} |
| Amount withdrawn | ${withdraw.amountMist} MIST (${withdraw.amountMist / 1e9} SUI) |
| Status | ${withdraw.status} |
| Supply after withdraw | ${afterWithdraw.toString()} MIST |

## Object changes

\`\`\`json
${JSON.stringify(withdraw.objectIds, null, 2)}
\`\`\`
`;
  writeFileSync(join(process.cwd(), 'NAVI_WITHDRAW_PROOF.md'), md);
}

function writeVerificationReport(params: {
  deposit: NaviTxEvidence;
  withdraw: NaviTxEvidence;
  positions: Awaited<ReturnType<typeof fetchNaviPositions>>;
  wallet: string;
}) {
  const md = `# NAVI VERIFICATION REPORT

**Generated:** ${new Date().toISOString()}

## Summary

| Phase | Requirement | Status |
|-------|-------------|--------|
| 1 | Real mainnet deposit | CHAIN_VERIFIED |
| 2 | Position discovery from Navi state | CHAIN_VERIFIED |
| 3 | Real mainnet withdrawal | CHAIN_VERIFIED |
| 4 | TITAN treasury workflow UI (Investment → Navi Deposit) | NOT VERIFIED — requires Slush mainnet signing in production UI |
| 5 | Proof Center records Navi actions | NOT VERIFIED — until UI deposit produces proof export |
| 6 | Portfolio Navi section | NOT VERIFIED — until live position after UI deposit |
| 7 | Automated allocation (Investment → Navi) | NOT VERIFIED — cross-network: testnet treasury, mainnet Navi |
| 8 | End-to-end CLI verification | CHAIN_VERIFIED |

## Deposit evidence

- Digest: [\`${params.deposit.digest}\`](${params.deposit.explorer})
- Owner: \`${params.deposit.wallet}\`
- Amount: ${params.deposit.amountMist} MIST

## Withdraw evidence

- Digest: [\`${params.withdraw.digest}\`](${params.withdraw.explorer})
- Amount: ${params.withdraw.amountMist} MIST

## Positions (${params.wallet})

\`\`\`json
${JSON.stringify(params.positions, (_, v) => (typeof v === 'bigint' ? v.toString() : v), 2)}
\`\`\`

## Blockers for full CHAIN_VERIFIED

1. MandateOS mandates are on **testnet**; Navi is **mainnet-only** — single-PTB treasury→Navi requires mainnet MandateOS publish or bridge.
2. Complete TITAN UI flow: Investment Execute → Navi Deposit via Slush (\`sui:mainnet\`) → Proof Center export.
`;
  writeFileSync(join(process.cwd(), 'NAVI_VERIFICATION_REPORT.md'), md);
}

function writeNotVerified(error: string) {
  const status = 'NOT VERIFIED';
  const depositMd = `# NAVI DEPOSIT PROOF

**Status:** ${status}

**Error:** ${error}

No on-chain deposit transaction was executed. Set \`MANDATEOS_MAINNET_KEY\` and run \`npm run mainnet:navi-verify\`.
`;
  const withdrawMd = `# NAVI WITHDRAW PROOF

**Status:** ${status}

Withdrawal not executed — deposit prerequisite missing.
`;
  const reportMd = `# NAVI VERIFICATION REPORT

**Status:** ${status}

**Generated:** ${new Date().toISOString()}

| Phase | Status |
|-------|--------|
| 1 Real mainnet deposit | NOT VERIFIED |
| 2 Position discovery | NOT VERIFIED |
| 3 Real mainnet withdrawal | NOT VERIFIED |
| 4 TITAN treasury integration | NOT VERIFIED |
| 5 Proof Center | NOT VERIFIED |
| 6 Portfolio | NOT VERIFIED |
| 7 Automated allocation | NOT VERIFIED |
| 8 Final verification | NOT VERIFIED |

**Blocker:** ${error}

**Action:** \`MANDATEOS_MAINNET_KEY=<suiprivkey> npm run mainnet:navi-verify\`
`;
  writeFileSync(join(process.cwd(), 'NAVI_DEPOSIT_PROOF.md'), depositMd);
  writeFileSync(join(process.cwd(), 'NAVI_WITHDRAW_PROOF.md'), withdrawMd);
  writeFileSync(join(process.cwd(), 'NAVI_VERIFICATION_REPORT.md'), reportMd);
}

async function main() {
  mkdirSync(PROOF_DIR, { recursive: true });
  const client = new SuiClient({ url: getFullnodeUrl('mainnet') });
  const kp = loadKeypair();
  const address = kp.toSuiAddress();

  const bal = await client.getBalance({ owner: address });
  console.log(`Mainnet wallet ${address}: ${Number(bal.totalBalance) / 1e9} SUI`);
  console.log(`Navi package: ${NAVI_MAINNET_PACKAGE_ID}`);

  if (dryRun) {
    const positions = await fetchNaviPositions(address);
    console.log('Current Navi positions:', positions);
    return;
  }

  if (BigInt(bal.totalBalance) < BigInt(DEPOSIT_MIST + 5_000_000)) {
    throw new Error(`Need ≥${(DEPOSIT_MIST + 5_000_000) / 1e9} SUI on mainnet for deposit + gas`);
  }

  const beforeSupply = await readNaviSupplyBalanceMist(address);
  console.log(`Navi SUI supply before: ${beforeSupply} MIST`);

  const deposit = await depositSuiToNavi(kp, DEPOSIT_MIST);
  console.log(`✓ Navi deposit: ${deposit.explorer}`);

  const afterDeposit = await readNaviSupplyBalanceMist(address);
  if (afterDeposit <= beforeSupply) {
    throw new Error(`Position did not increase after deposit (before=${beforeSupply}, after=${afterDeposit})`);
  }

  const positionsAfterDeposit = await fetchNaviPositions(address);
  writeDepositProof(deposit, beforeSupply, afterDeposit);

  const withdraw = await withdrawSuiFromNavi(kp, DEPOSIT_MIST);
  console.log(`✓ Navi withdraw: ${withdraw.explorer}`);

  const afterWithdraw = await readNaviSupplyBalanceMist(address);
  const positions = await fetchNaviPositions(address);
  writeWithdrawProof(withdraw, afterWithdraw);
  writeVerificationReport({ deposit, withdraw, positions, wallet: address });

  const artifact = {
    generatedAt: new Date().toISOString(),
    network: 'mainnet',
    protocol: 'navi',
    packageId: NAVI_MAINNET_PACKAGE_ID,
    wallet: address,
    depositMist: DEPOSIT_MIST,
    supplyBeforeMist: beforeSupply.toString(),
    supplyAfterDepositMist: afterDeposit.toString(),
    supplyAfterWithdrawMist: afterWithdraw.toString(),
    digests: { deposit: deposit.digest, withdraw: withdraw.digest },
    explorers: { deposit: deposit.explorer, withdraw: withdraw.explorer },
    depositEvidence: deposit,
    withdrawEvidence: withdraw,
    positionsAfterDeposit,
    positions,
    classification: 'CHAIN_VERIFIED',
    proofs: ['NAVI_DEPOSIT_PROOF.md', 'NAVI_WITHDRAW_PROOF.md', 'NAVI_VERIFICATION_REPORT.md'],
  };

  writeFileSync(join(PROOF_DIR, 'external-defi-verification.json'), JSON.stringify(artifact, null, 2));
  console.log('✓ proof/external-defi-verification.json');
  console.log('✓ NAVI_DEPOSIT_PROOF.md');
  console.log('✓ NAVI_WITHDRAW_PROOF.md');
  console.log('✓ NAVI_VERIFICATION_REPORT.md');
}

main().catch((e) => {
  console.error(e);
  const msg = e instanceof Error ? e.message : String(e);
  writeNotVerified(msg);
  const artifact = {
    generatedAt: new Date().toISOString(),
    classification: 'NOT VERIFIED',
    error: msg,
    blocker: 'Set MANDATEOS_MAINNET_KEY and run: npm run mainnet:navi-verify',
  };
  mkdirSync(PROOF_DIR, { recursive: true });
  writeFileSync(join(PROOF_DIR, 'external-defi-verification.json'), JSON.stringify(artifact, null, 2));
  process.exit(1);
});
