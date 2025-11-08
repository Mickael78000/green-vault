// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Vault.sol";
import "../src/VaultEnhanced.sol";
import "../src/MockERC20.sol";

contract InteractVault is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        
        Vault vault = Vault(vaultAddress);
        MockERC20 token = MockERC20(tokenAddress);
        
        console.log("Interacting with Vault");
        console.log("User:", user);
        console.log("Vault:", vaultAddress);
        console.log("Token:", tokenAddress);
        
        vm.startBroadcast(userPrivateKey);
        
        // Check balances
        uint256 tokenBalance = token.balanceOf(user);
        uint256 vaultBalance = vault.balanceOf(user);
        uint256 userShares = vault.shares(user);
        
        console.log("\nCurrent State:");
        console.log("Token Balance:", tokenBalance);
        console.log("Vault Balance:", vaultBalance);
        console.log("User Shares:", userShares);
        console.log("Total Shares:", vault.totalShares());
        
        // Example: Deposit 100 tokens
        uint256 depositAmount = 100 ether;
        if (tokenBalance >= depositAmount) {
            console.log("\nDepositing", depositAmount, "tokens...");
            token.approve(vaultAddress, depositAmount);
            vault.deposit(depositAmount);
            console.log("Deposit successful!");
            
            console.log("New shares:", vault.shares(user));
            console.log("New vault balance:", vault.balanceOf(user));
        } else {
            console.log("\nInsufficient token balance for deposit");
        }
        
        vm.stopBroadcast();
    }
}

contract InteractVaultEnhanced is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        
        VaultEnhanced vault = VaultEnhanced(vaultAddress);
        MockERC20 token = MockERC20(tokenAddress);
        
        console.log("Interacting with VaultEnhanced");
        console.log("User:", user);
        console.log("Vault:", vaultAddress);
        console.log("Token:", tokenAddress);
        
        vm.startBroadcast(userPrivateKey);
        
        // Check balances and stats
        uint256 tokenBalance = token.balanceOf(user);
        uint256 vaultBalance = vault.balanceOf(user);
        uint256 userShares = vault.shares(user);
        
        (
            uint256 totalShares,
            uint256 totalDeposited,
            uint256 totalWithdrawn,
            uint256 currentBalance
        ) = vault.getStats();
        
        console.log("\nCurrent State:");
        console.log("Token Balance:", tokenBalance);
        console.log("Vault Balance:", vaultBalance);
        console.log("User Shares:", userShares);
        console.log("\nVault Stats:");
        console.log("Total Shares:", totalShares);
        console.log("Total Deposited:", totalDeposited);
        console.log("Total Withdrawn:", totalWithdrawn);
        console.log("Current Balance:", currentBalance);
        console.log("TVL:", vault.totalValueLocked());
        console.log("Deposit Fee:", vault.depositFee(), "bps");
        console.log("Withdrawal Fee:", vault.withdrawalFee(), "bps");
        console.log("Paused:", vault.paused());
        
        vm.stopBroadcast();
    }
}
