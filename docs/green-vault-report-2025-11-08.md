# Green Vault Local Deployment & Interaction Report — 2025-11-08

## Summary
- Verified local Anvil node health.
- Updated Foundry RPC alias so `local` points to `127.0.0.1:8545` and used the `anvil` alias for reliability.
- Rebuilt (deploy profile, no via-IR) and deployed basic vaults (`Vault`, `VaultEnhanced`) with a `MockERC20` token using account (0).
- Performed token approvals, deposits, state checks, and partial withdrawals on both vaults.
- Saved accounts to docs/anvil-accounts.md and recorded addresses below.

## Node verification
- Listening: `true`
- Client: `"anvil/v1.4.3"`
- Chain ID: `1` (mainnet fork)
- Example block numbers observed: `23754885` (pre), `23754893` (post interactions)
- RPC aliases (foundry.toml):
  - local = http://127.0.0.1:8545
  - anvil = http://127.0.0.1:8545

## Accounts
- Stored at: `docs/anvil-accounts.md`
- Deployer (0): `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

## Build & deploy
- Build profile: `deploy` (via_ir=false)
- Script: `script/DeployVault.s.sol:DeployVault`
- Broadcast log: `broadcast/DeployVault.s.sol/1/run-latest.json`
- Deployed addresses:
  - Token (MockERC20 TEST): `0xB5055C59ec1a05D9e4Be31741a102EC3DBd5bf52`
  - Vault: `0x02184Db0Ca92Ff24b9dF33AEb22bC1d978E3B032`
  - VaultEnhanced: `0xA3710716965497e62bC3165Eb7DD2a1B1437f8Af`

## Interactions
All interactions executed using account (0) and RPC alias `anvil`.

- Initial balance (deployer): `1,000,000 TEST`
- Approvals:
  - Approve TEST to VaultEnhanced: `1,000 TEST`
  - Approve TEST to Vault: `500 TEST`

- Deposits:
  - VaultEnhanced `deposit(1,000 TEST)` → minted shares: `1,000` (1e21 wei)
  - Vault `deposit(500 TEST)` → minted shares: `500` (5e20 wei)

- Post-deposit checks:
  - VaultEnhanced `shares(deployer)`: `1,000` (1e21)
  - VaultEnhanced `totalShares`: `1,000` (1e21)
  - VaultEnhanced `totalValueLocked`: `1,000 TEST`
  - Vault `shares(deployer)`: `500` (5e20)

- Withdrawals (partial):
  - VaultEnhanced `withdraw(100 shares)` → returned `100 TEST`
  - Vault `withdraw(100 shares)` → returned `100 TEST`

- Final state (selected):
  - VaultEnhanced `totalValueLocked`: `900 TEST`
  - Token `balanceOf(VaultEnhanced)`: `900 TEST`

## Key commands (for reproducibility)
```bash
# Build (deploy profile)
FOUNDRY_PROFILE=deploy forge clean && FOUNDRY_PROFILE=deploy forge build

# Deploy
PRIVATE_KEY=<account_0_key> FOUNDRY_PROFILE=deploy \
forge script script/DeployVault.s.sol:DeployVault --rpc-url anvil --broadcast

# Approvals
cast send <TOKEN> "approve(address,uint256)" <ENH> 1000e18 --private-key <key> --rpc-url anvil
cast send <TOKEN> "approve(address,uint256)" <VAULT> 500e18 --private-key <key> --rpc-url anvil

# Deposits
cast send <ENH> "deposit(uint256)" 1000e18 --private-key <key> --rpc-url anvil
cast send <VAULT> "deposit(uint256)" 500e18 --private-key <key> --rpc-url anvil

# Checks
cast call <ENH> "shares(address)(uint256)" <ADDR> --rpc-url anvil
cast call <ENH> "totalShares()(uint256)" --rpc-url anvil
cast call <ENH> "totalValueLocked()(uint256)" --rpc-url anvil

# Withdrawals
cast send <ENH> "withdraw(uint256)" 100e18 --private-key <key> --rpc-url anvil
cast send <VAULT> "withdraw(uint256)" 100e18 --private-key <key> --rpc-url anvil
```

## Notes
- `VaultEnhanced` default fees are 0% for both deposit and withdrawal in this deployment; fee recipient is the deployer by default.
- The Green Vault strategy deploy script is temporarily a no-op to keep builds green while basic vaults are deployed; strategies can be restored and compiled later.
- RPC alias change to 127.0.0.1 avoids localhost resolution timeouts observed earlier.
