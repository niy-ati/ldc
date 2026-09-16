#!/usr/bin/env node
/**
 * demo-judge.mjs — MandateOS Command Center Demo Validator
 *
 * Validates that the Command Center correctly implements all required panels,
 * demo scenario flow, and constitutional reasoning features.
 *
 * Usage:
 *   node scripts/demo-judge.mjs [--dev-url http://localhost:5173]
 */

import { existsSync, readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const DEV_URL = process.argv.includes('--dev-url')
  ? process.argv[process.argv.indexOf('--dev-url') + 1]
  : 'http://localhost:5173';

const DEMO_STEPS = [
  { id: 'revenue', title: 'Revenue Received' },
  { id: 'payroll', title: 'Payroll Obligations Registered' },
  { id: 'runway', title: 'Runway Objective Validated' },
  { id: 'stress', title: 'Market Stress Detected' },
  { id: 'reallocate', title: 'Capital Reallocated' },
  { id: 'preserve', title: 'Obligations Preserved' },
  { id: 'audit', title: 'Audit Trail Produced' },
];

const SDK_EXPORTS = [
  'buildDeepBookIntelligence',
  'computeHedgeRecommendations',
  'assessTreasuryExposure',
  'buildCapitalAllocationView',
  'guardianReallocationPreview',
  'buildRebalanceRecommendations',
];

function readFile(relPath) {
  return readFileSync(resolve(ROOT, relPath), 'utf-8');
}

function fileExists(relPath) {
  return existsSync(resolve(ROOT, relPath));
}

async function checkServerReachable(url) {
  try {
    const resp = await fetch(url, { signal: AbortSignal.timeout(5000) });
    return resp.ok;
  } catch {
    return false;
  }
}

// ── Main ────────────────────────────────────────────────────────────────────────

async function main() {
  console.log('╔══════════════════════════════════════════════════════════╗');
  console.log('║     MandateOS Command Center — Demo Judge Report        ║');
  console.log('╚══════════════════════════════════════════════════════════╝');
  console.log();

  let totalChecks = 0;
  let passed = 0;

  function check(label, ok) {
    totalChecks++;
    if (ok) passed++;
    console.log(`  ${ok ? '✓' : '✗'} ${label}`);
  }

  // 1. File existence validation
  console.log('━━━ 1. Component & Module Files ━━━');
  const requiredFiles = [
    'packages/command-center/src/components/RiskRadar.tsx',
    'packages/command-center/src/components/ObligationShield.tsx',
    'packages/command-center/src/components/ConstitutionalReasoningPanel.tsx',
    'packages/command-center/src/components/AdaptiveLiquidityPanel.tsx',
    'packages/command-center/src/pages/OverviewPage.tsx',
    'packages/command-center/src/pages/DeepBookPage.tsx',
    'packages/command-center/src/demo/demoScenario.ts',
    'packages/command-center/src/demo/demoState.ts',
    'packages/command-center/src/store/mandateStore.ts',
    'packages/mandateos-sdk/src/product/deepbook-intelligence.ts',
    'packages/mandateos-sdk/src/product/capital-engine.ts',
    'packages/mandateos-sdk/src/views/types.ts',
  ];
  for (const f of requiredFiles) {
    check(f.split('/').slice(1).join('/'), fileExists(f));
  }
  console.log();

  // 2. SDK export validation
  console.log('━━━ 2. SDK Exports ━━━');
  const sdkIndex = readFile('packages/mandateos-sdk/src/index.ts');
  for (const exp of SDK_EXPORTS) {
    check(exp, sdkIndex.includes(exp));
  }
  console.log();

  // 3. View types — check key interfaces
  console.log('━━━ 3. View Types ━━━');
  const viewTypes = readFile('packages/mandateos-sdk/src/views/types.ts');
  const requiredTypes = [
    'DeepBookIntelligence',
    'HedgeRecommendation',
    'ExposureAssessment',
    'RebalanceRecommendation',
    'DemoScenarioStep',
    'CapitalBucketId',
    'VolatilityTrend',
    'LiquidityDepthRating',
  ];
  for (const t of requiredTypes) {
    check(`interface/type ${t}`, viewTypes.includes(t));
  }
  console.log();

  // 4. DeepBook Intelligence Engine
  console.log('━━━ 4. DeepBook Intelligence Engine ━━━');
  const dbIntel = readFile('packages/mandateos-sdk/src/product/deepbook-intelligence.ts');
  check('buildDeepBookIntelligence function', dbIntel.includes('export function buildDeepBookIntelligence'));
  check('computeHedgeRecommendations function', dbIntel.includes('export function computeHedgeRecommendations'));
  check('assessTreasuryExposure function', dbIntel.includes('export function assessTreasuryExposure'));
  check('Volatility rule (>60)', dbIntel.includes('volatilityIndex > 60'));
  check('Liquidity rule (<40)', dbIntel.includes('liquidityDepthScore < 40'));
  check('Slippage rule (>300)', dbIntel.includes('slippageRiskBps > 300'));
  check('Market condition derivation', dbIntel.includes('assessMarketCondition'));
  check('Constitutional impact derivation', dbIntel.includes('deriveConstitutionalImpact'));
  console.log();

  // 5. Capital Engine — 5-pool model
  console.log('━━━ 5. Capital Engine (5-Pool Model) ━━━');
  const capEngine = readFile('packages/mandateos-sdk/src/product/capital-engine.ts');
  check('Treasury Reserve bucket', capEngine.includes("'Treasury Reserve'"));
  check('Payroll Reserve bucket', capEngine.includes("'Payroll Reserve'"));
  check('Operational Reserve bucket', capEngine.includes("'Operational Reserve'"));
  check('Yield Capital bucket', capEngine.includes("'Yield Capital'"));
  check('Hedging Capital bucket', capEngine.includes("'Hedging Capital'"));
  check('buildRebalanceRecommendations function', capEngine.includes('export function buildRebalanceRecommendations'));
  check('guardianReallocationPreview function', capEngine.includes('export function guardianReallocationPreview'));
  console.log();

  // 6. Demo scenario structure
  console.log('━━━ 6. Demo Scenario Steps ━━━');
  const demoScenario = readFile('packages/command-center/src/demo/demoScenario.ts');
  for (const step of DEMO_STEPS) {
    check(`Step: ${step.title} (id: '${step.id}')`, demoScenario.includes(`'${step.id}'`));
  }
  check('getMandateViewForStep function', demoScenario.includes('getMandateViewForStep'));
  console.log();

  // 7. Demo state (institutional scenario)
  console.log('━━━ 7. Demo State (Institutional Scenario) ━━━');
  const demoState = readFile('packages/command-center/src/demo/demoState.ts');
  check('createDemoMandateView function', demoState.includes('createDemoMandateView'));
  check('createStressedMandateView function', demoState.includes('createStressedMandateView'));
  check('createRemediatedMandateView function', demoState.includes('createRemediatedMandateView'));
  check('Payroll obligations (Alice)', demoState.includes('ENG_LEAD_ALICE'));
  check('Payroll obligations (Bob)', demoState.includes('DEV_BOB'));
  check('Payroll obligations (Carol)', demoState.includes('DESIGN_CAROL'));
  check('Stress mode activation', demoState.includes('stressMode: true'));
  check('Guardian pending actions', demoState.includes('GA_STRESS_001'));
  console.log();

  // 8. Store scenario engine
  console.log('━━━ 8. Store Scenario Engine ━━━');
  const store = readFile('packages/command-center/src/store/mandateStore.ts');
  const storeActions = ['startDemoScenario', 'advanceDemoScenario', 'goToDemoStep', 'resetDemoScenario'];
  for (const action of storeActions) {
    check(action, store.includes(action));
  }
  check('demoScenarioStep state', store.includes('demoScenarioStep'));
  check('demoScenarioActive state', store.includes('demoScenarioActive'));
  console.log();

  // 9. OverviewPage — Capital Operations Center
  console.log('━━━ 9. OverviewPage (Capital Operations Center) ━━━');
  const overview = readFile('packages/command-center/src/pages/OverviewPage.tsx');
  check('Hero status bar', overview.includes('cc-hero'));
  check('Capital Operations Center title', overview.includes('Capital Operations Center'));
  check('RiskRadar component', overview.includes('<RiskRadar'));
  check('ObligationShield component', overview.includes('<ObligationShield'));
  check('ConstitutionalReasoningPanel', overview.includes('<ConstitutionalReasoningPanel'));
  check('AdaptiveLiquidityPanel', overview.includes('<AdaptiveLiquidityPanel'));
  check('Demo scenario integration', overview.includes('btn-start-demo'));
  check('Vault balance display', overview.includes('vault.balanceMist'));
  check('Compliance score', overview.includes('complianceScore'));
  check('Runway display', overview.includes('runwayDays'));
  console.log();

  // 10. DeepBookPage
  console.log('━━━ 10. DeepBookPage ━━━');
  const dbPage = readFile('packages/command-center/src/pages/DeepBookPage.tsx');
  check('RiskRadar integration', dbPage.includes('<RiskRadar'));
  check('Exposure assessment', dbPage.includes('assessTreasuryExposure'));
  check('Hook configuration table', dbPage.includes('panel-hook-config'));
  check('Hedge execution path', dbPage.includes('panel-hedge-execution'));
  check('5-step execution flow', dbPage.includes('Settlement Executes'));
  console.log();

  // 11. Layout — sectioned sidebar
  console.log('━━━ 11. Layout (Sectioned Sidebar) ━━━');
  const layout = readFile('packages/command-center/src/components/Layout.tsx');
  check("'Command' section", layout.includes("'Command'"));
  check("'Intelligence' section", layout.includes("'Intelligence'"));
  check("'Operations' section", layout.includes("'Operations'"));
  check("'Audit' section", layout.includes("'Audit'"));
  check('DeepBook Intelligence nav item', layout.includes('DeepBook Intelligence'));
  check('/deepbook route', layout.includes('/deepbook'));
  console.log();

  // 12. App — routing
  console.log('━━━ 12. App Routing ━━━');
  const app = readFile('packages/command-center/src/App.tsx');
  check('/deepbook route', app.includes('/deepbook'));
  check('DeepBookPage import', app.includes('DeepBookPage'));
  console.log();

  // 13. CSS — key styles
  console.log('━━━ 13. CSS Styling ━━━');
  const css = readFile('packages/command-center/src/styles/global.css');
  check('Command Center hero styles', css.includes('.cc-hero'));
  check('Risk radar styles', css.includes('.risk-radar-panel'));
  check('Obligation shield styles', css.includes('.obligation-shield-panel'));
  check('Constitutional reasoning styles', css.includes('.constitutional-panel'));
  check('Adaptive liquidity styles', css.includes('.adaptive-liquidity-panel'));
  check('DeepBook page styles', css.includes('.deepbook-page'));
  check('Pulse animations', css.includes('@keyframes pulse-danger'));
  check('Gauge card styles', css.includes('.gauge-card'));
  check('Hedge recommendation styles', css.includes('.hedge-card'));
  check('Demo scenario styles', css.includes('.cc-scenario-panel'));
  check('Glassmorphism/premium gradient', css.includes('linear-gradient'));
  check('Google Fonts (DM Sans)', css.includes('DM+Sans'));
  console.log();

  // 14. Dev server check (optional)
  console.log('━━━ 14. Dev Server ━━━');
  const reachable = await checkServerReachable(DEV_URL);
  check(`Server reachable at ${DEV_URL}`, reachable);
  if (!reachable) {
    console.log('    (Start with: npm run dev:cc)');
  }
  console.log();

  // Summary
  console.log('═══════════════════════════════════════════════════════════');
  const pct = ((passed / totalChecks) * 100).toFixed(0);
  console.log(`  Result: ${passed}/${totalChecks} checks passed`);
  console.log(`  Score:  ${pct}%`);
  if (passed === totalChecks) {
    console.log('  Status: ✓ ALL CHECKS PASSED');
  } else {
    console.log(`  Status: ⚠ ${totalChecks - passed} checks failed`);
  }
  console.log('═══════════════════════════════════════════════════════════');

  process.exit(passed === totalChecks ? 0 : 1);
}

main().catch((e) => {
  console.error('Judge script error:', e);
  process.exit(2);
});
