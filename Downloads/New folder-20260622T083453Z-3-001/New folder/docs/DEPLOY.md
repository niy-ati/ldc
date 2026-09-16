# Deploy TITAN MandateOS — Production HTTPS

Stable public HTTPS is required to differentiate Slush **localhost/self-signed** blocking from true dApp defects.

## Build

```powershell
cd "c:\Users\niyat\New folder"
npm run build:release
```

Outputs to `packages/command-center/dist-release` (avoids Windows file-lock on `dist/` when dev server is running).

Production env (`VITE_DEMO_MODE=false`, testnet mandate IDs) is baked from `.env.production` + `netlify.toml`.

## Netlify production (recommended)

Provides stable `*.netlify.app` URL, public CA, SPA routing, and CoinGecko proxy from `netlify.toml`.

### Interactive

```powershell
npx netlify-cli login
npm run deploy:netlify
```

### CI / token (non-interactive)

1. Create token: Netlify → User settings → Applications → New access token
2. Create or link site in Netlify dashboard
3. Deploy:

```powershell
$env:NETLIFY_AUTH_TOKEN = "<token>"
npx netlify-cli deploy --prod --dir=packages/command-center/dist-release --site <site-id>
```

### Environment variables

Set in Netlify UI (Site → Environment variables) or use values from root `netlify.toml` `[build.environment]`.

Required for live mandate mode:

- `VITE_DEMO_MODE=false`
- `VITE_SUI_NETWORK=testnet`
- `VITE_MANDATEOS_PACKAGE_ID` and related object IDs

## After deploy

1. Confirm site returns **200** (not 401 password gate from expired Netlify Drop).
2. Run Slush test: `docs/SLUSH_VALIDATION.md`
3. Compare localhost vs production: `docs/SLUSH_ORIGIN_ANALYSIS.md`

## Not suitable for Slush validation

| Method | Why |
|--------|-----|
| `https://localhost:5174` | Self-signed cert; FORBIDDEN 403 observed; never in Connected Apps |
| `*.trycloudflare.com` | Ephemeral; Slush often blocks relay domains |
| Netlify Drop (anonymous) | Password-gated, expires; prior URLs may return 401 |

## Local dev (not for Slush prod test)

```powershell
npm run dev:https   # https://localhost:5174 — Slush validation only after production test fails same way
npm run dev         # http://localhost:5173 — browse only
```

## Vercel alternative

```powershell
cd packages/command-center
npx vercel login
npx vercel --prod
```

Set the same `VITE_*` variables in the Vercel project dashboard. `vercel.json` is included.
