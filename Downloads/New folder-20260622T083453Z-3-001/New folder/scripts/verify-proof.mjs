/**
 * Validates proof.json from Proof Center export against Sui RPC.
 *
 * Usage:
 *   npm run verify-proof
 *   npm run verify-proof -- path/to/proof.json
 */
import { readFileSync, existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { verifyProofDocument } from '@mandateos/sdk';

const proofPath = process.argv[2] ?? join(process.cwd(), 'proof', 'proof.json');

function fail(msg) {
  console.error(`INVALID: ${msg}`);
  process.exit(1);
}

if (!existsSync(proofPath)) {
  fail(`Missing ${proofPath}. Export proof.json from Proof Center after wallet-signed activity.`);
}

const doc = JSON.parse(readFileSync(proofPath, 'utf8'));

if (!doc.wallet || !Array.isArray(doc.proofs)) {
  fail('proof.json must include wallet and proofs[]');
}

const report = await verifyProofDocument(doc);

for (const step of report.results) {
  const prefix = step.status === 'CHAIN_VERIFIED' ? 'PASS' : 'FAIL';
  console.log(`${prefix}: ${step.label} · ${step.network} · ${step.digest.slice(0, 16)}…`);
  for (const err of step.errors) console.error(`  ✗ ${err}`);
  for (const warn of step.warnings) console.warn(`  ⚠ ${warn}`);
}

mkdirSync(join(process.cwd(), 'proof'), { recursive: true });
writeFileSync(
  join(process.cwd(), 'proof', 'proof-verification.json'),
  JSON.stringify({ ...report, proofFile: proofPath }, null, 2),
);

if (report.classification === 'INVALID') {
  console.error(`\nINVALID: ${report.invalidCount} of ${report.proofCount} proof(s) failed RPC validation`);
  process.exit(1);
}

console.log(`\nCHAIN_VERIFIED: ${report.verifiedCount} proof(s) validated against RPC`);
console.log('Artifact: proof/proof-verification.json');
