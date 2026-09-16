# Slush Wallet Validation — TITAN MandateOS

## Status: integrated on public HTTPS

Slush connects on **stable public HTTPS** origins. Localhost / self-signed HTTPS is blocked by the Slush extension (not TITAN wiring).

## Confirmed success (2026-06-20)

| Field | Value |
|-------|--------|
| Origin | `https://transcendent-gecko-b31768.netlify.app` |
| Probe page | `/wallet-raw.html` |
| Method | `getWallets()` + `standard:connect({ silent: false })` |
| Account | `0xf6472cc0…e768` (testnet) |
| Silent reconnect | Works after first approval |
| TRPC error | **none** |

## TITAN integration (matches probe)

| Piece | Behavior |
|-------|----------|
| `connectSlushViaStandard()` | Same call as `wallet-raw.html` |
| `SlushConnectButton` | Raw connect → sync dapp-kit via silent `useConnectWallet` |
| `WalletProvider` | `autoConnect` on public HTTPS only (`shouldSlushAutoConnect()`) |
| `bootstrapWalletRegistry` | `getWallets()` only — no web Slush registration |
| Local dev | Connect disabled on HTTP localhost; use Vercel/Netlify for Slush |

## localhost failure (expected)

```
path:        dApp.connect
code:        FORBIDDEN
httpStatus:  403
message:     You must first set up your wallet to interact with apps.
```

| Layer | localhost:5174 | public HTTPS |
|-------|----------------|--------------|
| `standard:connect()` | Executes | Executes |
| Slush popup / Connected Apps | Never reached | Works after approve |
| Accounts returned | No | Yes |

## Test checklist (production)

1. Deploy (`npm run deploy:vercel` or Netlify — see `docs/DEPLOY_VERCEL.md`).
2. Open production origin (note exact URL).
3. Slush → **Testnet**, wallet unlocked, allow popups.
4. Click **Connect Slush** in sidebar or `/connect`.
5. Approve Slush popup → address appears in header/sidebar.
6. Refresh → silent reconnect should restore session.

## Minimal repro pages

- `/wallet-raw.html` — raw Wallet Standard (no React)
- `/wallet-navi-pattern.html` — dapp-kit reference pattern

Both succeed on public HTTPS with the same Slush profile that fails on localhost.
