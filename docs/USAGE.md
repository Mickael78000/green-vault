# Vault Usage Guide

This guide demonstrates how to interact with the Vault smart contract.

## Quick Start

### 1. Compile Contracts

```bash
npm run compile
```

### 2. Run Tests

```bash
npm test
```

### 3. Deploy Locally

Terminal 1 - Start local node:
```bash
npm run node
```

Terminal 2 - Deploy contracts:
```bash
npm run deploy:local
```

## Interacting with the Vault

### Using Hardhat Console

Start the console:
```bash
npx hardhat console --network localhost
```

### Basic Operations

```javascript
// Get contract factories
const Vault = await ethers.getContractFactory("Vault");
const MockERC20 = await ethers.getContractFactory("MockERC20");

// Deploy token
const token = await MockERC20.deploy("Test Token", "TEST", ethers.parseEther("1000000"));
await token.waitForDeployment();

// Deploy vault
const vault = await Vault.deploy(await token.getAddress());
await vault.waitForDeployment();

// Get signers
const [owner, user1] = await ethers.getSigners();

// Mint tokens to user1
await token.mint(user1.address, ethers.parseEther("1000"));

// Approve vault to spend tokens
await token.connect(user1).approve(await vault.getAddress(), ethers.parseEther("100"));

// Deposit tokens
await vault.connect(user1).deposit(ethers.parseEther("100"));

// Check shares
const userShares = await vault.shares(user1.address);
console.log("User shares:", ethers.formatEther(userShares));

// Check balance
const userBalance = await vault.balanceOf(user1.address);
console.log("User balance:", ethers.formatEther(userBalance));

// Withdraw half
await vault.connect(user1).withdraw(userShares / 2n);

// Check final balance
const finalBalance = await token.balanceOf(user1.address);
console.log("Final token balance:", ethers.formatEther(finalBalance));
```

## Enhanced Vault Features

### Setting Fees (Owner Only)

```javascript
const VaultEnhanced = await ethers.getContractFactory("VaultEnhanced");
const enhancedVault = await VaultEnhanced.deploy(await token.getAddress());

// Set 1% deposit fee and 0.5% withdrawal fee
await enhancedVault.setFees(100, 50); // 100 basis points = 1%, 50 = 0.5%

// Set fee recipient
await enhancedVault.setFeeRecipient(owner.address);
```

### Pausing the Vault

```javascript
// Pause deposits and withdrawals
await enhancedVault.pause();

// Users can still use emergency withdraw
await enhancedVault.connect(user1).emergencyWithdraw(userShares);

// Unpause
await enhancedVault.unpause();
```

### Getting Statistics

```javascript
const stats = await enhancedVault.getStats();
console.log("Total Shares:", stats._totalShares.toString());
console.log("Total Deposited:", ethers.formatEther(stats._totalDeposited));
console.log("Total Withdrawn:", ethers.formatEther(stats._totalWithdrawn));
console.log("Current Balance:", ethers.formatEther(stats._currentBalance));
```

## Integration Example (JavaScript/TypeScript)

```javascript
import { ethers } from "ethers";

// Connect to provider
const provider = new ethers.JsonRpcProvider("http://localhost:8545");
const signer = await provider.getSigner();

// Contract addresses (from deployment)
const VAULT_ADDRESS = "0x...";
const TOKEN_ADDRESS = "0x...";

// Contract ABIs (import from artifacts)
const vaultAbi = [...]; // From artifacts/contracts/Vault.sol/Vault.json
const tokenAbi = [...]; // From artifacts/contracts/MockERC20.sol/MockERC20.json

// Create contract instances
const vault = new ethers.Contract(VAULT_ADDRESS, vaultAbi, signer);
const token = new ethers.Contract(TOKEN_ADDRESS, tokenAbi, signer);

// Deposit flow
async function deposit(amount) {
  // 1. Approve vault to spend tokens
  const approveTx = await token.approve(VAULT_ADDRESS, amount);
  await approveTx.wait();
  console.log("Approved!");

  // 2. Deposit tokens
  const depositTx = await vault.deposit(amount);
  const receipt = await depositTx.wait();
  console.log("Deposited!", receipt.hash);

  // 3. Check shares
  const shares = await vault.shares(await signer.getAddress());
  console.log("Your shares:", ethers.formatEther(shares));
}

// Withdraw flow
async function withdraw(shares) {
  const withdrawTx = await vault.withdraw(shares);
  const receipt = await withdrawTx.wait();
  console.log("Withdrawn!", receipt.hash);
}

// Check balance
async function checkBalance() {
  const address = await signer.getAddress();
  const balance = await vault.balanceOf(address);
  console.log("Vault balance:", ethers.formatEther(balance));
}

// Usage
await deposit(ethers.parseEther("100"));
await checkBalance();
await withdraw(ethers.parseEther("50"));
```

