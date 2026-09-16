# TITAN Repository Audit

Generated: 2026-06-21  
Scope: `packages/command-center/src`, `packages/mandateos-sdk/src`, `scripts/`, `mandateos/sources/` (excludes `node_modules/`, `dist/`, `build/`)

**Policy:** Findings are documented only — nothing removed automatically.

---

## Summary

| Category | Production-reachable hits | Recommendation |
|----------|---------------------------|----------------|
| `console.log(` | 80+ (mostly wallet debug) | Keep in dev probe pages; gate production bundle paths |
| `mock` / CSS mockups | Hub intro only | Keep — decorative UI preview, not data |
| `seeded` / `sandbox` | Comments + hidden routes | Keep — documents policy |
| `synthesizeHistory` (SDK) | Capital analytics ranking | Review — synthetic APY history for advisory scores only |
| `MARKET_SEED_CATALOG` | Orphan data file | Review — unused by live catalog; only audit constant references |
| `TODO` / `FIXME` / `HACK` | None in app source | None |
| Verification `console.log` | CLI scripts only | Keep — operator output |

---

## 1. Production routes — classification tokens

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `lib/realityClassification.ts` | 8 | `'MOCK'` type | Y (route registry) | Keep — gating metadata |
| `lib/realityClassification.ts` | 24 | `Sandbox Demo` `/demo` | N (hidden) | Keep — blocked by `RealityRouteGate` |
| `lib/realityClassification.ts` | 52 | Yield Tokens `MOCK` | N (hidden) | Keep |

---

## 2. Liquidity terminal — no synthetic data (policy comments)

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `hooks/useLiquidityTerminal.ts` | 70 | `No seeded data` comment | Y (`/app/markets`) | Keep — documents contract |
| `lib/liquidityTerminalData.ts` | 1 | `no seeded fallback` | Y | Keep |
| `components/SuiMarketTerminal.tsx` | 116 | `No seeded or synthetic market data` | Y | Keep |

---

## 3. Hub decorative mockups (CSS-only, not market data)

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `components/hub/DeskMockups.tsx` | 1 | `Isometric glass desk mockups` | Y (`/hub`, wave intro) | Keep — static UI chrome |
| `components/hub/DeskMockups.tsx` | 10–133 | `mock-dash`, `MOCK_MAP` | Y | Keep — CSS class names, not fake API data |
| `components/TitanWaveIntro.tsx` | 2, 56 | `IntroDeskMockup` | Y (landing flow) | Keep |

---

## 4. Hidden simulated trade terminal (CoinGecko screener)

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `pages/TradePage.tsx` | 1–7 | `MarketTerminal` | N (`productionHidden`, `/app/trade`) | Hold — active route import; delete only after approval |
| `components/MarketTerminal.tsx` | 132 | CoinGecko screener UI | N | Hold |
| `hooks/useMarketTerminal.ts` | 15 | Uses `useMarketCatalog` (CoinGecko) | N | Hold |
| `hooks/useSuiMarketTerminal.ts` | 29 | Orphan hook | N (unused) | **Candidate delete** after approval |

---

## 5. Orphan / legacy seed catalog

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `data/marketSeedCatalog.ts` | 135 | `MARKET_SEED_CATALOG` static prices | **N** — no importers in runtime hooks | Review for removal after approval |
| `lib/metricAuditConstants.ts` | 19 | Labels seed as `FALLBACK_DATA` | N (audit metadata) | Keep until seed file removed |
| `hooks/useMarketCatalog.ts` | 3–7 | Uses `fetchCoinGeckoCatalog` only | Y (Trade page path only) | Keep |

---

## 6. SDK — synthetic history for advisory ranking

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `mandateos-sdk/src/product/sui-protocol-adapters.ts` | 144–148 | `synthesizeHistory()` for APY sparkline | Y if capital/routes pages used | **Review** — not used by Liquidity Terminal; advisory MAGMA-style scores only |
| `mandateos-sdk/src/product/sui-protocol-adapters.ts` | 90 | `historicalApy: synthesizeHistory(...)` | Same | Document in UI provenance if surfaced |

---

## 7. Wallet debug — `console.log` (dev / probe pages)

