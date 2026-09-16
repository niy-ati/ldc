# Deploy from repo ROOT (required for npm workspaces + @mandateos/sdk)

## Prerequisites

- Logged in: `npx vercel login`
- Stop any local dev servers (`npm run dev`) — they lock `dist/` on Windows

## First-time link (from repo root)

```powershell
cd "c:\Users\niyat\New folder"
npx vercel link
```

| Prompt | Answer |
|--------|--------|
| Directory | `.` (repo root) |
| Team | niyatijainn15-1145's projects |
| Project | Create new project |
| Name | **titan-mandateos** (lowercase only) |
| Customize settings? | **No** |

## Env vars + deploy

```powershell
cd "c:\Users\niyat\New folder"
powershell -ExecutionPolicy Bypass -File scripts/push-vercel-env.ps1
```

Then deploy from **repo root** (remote build — avoids Windows dist lock):

```powershell
mkdir .vercel -ErrorAction SilentlyContinue
copy packages\command-center\.vercel\project.json .vercel\project.json
npx vercel --prod --yes
```

Or: `npm run deploy:vercel` (after copying `.vercel\project.json` to repo root).

Vercel builds **remotely** (no local `dist` upload) — avoids Windows EPERM locks.

## Project URL

**Production:** https://titan-lemon-iota.vercel.app

Slush wallet connect: open that URL → Connect Slush → approve popup.

To sync env vars from `.env.production` (run from repo root with `.vercel/project.json` present):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/push-vercel-env.ps1
npx vercel --prod --yes
```
