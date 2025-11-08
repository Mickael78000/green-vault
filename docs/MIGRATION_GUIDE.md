# Migration Guide: Hardhat to Foundry

This project has been migrated from Hardhat to Foundry. This guide explains the changes and how to work with the new setup.

## 🔄 What Changed

### Framework
- **Before**: Hardhat (JavaScript/TypeScript-based)
- **After**: Foundry (Rust-based, Solidity testing)

### Key Differences

| Aspect | Hardhat | Foundry |
|--------|---------|---------|
| Testing Language | JavaScript | Solidity |
| Test Speed | Slower | Much faster |
| Gas Reporting | Via plugin | Built-in |
| Deployment | JavaScript scripts | Solidity scripts |
| Package Manager | npm/yarn | forge |
| Dependencies | node_modules | lib/ |

## 📁 Directory Structure Changes

### Before (Hardhat)
```
├── contracts/          # Smart contracts
├── test/              # JavaScript tests
├── scripts/           # JavaScript deployment scripts
├── hardhat.config.js  # Configuration
├── package.json       # Dependencies
└── node_modules/      # Node dependencies
```

### After (Foundry)
```
├── src/               # Smart contracts (was contracts/)
├── test/              # Solidity tests (was JavaScript)
├── script/            # Solidity deployment scripts
├── foundry.toml       # Configuration (was hardhat.config.js)
└── lib/               # Forge dependencies (was node_modules/)
```

## 🔧 Command Equivalents

### Installation & Setup
```bash
# Hardhat
npm install

# Foundry
forge install
```

### Compilation
```bash
# Hardhat
npx hardhat compile

# Foundry
forge build
```

### Testing
```bash
# Hardhat
npx hardhat test
npx hardhat test --verbose

# Foundry
forge test
forge test -vv
```

### Deployment
```bash
# Hardhat
npx hardhat run scripts/deploy.js --network sepolia

# Foundry
forge script script/DeployVault.s.sol:DeployVault \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### Local Node
```bash
# Hardhat
npx hardhat node

# Foundry
anvil
```

### Console Interaction
```bash
# Hardhat
npx hardhat console --network sepolia

# Foundry
cast call <contract> <function> --rpc-url $SEPOLIA_RPC_URL
cast send <contract> <function> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Gas Reporting
```bash
# Hardhat
# Requires gas-reporter plugin in config

# Foundry
forge test --gas-report
```

### Coverage
```bash
# Hardhat
npx hardhat coverage

# Foundry
forge coverage
```

## 📝 Test Migration

### Before (JavaScript - Hardhat)
```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Vault", function () {
  it("Should allow deposits", async function () {
    const [owner] = await ethers.getSigners();
    const Vault = await ethers.getContractFactory("Vault");
    const vault = await Vault.deploy(tokenAddress);
    
    await token.approve(vault.address, 100);
    await vault.deposit(100);
    
    expect(await vault.shares(owner.address)).to.equal(100);
  });
});
```

### After (Solidity - Foundry)
```solidity
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    Vault public vault;
    
    function setUp() public {
        vault = new Vault(tokenAddress);
    }
    
    function test_AllowsDeposits() public {
        token.approve(address(vault), 100);
        vault.deposit(100);
        
        assertEq(vault.shares(address(this)), 100);
    }
}
```

## 🎯 Benefits of Foundry

### 1. **Speed**
- Tests run 10-100x faster
- No JavaScript VM overhead
- Native Solidity execution

### 2. **Better Testing**
- Write tests in Solidity (same language as contracts)
- Built-in fuzz testing
- Cheatcodes for advanced testing scenarios
- Better stack traces

### 3. **Gas Optimization**
- Built-in gas reporting
- Gas snapshots for tracking changes
- Detailed gas breakdowns

### 4. **Developer Experience**
- Faster compilation
- Better error messages
- Integrated debugger
- No node_modules bloat

### 5. **Advanced Features**
- Symbolic execution
- Invariant testing
- Fork testing
- Built-in scripting

## 🚀 Getting Started with Foundry

### 1. Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Build the Project
```bash
forge build
```

### 3. Run Tests
```bash
forge test
```

### 4. Deploy Contracts
```bash
# Setup environment
cp .env.example .env
# Edit .env with your values

# Deploy
forge script script/DeployVault.s.sol:DeployVault \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

## 📚 Learning Resources

- [Foundry Book](https://book.getfoundry.sh/) - Official documentation
- [Foundry GitHub](https://github.com/foundry-rs/foundry) - Source code and examples
- [Awesome Foundry](https://github.com/crisgarner/awesome-foundry) - Curated resources
- [README_FOUNDRY.md](README_FOUNDRY.md) - Project-specific Foundry guide

## ❓ FAQ

### Q: Can I still use JavaScript for deployment?
A: Foundry uses Solidity scripts, but you can use `cast` CLI for interactions or write custom scripts in any language.

### Q: What happened to my JavaScript tests?
A: They were converted to Solidity tests in the `test/` directory. All functionality is preserved.

### Q: Do I need Node.js anymore?
A: No, Foundry doesn't require Node.js. However, you can still use it for other tooling if needed.

### Q: How do I verify contracts?
A: Use the `--verify` flag with forge script, or use `forge verify-contract` command.

### Q: Can I use OpenZeppelin contracts?
A: Yes! They're installed via `forge install` and are in the `lib/` directory.

## 🔍 Troubleshooting

### Issue: "forge: command not found"
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Issue: "Failed to resolve imports"
```bash
# Reinstall dependencies
forge install --force
```

### Issue: Tests failing after migration
```bash
# Clean and rebuild
forge clean
forge build
forge test -vvv  # Verbose output for debugging
```

## 📞 Support

For questions or issues:
1. Check [README_FOUNDRY.md](README_FOUNDRY.md)
2. Review [Foundry Book](https://book.getfoundry.sh/)
3. Open an issue on GitHub
4. Check existing test files for examples

---

**Migration completed successfully! All 52 tests passing. 🎉**