Production main app (`main.tsx` → `/app/*`) includes wallet sync logging. Standalone probe HTML pages bundle separately.

| File | Lines | Snippet | Production? | Action |
|------|-------|---------|-------------|--------|
| `wallets/useSlushWalletSync.ts` | 50 | `WalletProvider mounted` | **Y** (all routes) | Review — wrap in `import.meta.env.DEV` |
| `wallets/TitanWalletContext.tsx` | 51 | `[profile-diag] WalletContext` | Y | Review — dev-only gate |
| `lib/initWalletStandard.ts` | 11–29 | wallet registration logs | Y | Review |
| `wallets/slushWalletRestore.ts` | 105–150 | restore diagnostics | Y | Review |
| `lib/walletDebug.ts` | 47–109 | connect debug groups | Y (via connect paths) | Keep for Slush troubleshooting |
| `wallet-test-main.tsx` | 56, 393, 411 | `[wallet-test]` | N (`wallet-test.html`) | Keep — dev page |
| `wallet-raw.ts` | 29 | raw probe log | N (`wallet-raw.html`) | Keep |
| `wallet-slush-inspector.ts` | 38, 217 | inspector logs | N (standalone HTML) | Keep |
| `wallet-slush-accounts.ts` | 44, 170 | exposure report | N (standalone HTML) | Keep |
| `wallet-auth-audit.ts` | 129 | auth audit | N (standalone HTML) | Keep |
| `components/WalletDiagnosticPanel.tsx` | 41 | profile-diag export | N (`DEV` route only) | Keep |

---

## 8. Config / sandbox references

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `lib/config.ts` | 5 | `Sandbox fixtures only on /demo` | N (`/demo` hidden) | Keep |
| `lib/realityClassification.ts` | 25 | `/scenarios` fixture sim hidden | N | Keep |

---

## 9. Verification scripts — `console.log` (CLI only)

| File | Example lines | Snippet | Production? | Action |
|------|---------------|---------|-------------|--------|
| `scripts/run-judge-verification.ts` | 763–764 | `✓ PROGRAMMABLE_MONEY_PROOF.md` | N (CLI) | Keep |
| `scripts/run-defi-chain-verified.ts` | 621–626 | verification summary | N (CLI) | Keep |
| `scripts/validate-proof-artifacts.mjs` | 44, 186 | `PASS` / validations | N (CLI) | Keep |
| `scripts/demo-judge.mjs` | 62–260 | demo judge report | N (CLI) | Keep |

---

## 10. Move contracts

| File | Line | Snippet | Production? | Action |
|------|------|---------|-------------|--------|
| `mandateos/sources/types.move` | 80–86 | `TEMPLATE_*` constants | Y (on-chain) | Keep — protocol constants, not temp code |

---

## 11. Secrets scan (pre-GitHub)

| Path | Finding | Production? | Action |
|------|---------|-------------|--------|
| `packages/command-center/.env.production` | Public package IDs + network | Local only | **Gitignore** — do not commit |
| `packages/command-center/.env.local` | Local overrides | Local only | **Gitignore** |
| `proof/*.json` | Public wallet addresses, digests | Y (proof pack) | Safe to commit — no private keys found |
| Root `.md` reports | Public addresses | Docs | Safe |

---

## Recommended follow-ups (require approval)

1. **Delete** `hooks/useSuiMarketTerminal.ts` — orphaned
2. **Delete or archive** `data/marketSeedCatalog.ts` — no runtime imports
3. **Gate** `useSlushWalletSync` / `TitanWalletContext` console logs behind `import.meta.env.DEV`
4. **Add** root `lint` and `typecheck` scripts (CC `tsc` currently fails with ~40 pre-existing errors; Vite build passes)
5. **Update** verification script output paths to `docs/reports/` (optional — scripts currently write repo root)

---

## Search commands used

```text
grep -R "MarketTerminal" packages/command-center/src
grep -R "useMarketTerminal" packages/command-center/src
grep -R "TradePage" packages/command-center/src
grep TODO|FIXME|HACK|TEMP|DEBUG packages/**/src
grep console.log( packages/command-center/src
grep -i mock|stub|fake|seeded|sandbox packages/**/src
```
