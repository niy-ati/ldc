# Fund Treasury Audit — Slush signing gate

## Symptom

Click **Fund 0.15 SUI** → UI shows `Approve Slush in the extension to sign transactions` with **no Slush popup**.

Wallet bar still shows address, balance, and network.

## Root cause

**Execution stopped in `requireWallet()` before PTB build or `signAndExecuteTransaction`.**

| Item | Value |
|------|--------|
| **File** | `packages/command-center/src/hooks/useMandateLifecycle.ts` |
| **Function** | `requireWallet()` (now `ensureWallet()`) |
| **Line** | ~34–36 (before fix) |
| **Thrown error** | `Approve Slush in the extension to sign transactions` |
| **Cause** | `auth.dappKitConnected === false` while `auth.connected === true` |

### Why wallet appears connected but signing fails

1. **Titan session** restores address from `localStorage` / `wallet.accounts` (`TitanWalletContext`, `useSlushWalletSync`).
2. **`useAuth().connected`** uses `useEffectiveWalletAddress()` → true when Titan session has address.
3. **`useAuth().dappKitConnected`** uses dapp-kit `useCurrentAccount()` → false because `WalletProvider autoConnect={false}` and silent dapp-kit sync was not run on page load.
4. **`requireWallet()`** required dapp-kit account → threw immediately.
5. **`signAndExecuteTransaction` was never called** → no Slush popup.

### Full path (before fix)

```
TreasuryExecutionPanel.run('fund')
  → lifecycle.fundTreasury(0.15)
    → getGraph()                         ✓ (if treasury loaded)
    → requireWallet()                    ✗ dappKitConnected false
    → buildFundVaultTx                   never reached
    → executeTx / signAndExecute         never reached
```

## Fix (v2 — wallet-standard signing)

The dapp-kit `signAndExecuteTransaction` path was removed for mandate PTBs. Signing now uses **Wallet Standard `sui:signTransaction`** (same as Navi/DeFi workflows):

| File | Change |
|------|--------|
| `walletStandardExecute.ts` | `resolveSlushSigningAccount()` opens Slush popup when `wallet.accounts` is empty; signs + executes via extension |
| `useMandateTransaction.ts` | Calls `signAndExecuteWithSlushWallet` instead of dapp-kit |
| `TreasuryExecutionPanel.tsx` | Uses `useEffectiveWalletAddress` for obligation/delegate recipient fallback |

When `wallet.accounts` is empty but Titan session shows an address (stale localStorage), clicking Fund/Register now triggers `standard:connect({ silent: false })` → **Slush popup**.

## Debugging

Filter DevTools console: `[fund-treasury]`

Steps logged:

1. `button_click` — TreasuryExecutionPanel
2. `fund_treasury_start` — useMandateLifecycle
3. `treasury_graph_lookup` — graph + object IDs
4. `require_wallet` / `ensure_signing_ready` — wallet state
5. `dapp_kit_sync_*` — dapp-kit connect attempts
6. `ptb_created` — SDK PTB built
7. `sign_and_execute_call` / `sign_and_execute_digest` — wallet signing

## Answers

| Question | Answer |
|----------|--------|
| Is `signAndExecuteTransaction` called? | **No** (before fix) — blocked at `requireWallet()` |
| Is PTB construction failing? | **No** — never reached |
| Is treasury object ID missing? | Only if graph not loaded; separate error message |
| Exception swallowed? | **No** — caught in `TreasuryExecutionPanel.run` → `setError` |
| Wallet capability detected correctly? | **Partially** — display uses Titan session; signing gate used dapp-kit only |
