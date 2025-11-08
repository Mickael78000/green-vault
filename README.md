# Green Vault

A secure and feature-rich vault implementation for ERC20 tokens on EVM-compatible blockchains, built with Foundry.

## ✨ Features

- **Basic Vault**: Simple deposit/withdraw functionality with proportional share distribution
- **Enhanced Vault**: Advanced features including:
  - Configurable deposit and withdrawal fees
  - Pausability for emergency situations
  - Emergency withdrawal (works even when paused)
  - Comprehensive statistics tracking
  - Fee recipient management

## 🚀 Quick Start

```bash
# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report
```

## 📖 Documentation

- **[Foundry Guide](docs/README_FOUNDRY.md)** - Complete guide for using Foundry with this project
- **[Project Summary](docs/PROJECT_SUMMARY.md)** - Detailed project overview
- **[Quick Start Guide](docs/QUICKSTART.md)** - Get started quickly
- **[Usage Guide](docs/USAGE.md)** - How to use the contracts

## 🔧 Configuration

Create a `.env` file with the following variables:

- `PRIVATE_KEY`
- `SEPOLIA_RPC_URL`
- `ETHERSCAN_API_KEY`
- `TOKEN_ADDRESS`
- `VAULT_ADDRESS`

## 📁 Project Structure

```
src/                    # Smart contracts
├── Vault.sol
├── VaultEnhanced.sol
└── MockERC20.sol
test/                   # Solidity tests
script/                 # Deployment and interaction scripts
lib/                    # Dependencies (managed by forge)
foundry.toml            # Foundry configuration
```

## 🧪 Testing

The project includes comprehensive tests covering:
- Deployment scenarios
- Deposit and withdrawal functionality
- Fee calculations
- Pausability and emergency features
- Edge cases and security
- Fuzz testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test file
forge test --match-path test/Vault.t.sol

# Generate coverage report
forge coverage
```

## 📦 Contracts

### Vault.sol
Basic vault with core functionality:
- Deposit ERC20 tokens for shares
- Withdraw tokens by burning shares
- Proportional share calculation
- Reentrancy protection

### VaultEnhanced.sol
Enhanced vault with additional features:
- All Vault.sol features
- Configurable fees (max 10%)
- Pause/unpause functionality
- Emergency withdrawal
- Statistics tracking (TVL, deposits, withdrawals)

### MockERC20.sol
Testing token with minting capability

## 🚀 Deployment

### Local (Anvil)

```bash
# Start a local node
anvil

# In another terminal, deploy using your local private key
forge script script/DeployVault.s.sol:DeployVault \
  --rpc-url anvil \
  --broadcast \
  --private-key $PRIVATE_KEY
```

### Testnet (Sepolia)

```bash
# Deploy with mock token
forge script script/DeployVault.s.sol:DeployVault \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Deploy with existing token
forge script script/DeployVault.s.sol:DeployVaultWithToken \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Mainnet

```bash
# Deploy VaultEnhanced with existing token
forge script script/DeployVault.s.sol:DeployVaultEnhancedWithToken \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

See [docs/README_FOUNDRY.md](docs/README_FOUNDRY.md) for detailed deployment instructions.

## 🔐 Security

- Built with OpenZeppelin's audited contracts
- Reentrancy guards on all state-changing functions
- Comprehensive test coverage
- Fee limits to prevent excessive charges
- Emergency pause functionality

## 🛠️ Built With

- [Foundry](https://book.getfoundry.sh/) - Ethereum development toolkit
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) - Secure smart contract library
- [Solidity ^0.8.20](https://docs.soliditylang.org/) - Smart contract language

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For detailed documentation and troubleshooting, see [docs/README_FOUNDRY.md](docs/README_FOUNDRY.md)
