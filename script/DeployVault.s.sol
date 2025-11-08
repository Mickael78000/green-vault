// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Vault.sol";
import "../src/VaultEnhanced.sol";
import "../src/MockERC20.sol";

contract DeployVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MockERC20 for testing (only for testnets/local)
        MockERC20 token = new MockERC20("Test Token", "TEST", 1_000_000 ether);
        console.log("MockERC20 deployed at:", address(token));
        
        // Deploy basic Vault
        Vault vault = new Vault(address(token));
        console.log("Vault deployed at:", address(vault));
        
        // Deploy VaultEnhanced
        VaultEnhanced vaultEnhanced = new VaultEnhanced(address(token));
        console.log("VaultEnhanced deployed at:", address(vaultEnhanced));
        
        vm.stopBroadcast();
        
        console.log("\nDeployment Summary:");
        console.log("===================");
        console.log("Token:", address(token));
        console.log("Vault:", address(vault));
        console.log("VaultEnhanced:", address(vaultEnhanced));
    }
}

contract DeployVaultWithToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        
        console.log("Deploying Vault with existing token");
        console.log("Deployer:", deployer);
        console.log("Token:", tokenAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy basic Vault with existing token
        Vault vault = new Vault(tokenAddress);
        console.log("Vault deployed at:", address(vault));
        
        vm.stopBroadcast();
    }
}

contract DeployVaultEnhancedWithToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        
        console.log("Deploying VaultEnhanced with existing token");
        console.log("Deployer:", deployer);
        console.log("Token:", tokenAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy VaultEnhanced with existing token
        VaultEnhanced vaultEnhanced = new VaultEnhanced(tokenAddress);
        console.log("VaultEnhanced deployed at:", address(vaultEnhanced));
        
        vm.stopBroadcast();
    }
}
