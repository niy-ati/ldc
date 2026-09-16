# Wallet State Audit — Cross-Surface Consistency

## Symptom

Global header shows connected address, testnet label, and balance. **Navi Capital** (and Scallop/Cetus/Allocation) showed "Connect Slush wallet to use Navi" or behaved as if no wallet exists.

## Root cause

**Two wallet state sources** were used across the app:

| Surface | Hook (before) | Address source |
|---------|---------------|----------------|
| Header (`WalletBar`) | `useAuth()` | `useEffectiveWalletAddress()` (Titan session + dapp-kit) |
| Treasury | `useEffectiveWalletAddress()` / `useAuth()` | Same ✓ |
| Navi Capital | `useNaviWorkflow()` | `useCurrentAccount()` (dapp-kit only) ✗ |
| Scallop / Cetus | `useDefiProtocolWorkflow()` | `useCurrentAccount()` ✗ |
| Allocation Engine | `useCapitalAllocator()` → DeFi hooks | `useCurrentAccount()` ✗ |
| Mainnet balance / positions | `useMainnetWalletBalance`, `useExternalProtocolPositions` | `useCurrentAccount()` ✗ |

Titan session restores address from Slush `wallet.accounts` / localStorage for display. **dapp-kit `useCurrentAccount()` stays null** when `autoConnect={false}` and silent sync fails.

Navi signing checked `account?.address` from dapp-kit → threw **"Connect Slush wallet to use Navi"** even though header showed connected.

**Not a mainnet vs testnet mismatch for the connect gate** — Navi UI gate used `auth.connected` (correct). Failure was on **Sign · Deposit** via dapp-kit-only signing path.

## Fix

Single shared hook: **`useWalletConnection()`** (`packages/command-center/src/hooks/useWalletConnection.ts`)

All surfaces should use **`useAuth()`** (wraps `useWalletConnection`) or `useWalletConnection(surface)` directly.

Logging: filter DevTools for **`[wallet-state]`**

Fields logged per surface:

- `connected`
- `address`
- `treasuryNetwork` (app config, e.g. testnet)
- `defiNetwork` (mainnet — Navi/Scallop/Cetus)
- `walletProviderName`
- `dappKitConnected`
- `sessionSource`

DeFi signing unified via **`signAndExecuteMainnetWithSlush()`** in `walletStandardExecute.ts` — same Slush resolution as Treasury (Titan session + popup fallback).

## After fix — source map

| Surface | Hook | Signing |
|---------|------|---------|
| Header | `useAuth` | — |
| Treasury | `useAuth` / `useEffectiveWalletAddress` | `signAndExecuteWithSlushWallet` |
| Navi | `useWalletConnection` in `useNaviWorkflow` | `signAndExecuteMainnetWithSlush` |
| Scallop / Cetus | `useWalletConnection` in `useDefiProtocolWorkflow` | `signAndExecuteMainnetWithSlush` |
| Allocation | `useCapitalAllocator` → DeFi hooks | same |
| Mainnet balance | `useMainnetWalletBalance` | effective address |

## Note on networks

Treasury PTBs run on **testnet** (current deploy). Navi/Scallop/Cetus run on **mainnet**. Connected wallet address is the same; mainnet SUI balance may be **0** while testnet balance shows in header — that is expected (see ProtocolCapitalDesk "Fund wallet on mainnet" banner).
