/**
 * Dry-run gas estimates for evidence sprint PTBs (v5 package).
 * Usage: node scripts/estimate-sprint-gas.mjs
 */
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { MandateOSClient } from '../packages/mandateos-sdk/dist/index.js';

const NETWORK = 'testnet';
const GOVERNOR = '0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b';
const PTB_SHIM = '0x70cba71ba84b852a83c66f3cddad429c98d082cffdc7638fa21e98faecf26af9';
const PACKAGE = '0xab08c97952d7ca39b1cf1f3d773d940f5d56ed8235da65b1c313ddcdec555e13';

const FUND_WALLET_A_MIST = 80_000_000n;
const FUND_WALLET_B_MIST = 220_000_000n;
const FUND_VAULT_MIST = 15_000_000n;
const EXECUTE_MIST = 2_000_000n;
const PAYROLL_FUND = 8_000_000n;
const PAYROLL_PAY = 2_000_000n;
const REVENUE_FUND = 10_000_000n;
const INVEST_FUND = 8_000_000n;

const client = new SuiClient({ url: getFullnodeUrl(NETWORK) });
const sdk = new MandateOSClient({ packageId: PACKAGE, ptbShimPackageId: PTB_SHIM });

function netGas(gasUsed) {
  if (!gasUsed) return 0n;
  return BigInt(gasUsed.computationCost) + BigInt(gasUsed.storageCost) - BigInt(gasUsed.storageRebate);
}

async function dryRun(label, tx, sender) {
  const result = await client.devInspectTransactionBlock({
    transactionBlock: tx,
    sender,
  });
  const status = result.effects?.status?.status ?? 'unknown';
  const gas = netGas(result.effects?.gasUsed);
  const err = result.error ?? result.effects?.status?.error;
  return { label, status, gas, err };
}

async function dryRunFundVault(sender, vaultId, amount, module) {
  const { Transaction } = await import('@mysten/sui/transactions');
  const tx = new Transaction();
  const [coin] = tx.splitCoins(tx.gas, [amount]);
  tx.moveCall({
    target: `${PACKAGE}::${module}::fund`,
    typeArguments: [sdk.coinType],
    arguments: [tx.object(vaultId), coin],
  });
  return dryRun(`fund ${module}`, tx, sender);
}

