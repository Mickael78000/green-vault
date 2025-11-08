# Vault Project - Foundry Edition

A secure and feature-rich vault implementation for ERC20 tokens on EVM-compatible blockchains, now using Foundry for development, testing, and deployment.

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Git

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd windsurf-project

# Install dependencies
forge install

# Build contracts
forge build
```

### Running Tests

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vv

# Run tests with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/Vault.t.sol

# Run specific test function
forge test --match-test test_AllowsUsersToDepositTokens

# Run tests with coverage
forge coverage
```

## 📁 Project Structure

```
├── src/                    # Smart contracts
│   ├── Vault.sol          # Basic vault implementation
│   ├── VaultEnhanced.sol  # Enhanced vault with fees and pausability
│   └── MockERC20.sol      # Mock ERC20 for testing
├── test/                   # Solidity tests
│   ├── Vault.t.sol        # Tests for basic vault
│   └── VaultEnhanced.t.sol # Tests for enhanced vault
├── script/                 # Deployment and interaction scripts
│   ├── DeployVault.s.sol  # Deployment scripts
│   └── InteractVault.s.sol # Interaction scripts
├── lib/                    # Dependencies (managed by forge)
├── foundry.toml           # Foundry configuration
└── .env.example           # Environment variables template
```

## 🔧 Configuration

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Required environment variables:
- `PRIVATE_KEY`: Your wallet private key (for deployments)
- `SEPOLIA_RPC_URL`: RPC URL for Sepolia testnet
- `ETHERSCAN_API_KEY`: For contract verification
- `TOKEN_ADDRESS`: Address of the ERC20 token (for production deployments)
- `VAULT_ADDRESS`: Address of deployed vault (for interactions)

## 📝 Smart Contracts

### Vault.sol
Basic vault implementation with:
- Deposit ERC20 tokens and receive shares
- Withdraw tokens by burning shares
- Proportional share calculation
- Reentrancy protection

### VaultEnhanced.sol
Enhanced vault with additional features:
- Configurable deposit and withdrawal fees
- Pausability for emergency situations
- Emergency withdrawal function (works even when paused)
- Fee recipient management
- Comprehensive statistics tracking

### MockERC20.sol
Simple ERC20 token for testing purposes with:
- Minting capability
- Standard ERC20 functionality

## 🚀 Deployment

### Local Deployment (Anvil)

```bash
# Start local node
anvil

# Deploy contracts (in another terminal)
forge script script/DeployVault.s.sol:DeployVault --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

### Testnet Deployment (Sepolia)

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

### Mainnet Deployment

```bash
# Deploy VaultEnhanced with existing token
forge script script/DeployVault.s.sol:DeployVaultEnhancedWithToken \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## 🔍 Verification

Contracts are automatically verified during deployment if you use the `--verify` flag. To verify manually:

```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## 🎯 Interacting with Contracts

### Using Cast (Foundry CLI)

```bash
# Check vault balance
cast call <VAULT_ADDRESS> "balanceOf(address)" <USER_ADDRESS> --rpc-url $SEPOLIA_RPC_URL

# Check total shares
cast call <VAULT_ADDRESS> "totalShares()" --rpc-url $SEPOLIA_RPC_URL

# Deposit tokens (requires approval first)
cast send <TOKEN_ADDRESS> "approve(address,uint256)" <VAULT_ADDRESS> 100000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send <VAULT_ADDRESS> "deposit(uint256)" 100000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Using Scripts

```bash
# Interact with Vault
forge script script/InteractVault.s.sol:InteractVault \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# Interact with VaultEnhanced
forge script script/InteractVault.s.sol:InteractVaultEnhanced \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

## 🧪 Testing

The project includes comprehensive test suites:

### Vault Tests (22 tests)
- Deployment tests
- Deposit functionality
- Withdrawal functionality
- Balance calculations
- Security tests
- Fuzz tests

### VaultEnhanced Tests (30 tests)
- All Vault tests
- Fee configuration tests
- Pausability tests
- Emergency withdrawal tests
- Statistics tracking tests
- Fuzz tests with variable fees

### Running Specific Test Categories

```bash
# Run only deployment tests
forge test --match-test test_Deployment

# Run only fuzz tests
forge test --match-test testFuzz

# Run tests with gas snapshots
forge snapshot
```

## 📊 Gas Optimization

View gas reports:

```bash
forge test --gas-report
```

Create gas snapshots:

```bash
forge snapshot
```

Compare gas usage:

```bash
forge snapshot --diff
```

## 🔐 Security

- All contracts use OpenZeppelin's battle-tested libraries
- Reentrancy protection on all state-changing functions
- Comprehensive test coverage
- Emergency pause functionality in VaultEnhanced
- Fee limits to prevent excessive charges

### Security Auditing

```bash
# Run Slither static analyzer (if installed)
slither .

# Run Mythril security analyzer (if installed)
myth analyze src/Vault.sol
```

## 🛠️ Development

### Formatting

```bash
# Format code
forge fmt

# Check formatting
forge fmt --check
```

### Cleaning

```bash
# Clean build artifacts
forge clean

# Clean and rebuild
forge clean && forge build
```

## 📚 Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry GitHub](https://github.com/foundry-rs/foundry)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Troubleshooting

### Common Issues

**Issue: `forge: command not found`**
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**Issue: `Error: Failed to resolve imports`**
```bash
# Reinstall dependencies
forge install --force
```

**Issue: `Error: Compiler version mismatch`**
```bash
# Clean and rebuild
forge clean
forge build
```

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review test files for usage examples
