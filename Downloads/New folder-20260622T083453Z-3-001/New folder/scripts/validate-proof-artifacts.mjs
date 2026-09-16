/**
 * Validate proof/deployment.json and proof/testnet-results.json against schemas.
 * Also validates explorer URL format and Command Center env var coverage.
 *
 * Usage:
 *   node scripts/validate-proof-artifacts.mjs
 *   node scripts/validate-proof-artifacts.mjs --fixture
 */
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const useFixture = process.argv.includes('--fixture');

const REQUIRED_CC_ENV = [
  'VITE_DEMO_MODE',
  'VITE_SUI_NETWORK',
  'VITE_MANDATEOS_PACKAGE_ID',
  'VITE_MANDATEOS_MANDATE_ID',
  'VITE_MANDATEOS_VAULT_ID',
  'VITE_MANDATEOS_CONSTITUTION_ID',
  'VITE_MANDATEOS_OBLIGATIONS_ID',
  'VITE_MANDATEOS_RISK_PROFILE_ID',
  'VITE_MANDATEOS_LIQUIDITY_ENGINE_ID',
  'VITE_MANDATEOS_FORECAST_ID',
  'VITE_MANDATEOS_HOOK_ID',
  'VITE_MANDATEOS_GUARDIAN_POLICY_ID',
  'VITE_MANDATEOS_EXECUTION_TRACKER_ID',
  'VITE_MANDATEOS_TREASURY_CONFIG_ID',
  'VITE_MANDATEOS_TRACE_TX',
];

const ADDR = /^0x[a-fA-F0-9]{64}$/;
const EXPLORER_TX = /^https:\/\/suiscan\.xyz\/testnet\/tx\//;
const EXPLORER_OBJ = /^https:\/\/suiscan\.xyz\/testnet\/object\//;

function fail(msg) {
  console.error(`FAIL: ${msg}`);
  process.exitCode = 1;
}

function pass(msg) {
  console.log(`PASS: ${msg}`);
}

function validateDeployment(d) {
  const required = ['packageId', 'digest', 'governor', 'network'];
  for (const k of required) {
    if (!(k in d)) return fail(`deployment.json missing field: ${k}`);
  }
  if (!ADDR.test(d.packageId)) fail(`deployment.packageId invalid: ${d.packageId}`);
  if (!ADDR.test(d.governor)) fail(`deployment.governor invalid: ${d.governor}`);
  if (d.network !== 'testnet') fail(`deployment.network must be testnet`);
  if (!d.digest || d.digest.length < 20) fail(`deployment.digest too short`);
  pass('deployment.json schema');
  pass(`deployment explorer tx: https://suiscan.xyz/testnet/tx/${d.digest}`);
  pass(`deployment explorer pkg: https://suiscan.xyz/testnet/object/${d.packageId}`);
}

function validateResults(r) {
  const required = ['network', 'packageId', 'governor', 'steps', 'objects'];
  for (const k of required) {
    if (!(k in r)) return fail(`testnet-results.json missing field: ${k}`);
  }
  if (r.network !== 'testnet') fail('results.network must be testnet');
  if (!ADDR.test(r.packageId)) fail('results.packageId invalid');
  if (!ADDR.test(r.governor)) fail('results.governor invalid');

  const coreObjects = [
    'FinancialMandate',
    'FinancialConstitution',
    'MandateVault',
    'ObligationRegistry',
    'GuardianPolicy',
    'LiquidityEngine',
  ];
  for (const obj of coreObjects) {
    if (!r.objects[obj] || !ADDR.test(r.objects[obj])) {
      fail(`results.objects.${obj} missing or invalid`);
    }
  }

  for (const step of r.steps) {
    if (!step.name || !step.digest || !step.explorer) {
      fail(`step missing name/digest/explorer: ${JSON.stringify(step)}`);
    }
    if (step.explorer.startsWith('https://') && !EXPLORER_TX.test(step.explorer)) {
      fail(`step explorer URL invalid: ${step.explorer}`);
    }
  }

  const treasurySteps = r.steps.filter(
    (s) =>
      s.name.includes('Treasury') ||
      s.name.includes('Fund') ||
      s.name.includes('Simulate') ||
      s.name.includes('Execute Treasury'),
  );
  if (treasurySteps.length < 3) fail('expected >= 3 treasury-related steps');

  const agentSteps = r.steps.filter((s) => s.name.includes('Delegated') || s.name.includes('ExecutorCap'));
  if (r.proofStatus !== 'partial' && agentSteps.length < 2) fail('expected >= 2 agent-related steps');

  const guardianSteps = r.steps.filter((s) => s.name.includes('Guardian'));
  if (r.proofStatus !== 'partial' && guardianSteps.length < 1) fail('expected >= 1 guardian step');

  pass('testnet-results.json schema');
  pass(`results: ${r.steps.length} steps, ${Object.keys(r.objects).length} objects`);
}

