# @mandateos/sdk

TypeScript PTB SDK for **MandateOS** — the sole interface for frontend and demo flows.

Business-level operations (treasury disbursement, payroll, governance, delegation, guardian) are exposed as `Transaction` builders. Protocol internals (workflow witnesses, constitutional validation, liquidity checks) are composed inside the SDK and never leak to application code.

## Install

```bash
npm install @mandateos/sdk @mysten/sui
```

From the monorepo workspace root:

```bash
npm install
npm run build:sdk
```

## Setup

Publish the Move package first, then configure the SDK with the on-chain package ID:

```typescript
import { SuiClient } from '@mysten/sui/client';
import { MandateOSClient, parseCreatedTreasury, parseSimulationApprovalId } from '@mandateos/sdk';

const client = new MandateOSClient({
  packageId: process.env.MANDATEOS_PACKAGE_ID!,
});
const sui = new SuiClient({ url: 'https://fullnode.testnet.sui.io:443' });
```

## Treasury flow (simulate → approve → execute)

MandateOS requires a **two-transaction** pattern: the governor simulates and approves; the executor settles with the consumable approval object.

### 1. Create treasury

```typescript
const createTx = client.buildCreateTreasuryTx({
  owner: governorAddress,
  executor: executorAddress,
  targetBalance: 10_000_000_000n,
  maxPerTransaction: 5_000_000_000n,
  maxDaily: 10_000_000_000n,
  minReserveBps: 1000,
  contributionBps: 0,
  contributionRecipient: recipientAddress,
  multisigThreshold: 1n,
});

const createResult = await sui.signAndExecuteTransaction({
  signer: governorKeypair,
  transaction: createTx,
  options: { showObjectChanges: true },
});

const { graph, ownerAssets } = parseCreatedTreasury(
  createResult,
  client.packageId,
  client.coinType,
);
```

### 2. Fund vault

```typescript
const fundTx = client.buildFundVaultTx(graph, { amount: 1_000_000_000n });
```

### 3. Simulate and approve (governor)

```typescript
const simulateTx = client.buildSimulateTreasuryDisbursementTx(graph, {
  amount: 100_000_000n,
  recipient: recipientAddress,
  executor: executorAddress,
});

const simResult = await sui.signAndExecuteTransaction({
  signer: governorKeypair,
  transaction: simulateTx,
  options: { showObjectChanges: true },
});

const approvalId = parseSimulationApprovalId(simResult, client.packageId)!;
```

### 4. Execute disbursement (executor)

```typescript
const executeTx = client.buildExecuteTreasuryDisbursementTx(graph, {
  amount: 100_000_000n,
  recipient: recipientAddress,
  approvalId,
});

await sui.signAndExecuteTransaction({ signer: executorKeypair, transaction: executeTx });
```

## API surface

| Category | Methods |
|----------|---------|
| Bootstrap | `buildCreateTreasuryTx`, `buildCreatePayrollTx`, `buildCreateSubscriptionTx`, `buildFundVaultTx` |
| Simulation | `buildSimulateAndApproveTx`, `buildSimulateTreasuryDisbursementTx` |
| Execution | `buildExecuteTreasuryDisbursementTx`, `buildExecutePayrollTx`, `buildExecuteSubscriptionPaymentTx`, `buildExecuteRevenueDistributionTx`, `buildExecuteInvestmentTx` |
| Governance | `buildPauseMandateTx`, `buildResumeMandateTx`, `buildRegisterObligationTx`, `buildRebalanceLiquidityTx` |
| Delegation | `buildIssueExecutorCapTx` |
| Guardian | `buildEvaluateGuardianTx`, `buildEvaluateAndShareGuardianTx`, `buildExecuteGuardianActionTx` |

## Object graph

After bootstrap, store the returned `TreasuryMandateGraph` (shared object IDs). The SDK uses this bundle for all subsequent operations — callers never pass individual module paths or workflow types.

## Constants

`ActionKind`, `MandateType`, `MandateStatus`, and `ProtocolBit` mirror on-chain `mandateos::types` for use in simulation and delegation configuration.

## License

MIT
