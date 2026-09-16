# Deploy TITAN Command Center for Slush wallet validation (HTTPS)

## Quick test (anonymous Netlify — password gated)

If an anonymous deploy was already run, open:

- **Site:** https://glittery-dasik-7e17f6.netlify.app
- **Password:** `My-Drop-Site` (Netlify Drop requirement)
- **Wallet test pages:**
  - `/wallet-navi-pattern.html` — Mysten reference + Slush connect
  - `/wallet-raw.html` — raw `standard:connect`
  - `/demo` — Judge Demo

Claim within 60 minutes to remove the drop password:  
https://app.netlify.com/drop/

## Production deploy (recommended — no drop password)

### Option A: Netlify (authenticated)

```powershell
cd "c:\Users\niyat\New folder"
npm run build
$env:NETLIFY_AUTH_TOKEN = "<your-token>"
npx netlify-cli deploy --prod --dir packages/command-center/dist --site <site-id>
```

Environment variables for Netlify UI (Site settings → Environment variables) are listed in root `netlify.toml` under `[build.environment]`.

### Option B: Vercel

```powershell
cd "c:\Users\niyat\New folder\packages\command-center"
npx vercel login
npx vercel --prod
```

Set the same `VITE_*` variables in the Vercel project dashboard. `vercel.json` is included.

### Option C: Cloudflare Pages

Connect the repo in Cloudflare dashboard, or:

```powershell
npx wrangler pages deploy packages/command-center/dist --project-name titan-command-center
```

## Build locally

```powershell
cd "c:\Users\niyat\New folder"
npm run build
```

Production env is baked from `packages/command-center/.env.production`.

## Slush validation protocol

1. Open HTTPS site (not localhost).
2. Slush extension → Testnet, unlock wallet.
3. Visit `/wallet-navi-pattern.html` → Connect Slush.
4. If connect succeeds → FORBIDDEN was localhost/HTTP-specific.
5. If connect still fails → Slush/extension issue unrelated to TITAN origin.
