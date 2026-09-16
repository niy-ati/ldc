# MandateOS — Judge Verification Pack

Place live proof artifacts here after testnet deployment.

## Required files

| File | Contents |
|------|----------|
| `deployment.json` | package id, publish digest |
| `testnet-results.json` | all demo tx digests + object ids |
| `screenshots/` | UI and explorer captures |

## Faucet funding

Deployer address (needs testnet SUI):

```
0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b
```

Web faucet: https://faucet.sui.io/?address=0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b

## Quick verify

```powershell
npm run testnet:publish   # after funding
npm run testnet:proof     # after publish
```

## Explorer base URLs

- Transaction: `https://suiscan.xyz/testnet/tx/{digest}`
- Object: `https://suiscan.xyz/testnet/object/{id}`
- Package: `https://suiscan.xyz/testnet/object/{packageId}`