async function main() {
  const walletA = Ed25519Keypair.generate();
  const walletB = Ed25519Keypair.generate();
  const addrA = walletA.toSuiAddress();
  const addrB = walletB.toSuiAddress();
  const recipient = Ed25519Keypair.generate().toSuiAddress();
  const employee = Ed25519Keypair.generate().toSuiAddress();
  const revenueRecipient = Ed25519Keypair.generate().toSuiAddress();
  const investRecipient = Ed25519Keypair.generate().toSuiAddress();

  const rows = [];

  // Governor transfers (simple split+transfer)
  const { Transaction } = await import('@mysten/sui/transactions');
  for (const [label, addr, amt] of [
    ['Governor fund Wallet A', addrA, FUND_WALLET_A_MIST],
    ['Governor fund Wallet B', addrB, FUND_WALLET_B_MIST],
  ]) {
    const tx = new Transaction();
    const [coin] = tx.splitCoins(tx.gas, [amt]);
    tx.transferObjects([coin], addr);
    rows.push(await dryRun(label, tx, GOVERNOR));
  }

  // Wallet A — P1 create + P2/P3/P4 Guardian path
  rows.push(await dryRun('P1 Create Treasury Wallet A', sdk.buildCreateTreasuryTx({
    owner: addrA, executor: addrA, targetBalance: 10_000_000_000n, maxPerTransaction: 500_000_000n,
    maxDaily: 2_000_000_000n, minReserveBps: 1000, contributionBps: 0, contributionRecipient: addrA, multisigThreshold: 1n,
  }), addrA));

  // Placeholder graph IDs for post-create ops — use dummy shared refs; devInspect validates Move not object existence for some
  // Instead chain real IDs from a prior create via devInspect sequential simulation is hard.
  // Use historical average gas from successful txs for post-create steps.
  const historical = {
    'P1 Create Treasury Wallet B': 30_157_080n,
    'P3 Fund Treasury': 1_311_160n,
    'P4 Guardian Evaluate': 3_701_080n,
    'P2 Create Obligation': 1_898_272n,
    'P3 Simulate Treasury': 8_595_524n,
    'P3 Execute Treasury': 11_683_688n,
    'P4 Create Payroll': 31_046_280n,
    'P4 Fund Payroll Vault': 1_311_160n,
    'P4 Simulate Payroll': 8_595_524n,
  };

  rows.push({ label: 'P1 Create Treasury Wallet B', status: 'historical', gas: historical['P1 Create Treasury Wallet B'], err: null });
  rows.push({ label: 'P3 Fund Treasury', status: 'historical', gas: historical['P3 Fund Treasury'], err: null });
  rows.push({ label: 'P4 Guardian Evaluate', status: 'historical', gas: historical['P4 Guardian Evaluate'], err: null });
  rows.push({ label: 'P2 Create Obligation', status: 'historical', gas: historical['P2 Create Obligation'], err: null });
  rows.push({ label: 'P3 Simulate Treasury', status: 'historical', gas: historical['P3 Simulate Treasury'], err: null });
  rows.push({ label: 'P3 Execute Treasury', status: 'historical', gas: historical['P3 Execute Treasury'], err: null });
  rows.push({ label: 'P4 Create Payroll', status: 'historical', gas: historical['P4 Create Payroll'], err: null });
  rows.push({ label: 'P4 Fund Payroll Vault', status: 'historical', gas: historical['P4 Fund Payroll Vault'], err: null });
  rows.push({ label: 'P4 Simulate Payroll', status: 'historical', gas: historical['P4 Simulate Payroll'], err: null });

  // Dry-run execute builders with synthetic graph — will fail object lookup; estimate from execute treasury ratio
  const executeEstimate = 12_000_000n; // ~execute treasury measured
  const simulateEstimate = 8_600_000n;
  const createMandateEstimate = 31_000_000n;
  const fundEstimate = 1_311_160n;

  rows.push({ label: 'P4 Execute Payroll (est. from execute treasury dry-run class)', status: 'estimate', gas: executeEstimate, err: null });
  rows.push({ label: 'P4 Create Revenue Mandate (est.)', status: 'estimate', gas: createMandateEstimate, err: null });
  rows.push({ label: 'P4 Fund Revenue Vault (est.)', status: 'estimate', gas: fundEstimate, err: null });
  rows.push({ label: 'P4 Simulate Revenue (est.)', status: 'estimate', gas: simulateEstimate, err: null });
  rows.push({ label: 'P4 Execute Revenue (est.)', status: 'estimate', gas: executeEstimate, err: null });
  rows.push({ label: 'P4 Create Investment Mandate (est.)', status: 'estimate', gas: createMandateEstimate, err: null });
  rows.push({ label: 'P4 Fund Investment Vault (est.)', status: 'estimate', gas: fundEstimate, err: null });
  rows.push({ label: 'P4 Simulate Investment (est.)', status: 'estimate', gas: simulateEstimate, err: null });
  rows.push({ label: 'P4 Execute Investment (est.)', status: 'estimate', gas: executeEstimate, err: null });

  const phases = {
    governor: ['Governor fund Wallet A', 'Governor fund Wallet B'],
    p1: ['P1 Create Treasury Wallet A', 'Governor fund Wallet A', 'Governor fund Wallet B', 'P1 Create Treasury Wallet B'],
    p2: ['P2 Create Obligation'],
    p3: ['P3 Fund Treasury', 'P3 Simulate Treasury', 'P3 Execute Treasury'],
    p4Guardian: ['P4 Guardian Evaluate'],
    p4Payroll: ['P4 Create Payroll', 'P4 Fund Payroll Vault', 'P4 Simulate Payroll', 'P4 Execute Payroll (est. from execute treasury dry-run class)'],
    p4Revenue: ['P4 Create Revenue Mandate (est.)', 'P4 Fund Revenue Vault (est.)', 'P4 Simulate Revenue (est.)', 'P4 Execute Revenue (est.)'],
    p4Investment: ['P4 Create Investment Mandate (est.)', 'P4 Fund Investment Vault (est.)', 'P4 Simulate Investment (est.)', 'P4 Execute Investment (est.)'],
  };

  const govBal = BigInt((await client.getBalance({ owner: GOVERNOR })).totalBalance);

  console.log('=== Dry-run / historical gas (MIST) ===\n');
  let total = 0n;
  for (const r of rows) {
    total += r.gas;
    console.log(`${r.label}: ${r.gas} (${Number(r.gas) / 1e9} SUI) [${r.status}]${r.err ? ` ERR: ${r.err}` : ''}`);
  }

  console.log('\n=== Phase totals (gas only, MIST) ===');
  for (const [phase, labels] of Object.entries(phases)) {
    const sum = rows.filter((r) => labels.includes(r.label)).reduce((a, r) => a + r.gas, 0n);
    console.log(`${phase}: ${sum} (${Number(sum) / 1e9} SUI)`);
  }

  const walletACoins = FUND_WALLET_A_MIST;
  const walletBCoins = FUND_WALLET_B_MIST;
  const walletAGas = rows.filter((r) =>
    ['P1 Create Treasury Wallet A', 'P3 Fund Treasury', 'P4 Guardian Evaluate', 'P2 Create Obligation', 'P3 Simulate Treasury', 'P3 Execute Treasury'].includes(r.label),
  ).reduce((a, r) => a + r.gas, 0n);
  const walletBGas = rows.filter((r) =>
    r.label.startsWith('P1 Create Treasury Wallet B') || r.label.startsWith('P4'),
  ).reduce((a, r) => a + r.gas, 0n);
  const walletBCoinOut = PAYROLL_FUND + REVENUE_FUND + INVEST_FUND;
  const walletACoinOut = FUND_VAULT_MIST; // execute comes from vault

  const govTransfer = FUND_WALLET_A_MIST + FUND_WALLET_B_MIST;
  const govGas = rows.filter((r) => r.label.startsWith('Governor')).reduce((a, r) => a + r.gas, 0n);

  console.log('\n=== Funding requirement analysis ===');
  console.log(`Governor balance now: ${govBal} (${Number(govBal) / 1e9} SUI)`);
  console.log(`Governor transfers to wallets: ${govTransfer} (${Number(govTransfer) / 1e9} SUI)`);
  console.log(`Governor gas (2 fund txs): ${govGas} (${Number(govGas) / 1e9} SUI)`);
  console.log(`Governor total needed: ${govTransfer + govGas} (${Number(govTransfer + govGas) / 1e9} SUI)`);
  console.log(`Governor surplus after sprint: ${govBal - govTransfer - govGas} (${Number(govBal - govTransfer - govGas) / 1e9} SUI)`);
  console.log(`Wallet A funded: ${walletACoins}; gas+vault fund need ~${walletAGas + walletACoinOut}`);
  console.log(`Wallet A headroom: ${walletACoins - walletAGas - walletACoinOut}`);
  console.log(`Wallet B funded: ${walletBCoins}; gas+vault funds need ~${walletBGas + walletBCoinOut}`);
  console.log(`Wallet B headroom: ${walletBCoins - walletBGas - walletBCoinOut}`);
  console.log(`\nHardcoded MIN_GOV 1 SUI is ${MIN_GOV_MIST > govBal ? 'ABOVE' : 'BELOW'} current balance — gate is ${MIN_GOV_MIST > govBal ? 'incorrect for governor solvency' : 'ok'}`);
}

const MIN_GOV_MIST = 1_000_000_000n;
main().catch((e) => { console.error(e); process.exit(1); });
