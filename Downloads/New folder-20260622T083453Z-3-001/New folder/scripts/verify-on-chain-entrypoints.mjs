/**
 * Verify MandateOS SDK PTB targets exist as public functions on the published package.
 */
import { writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';

const PKG =
  process.env.MANDATEOS_PACKAGE_ID ??
  '0x96e72b6e6e5085d98e46b30c7da1c2b0300bcfda51719c6bedff4bff886c3713';

const SDK_TARGETS = [
  ['treasury_mandate', 'create'],
  ['treasury_mandate', 'share_all'],
  ['treasury_mandate', 'fund'],
  ['treasury_mandate', 'treasury_disbursement'],
  ['simulation', 'open_simulation'],
  ['simulation', 'run_projection'],
  ['simulation', 'approve_simulation'],
  ['simulation', 'transfer_approval'],
  ['guardian', 'evaluate'],
  ['guardian', 'share_action'],
  ['guardian', 'execute_action'],
  ['delegation', 'issue_executor_cap'],
  ['delegation', 'transfer_executor_cap'],
  ['workflow', 'open_session'],
  ['financial_mandate', 'settle'],
  ['payroll_mandate', 'create'],
  ['subscription_mandate', 'create'],
  ['revenue_allocation_mandate', 'create'],
  ['auto_investment_mandate', 'create'],
  ['dao_treasury_mandate', 'create'],
];

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const sourcesDir = join(root, 'mandateos', 'sources');
const localMods = readdirSync(sourcesDir)
  .filter((f) => f.endsWith('.move'))
  .map((f) => f.replace('.move', ''))
  .sort();

const client = new SuiClient({ url: getFullnodeUrl('testnet') });
const mods = await client.getNormalizedMoveModulesByPackage({ package: PKG });

const onChainModNames = Object.keys(mods)
  .map((k) => k.split('::').pop())
  .sort();

const results = [];
for (const [mod, fn] of SDK_TARGETS) {
  const key = Object.keys(mods).find((k) => k.split('::').pop() === mod);
  const ok = !!(key && mods[key]?.exposedFunctions?.[fn]);
  results.push({ module: mod, function: fn, status: ok ? 'present' : 'MISSING' });
}

const missingMods = localMods.filter((m) => !onChainModNames.includes(m));
const report = {
  packageId: PKG,
  localModuleCount: localMods.length,
  onChainModuleCount: onChainModNames.length,
  missingModulesOnChain: missingMods,
  sdkTargetVerification: results,
  allSdkTargetsPresent: results.every((r) => r.status === 'present'),
  note: 'MandateOS uses public fun (PTB-callable); no entry fun attributes in Move sources.',
};

mkdirSync(join(root, 'proof'), { recursive: true });
writeFileSync(join(root, 'proof', 'entrypoint-verification.json'), JSON.stringify(report, null, 2));

console.log(JSON.stringify(report, null, 2));
process.exit(report.allSdkTargetsPresent && missingMods.length === 0 ? 0 : 1);