function validateCcEnvFromResults(r) {
  const env = {
    VITE_DEMO_MODE: 'false',
    VITE_SUI_NETWORK: r.network,
    VITE_MANDATEOS_PACKAGE_ID: r.packageId,
    VITE_MANDATEOS_MANDATE_ID: r.objects.FinancialMandate,
    VITE_MANDATEOS_VAULT_ID: r.objects.MandateVault,
    VITE_MANDATEOS_CONSTITUTION_ID: r.objects.FinancialConstitution,
    VITE_MANDATEOS_OBLIGATIONS_ID: r.objects.ObligationRegistry,
    VITE_MANDATEOS_RISK_PROFILE_ID: r.objects.OperationalRiskProfile ?? '',
    VITE_MANDATEOS_LIQUIDITY_ENGINE_ID: r.objects.LiquidityEngine,
    VITE_MANDATEOS_FORECAST_ID: r.objects.MarketForecast ?? '',
    VITE_MANDATEOS_HOOK_ID: r.objects.DeepBookHook ?? '',
    VITE_MANDATEOS_GUARDIAN_POLICY_ID: r.objects.GuardianPolicy,
    VITE_MANDATEOS_EXECUTION_TRACKER_ID: r.objects.DailyExecutionTracker ?? '',
    VITE_MANDATEOS_TREASURY_CONFIG_ID: r.objects.TreasuryConfig ?? '',
    VITE_MANDATEOS_TRACE_TX:
      r.steps.find((s) => s.name.includes('Execute Treasury'))?.digest ??
      r.steps.find((s) => s.name.includes('Simulate'))?.digest ??
      '',
  };

  const viteEnv = readFileSync(
    join(root, 'packages/command-center/src/vite-env.d.ts'),
    'utf8',
  );
  for (const key of REQUIRED_CC_ENV) {
    if (!viteEnv.includes(key)) fail(`vite-env.d.ts missing ${key}`);
    if (key === 'VITE_DEMO_MODE') continue;
    if (key === 'VITE_SUI_NETWORK') continue;
    if (!env[key] && !['VITE_MANDATEOS_RISK_PROFILE_ID', 'VITE_MANDATEOS_FORECAST_ID', 'VITE_MANDATEOS_HOOK_ID', 'VITE_MANDATEOS_EXECUTION_TRACKER_ID'].includes(key)) {
      fail(`cannot derive ${key} from results.objects`);
    }
  }
  pass('Command Center env vars covered in vite-env.d.ts');
}

function explorerHelpers() {
  const tx = (net, d) => `https://suiscan.xyz/${net}/tx/${d}`;
  const obj = (net, id) => `https://suiscan.xyz/${net}/object/${id}`;
  const sampleTx = tx('testnet', 'ABC123');
  const sampleObj = obj('testnet', '0x' + 'a'.repeat(64));
  if (!EXPLORER_TX.test(sampleTx)) fail('explorer tx helper format');
  if (!EXPLORER_OBJ.test(sampleObj)) fail('explorer object helper format');
  pass('explorer URL generation format');
}

const deploymentPath = useFixture
  ? join(root, 'proof/fixtures/deployment.sample.json')
  : join(root, 'proof/deployment.json');
const resultsPath = useFixture
  ? join(root, 'proof/fixtures/testnet-results.sample.json')
  : join(root, 'proof/testnet-results.json');

explorerHelpers();

if (existsSync(deploymentPath)) {
  validateDeployment(JSON.parse(readFileSync(deploymentPath, 'utf8')));
} else {
  fail(`missing ${deploymentPath} (use --fixture for dry-run)`);
}

if (existsSync(resultsPath)) {
  const results = JSON.parse(readFileSync(resultsPath, 'utf8'));
  validateResults(results);
  validateCcEnvFromResults(results);
} else {
  fail(`missing ${resultsPath} (use --fixture for dry-run)`);
}

if (process.exitCode) {
  console.error('\nValidation failed.');
  process.exit(1);
}
console.log('\nAll validations passed.');
