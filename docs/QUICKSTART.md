# Quick Start Guide

Get up and running with the EVM Vault in 5 minutes!

## 🚀 Installation (1 minute)

```bash
# Already done - dependencies installed!
npm install
```

## ⚡ Quick Test (1 minute)

```bash
# Compile contracts
npm run compile

# Run all tests
npm test
```

Expected output: `21 passing ✅`

## 🎮 Try It Out (2 minutes)

```bash
# Run the interactive demo
npm run interact
```

This will:
1. Deploy a test token and vault
2. Mint tokens to users
3. Perform deposits and withdrawals
4. Show balances and statistics

## 📝 Basic Usage

### 1. Deploy Contracts

```javascript
// Deploy token
const token = await MockERC20.deploy("My Token", "MTK", ethers.parseEther("1000000"));

// Deploy vault
const vault = await Vault.deploy(await token.getAddress());
```

### 2. Deposit Tokens

```javascript
// Approve vault
await token.approve(vaultAddress, ethers.parseEther("100"));

// Deposit
await vault.deposit(ethers.parseEther("100"));

// Check shares
const shares = await vault.shares(userAddress);
```

### 3. Withdraw Tokens

```javascript
// Withdraw all shares
const userShares = await vault.shares(userAddress);
await vault.withdraw(userShares);
```

## 🎯 Common Commands

```bash
npm test              # Run tests
npm run compile       # Compile contracts
npm run interact      # Run demo
npm run clean         # Clean build files
```

## 📚 Next Steps

1. Read [README.md](./README.md) for full documentation
2. Check [USAGE.md](./USAGE.md) for detailed examples
3. Review [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md) for overview

## 🔥 Quick Deploy to Local Network

Terminal 1:
```bash
npm run node
```

Terminal 2:
```bash
npm run deploy:local
```

## 💡 Key Concepts

- **Shares**: Represent your portion of the vault
- **Deposit**: Add tokens, receive shares
- **Withdraw**: Burn shares, receive tokens
- **Proportional**: Shares represent % of total pool

## ⚠️ Important

- Always approve tokens before depositing
- Shares ≠ Tokens (shares are proportional)
- First depositor gets 1:1 ratio
- Later depositors get proportional shares

## 🆘 Troubleshooting

**Tests failing?**
```bash
npm run clean
npm run compile
npm test
```

**Need help?**
- Check the test files for examples
- Read USAGE.md for detailed guides
- Review contract comments

---

**You're all set!** 🎉

The vault is ready to use. Start with `npm test` to verify everything works.
