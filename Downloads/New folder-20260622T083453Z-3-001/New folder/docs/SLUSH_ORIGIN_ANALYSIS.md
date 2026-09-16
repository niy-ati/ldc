# Slush Origin Blocking Analysis

## Raw TRPC failure (confirmed)

```
path:        dApp.connect
code:        FORBIDDEN
httpStatus:  403
message:     You must first set up your wallet to interact with apps.
```

TITAN reaches `standard:connect()` → Slush extension receives the call → Slush TRPC rejects **before** any Connected Apps entry is created.

## What “before authorization” means

| Signal | localhost:5174 | NAVI / prior Netlify |
|--------|------------------|----------------------|
| `standard:connect()` invoked | Yes | Yes |
| Slush popup / approval UI | No (or never completes) | Yes |
| Origin in Connected Apps | **Never appears** | Appears after approve |
| TRPC result | FORBIDDEN 403 | Success |
| Accounts returned | No | Yes |

Connected Apps only lists origins **after** the user approves in the Slush connect flow. A FORBIDDEN at `dApp.connect` means Slush blocked the origin at the extension authorization layer — not a post-connect TITAN bug.

## Origin comparison matrix

| Origin type | Example | Cert | In Connected Apps | Connect result |
|-------------|---------|------|-------------------|----------------|
| HTTPS production (known dApp) | `app.naviprotocol.io` | Public CA | Yes | Success |
| HTTPS production (TITAN Netlify) | `*.netlify.app` (prior deploys) | Public CA | Yes (historical) | Success (when site live) |
| HTTPS localhost (Vite dev) | `https://localhost:5174` | **Self-signed** | **Never** | FORBIDDEN 403 |
| HTTP localhost | `http://localhost:5173` | N/A | No | Blocked (HTTP) |
| Ephemeral tunnel | `*.trycloudflare.com` | Public CA | No | FORBIDDEN (observed) |
| LAN IP | `http://192.168.x.x:5173` | N/A | No | Blocked |

## Does Slush block each origin class?

### 1. Self-signed localhost certificates — **likely yes**

- Vite `dev:https` uses `@vitejs/plugin-basic-ssl` (self-signed).
- The **page** loads after accepting the browser cert warning; the **extension** runs in a separate trust context.
- FORBIDDEN 403 with a generic “set up your wallet” message is consistent with an internal origin gate, not incomplete onboarding (same wallet works on NAVI).
- Chrome’s `allow-insecure-localhost` flag affects page TLS only; it does not guarantee wallet extension TRPC will trust the origin.

### 2. localhost origins — **likely restricted**

- Slush stores permissions per exact origin (`localhost` ≠ `127.0.0.1` ≠ port).
- Even on HTTPS localhost, **no Connected Apps entry** implies the connect handshake never reached the approval step.
- Mysten forum: Slush support asks “Are you on localhost?” when sites are flagged — localhost is treated differently from production HTTPS.

### 3. Development origins — **yes for non-production patterns**

- HTTP dev origins: rejected (TITAN origin gate also blocks these).
- Ephemeral tunnel hostnames: observed FORBIDDEN (Slush likely blocks non-stable / relay domains).
- Stable `*.netlify.app` with public CA: **allowed** when user completes approval (historical TITAN deploys in Connected Apps).

### 4. Untrusted / flagged origins — **possible but secondary here**

- Slush can mark sites “malicious” (Sui forum reports).
- Prior TITAN Netlify URLs **did** reach Connected Apps, so TITAN is not globally blocklisted.
- Suspended/password-gated Netlify drops (401) are a **hosting** issue, not Slush origin logic.

## Root cause ranking (current evidence)

1. **Pre-authorization TRPC origin gate in Slush extension** — FORBIDDEN 403, no Connected Apps entry, NAVI works on same wallet.
2. **Self-signed `https://localhost:5174`** — strongest localhost-specific explanation.
3. **Ephemeral / dev hostnames** — blocks quick tunnels; not applicable to stable Netlify.
4. **Incomplete wallet setup** — ruled out (NAVI + same extension profile).

## Production test (required next step)

Deploy to **stable public HTTPS** (Netlify prod — see `docs/DEPLOY.md`), then:

| Step | Action |
|------|--------|
| 1 | Open `https://<your-site>.netlify.app` |
| 2 | Slush → Testnet, unlock |
| 3 | Connect Slush on TITAN |
| 4 | Check Connected Apps for exact origin |
| 5 | Record TRPC payload if it fails |

### Expected differentiation

| Production result | Conclusion |
|-------------------|------------|
| Connect succeeds + origin in Connected Apps | Slush blocks **localhost/self-signed/dev** origins only |
| Same FORBIDDEN 403, no Connected Apps entry | Escalate to Mysten/Slush with raw TRPC — **not a TITAN fix** |
| Site 401 / password gate | Fix Netlify hosting first (anonymous drop expired) |

## Policy: no further TITAN wallet code changes

Unless production HTTPS reproduces the same `FORBIDDEN` / `dApp.connect` error, do not modify TITAN wallet integration. The failure is inside Slush’s extension authorization layer.

## Escalation payload for Mysten

```
Wallet:     com.mystenlabs.suiwallet (Slush extension)
Network:    testnet
Origin:     https://localhost:5174  (or production URL after deploy)
Path:       dApp.connect
Code:       FORBIDDEN
HTTP:       403
Message:    You must first set up your wallet to interact with apps.
Repro:      Same wallet connects on app.naviprotocol.io; origin never appears in Connected Apps on TITAN origin.
dApp stack: @mysten/dapp-kit 0.20.0, Wallet Standard standard:connect (no custom TRPC from TITAN)
```
