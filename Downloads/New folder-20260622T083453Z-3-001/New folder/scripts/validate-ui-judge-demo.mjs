/**
 * Validates proof/ui-judge-demo.json schema for browser judge acceptance.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const path = join(process.cwd(), 'proof', 'ui-judge-demo.json');

if (!existsSync(path)) {
  console.error('NOT VERIFIED: proof/ui-judge-demo.json missing');
  console.error('Complete browser judge flow at /demo and export proof from the UI.');
  process.exit(1);
}

const doc = JSON.parse(readFileSync(path, 'utf8'));
const required = ['wallet', 'generatedAt', 'steps'];
for (const k of required) {
  if (!doc[k]) {
    console.error(`NOT VERIFIED: ui-judge-demo.json missing field "${k}"`);
    process.exit(1);
  }
}

const steps = doc.steps as Array<{ action: string; digest: string; explorer?: string; timestampMs?: number }>;
if (!Array.isArray(steps) || steps.length < 5) {
  console.error('NOT VERIFIED: need ≥5 judge steps with digests');
  process.exit(1);
}

for (const s of steps) {
  if (!s.digest || s.digest.length < 20) {
    console.error(`NOT VERIFIED: step "${s.action}" missing digest`);
    process.exit(1);
  }
}

console.log('CHAIN_VERIFIED: ui-judge-demo.json schema OK');
console.log(`Wallet: ${doc.wallet}`);
console.log(`Steps: ${steps.length}`);