## Web3 Frontend Integration (React Example)

```jsx
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

function VaultApp() {
  const [vault, setVault] = useState(null);
  const [balance, setBalance] = useState('0');
  const [shares, setShares] = useState('0');

  useEffect(() => {
    async function init() {
      if (window.ethereum) {
        const provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = await provider.getSigner();
        
        const vaultContract = new ethers.Contract(
          VAULT_ADDRESS,
          VAULT_ABI,
          signer
        );
        
        setVault(vaultContract);
        await updateBalances(vaultContract, signer);
      }
    }
    init();
  }, []);

  async function updateBalances(vaultContract, signer) {
    const address = await signer.getAddress();
    const bal = await vaultContract.balanceOf(address);
    const shr = await vaultContract.shares(address);
    setBalance(ethers.formatEther(bal));
    setShares(ethers.formatEther(shr));
  }

  async function handleDeposit(amount) {
    const tx = await vault.deposit(ethers.parseEther(amount));
    await tx.wait();
    await updateBalances(vault, await vault.runner);
  }

  async function handleWithdraw(shares) {
    const tx = await vault.withdraw(ethers.parseEther(shares));
    await tx.wait();
    await updateBalances(vault, await vault.runner);
  }

  return (
    <div>
      <h1>Vault Dashboard</h1>
      <p>Balance: {balance} tokens</p>
      <p>Shares: {shares}</p>
      <button onClick={() => handleDeposit("100")}>Deposit 100</button>
      <button onClick={() => handleWithdraw(shares)}>Withdraw All</button>
    </div>
  );
}
```

## Common Patterns

### Batch Deposits

```javascript
async function batchDeposit(users, amounts) {
  for (let i = 0; i < users.length; i++) {
    await token.connect(users[i]).approve(vaultAddress, amounts[i]);
    await vault.connect(users[i]).deposit(amounts[i]);
  }
}
```

### Calculate Expected Shares

```javascript
async function calculateExpectedShares(depositAmount) {
  const totalShares = await vault.totalShares();
  const poolBalance = await token.balanceOf(await vault.getAddress());
  
  if (totalShares === 0n || poolBalance === 0n) {
    return depositAmount;
  }
  
  return (depositAmount * totalShares) / poolBalance;
}
```

### Monitor Events

```javascript
// Listen for deposits
vault.on("Deposited", (user, amount, shares, event) => {
  console.log(`${user} deposited ${ethers.formatEther(amount)} tokens`);
  console.log(`Received ${ethers.formatEther(shares)} shares`);
});

// Listen for withdrawals
vault.on("Withdrawn", (user, amount, shares, event) => {
  console.log(`${user} withdrew ${ethers.formatEther(amount)} tokens`);
  console.log(`Burned ${ethers.formatEther(shares)} shares`);
});
```

## Security Best Practices

1. **Always approve before deposit**: Users must approve the vault to spend their tokens
2. **Check balances**: Verify token balances before operations
3. **Handle errors**: Wrap transactions in try-catch blocks
4. **Verify addresses**: Ensure contract addresses are correct
5. **Test on testnet**: Always test on testnet before mainnet deployment
6. **Audit contracts**: Get professional audits for production use

## Troubleshooting

### Transaction Reverted

- Check token approval
- Verify sufficient balance
- Ensure vault is not paused (for VaultEnhanced)

### Share Calculation Issues

- Shares are proportional to total pool
- First depositor gets 1:1 shares
- Subsequent deposits get proportional shares

### Gas Optimization

- Batch operations when possible
- Use appropriate gas limits
- Consider gas price during network congestion

## Additional Resources

- [Hardhat Documentation](https://hardhat.org/docs)
- [Ethers.js Documentation](https://docs.ethers.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
