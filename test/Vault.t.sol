// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/MockERC20.sol";

contract VaultTest is Test {
    Vault public vault;
    MockERC20 public token;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // Deploy MockERC20 token
        token = new MockERC20("Test Token", "TEST", 1_000_000 ether);
        
        // Deploy Vault
        vault = new Vault(address(token));
        
        // Mint tokens to users for testing
        token.mint(user1, 10_000 ether);
        token.mint(user2, 10_000 ether);
        token.mint(user3, 10_000 ether);
    }
    
    // ============ Deployment Tests ============
    
    function test_DeploymentSetsCorrectAsset() public view {
        assertEq(address(vault.asset()), address(token));
    }
    
    function test_DeploymentSetsCorrectOwner() public view {
        assertEq(vault.owner(), owner);
    }
    
    function test_RevertWhenAssetAddressIsZero() public {
        vm.expectRevert("Invalid asset address");
        new Vault(address(0));
    }
    
    function test_StartsWithZeroTotalShares() public view {
        assertEq(vault.totalShares(), 0);
    }
    
    // ============ Deposit Tests ============
    
    function test_AllowsUsersToDepositTokens() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), depositAmount);
        assertEq(vault.totalShares(), depositAmount);
    }
    
    function test_EmitsDepositedEvent() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        
        vm.expectEmit(true, false, false, true, address(vault));
        emit Deposited(user1, depositAmount, depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
    }
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    
    function test_RevertWhenDepositingZeroTokens() public {
        vm.prank(user1);
        vm.expectRevert("Cannot deposit 0");
        vault.deposit(0);
    }
    
    function test_CalculatesSharesCorrectlyForMultipleDeposits() public {
        uint256 firstDeposit = 100 ether;
        uint256 secondDeposit = 100 ether;
        
        // First deposit
        vm.startPrank(user1);
        token.approve(address(vault), firstDeposit);
        vault.deposit(firstDeposit);
        vm.stopPrank();
        
        // Second deposit
        vm.startPrank(user2);
        token.approve(address(vault), secondDeposit);
        vault.deposit(secondDeposit);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), firstDeposit);
        assertEq(vault.shares(user2), secondDeposit);
        assertEq(vault.totalShares(), firstDeposit + secondDeposit);
    }
    
    function test_HandlesMultipleDepositsFromSameUser() public {
        uint256 firstDeposit = 100 ether;
        uint256 secondDeposit = 50 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), firstDeposit);
        vault.deposit(firstDeposit);
        
        token.approve(address(vault), secondDeposit);
        vault.deposit(secondDeposit);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), firstDeposit + secondDeposit);
    }
    
    // ============ Withdrawal Tests ============
    
    function test_AllowsUsersToWithdrawTokens() public {
        uint256 depositAmount = 100 ether;
        
        // Deposit
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 initialBalance = token.balanceOf(user1);
        uint256 userShares = vault.shares(user1);
        
        // Withdraw
        vault.withdraw(userShares);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), 0);
        assertEq(vault.totalShares(), 0);
        assertEq(token.balanceOf(user1), initialBalance + depositAmount);
    }
    
    function test_EmitsWithdrawnEvent() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        
        vm.expectEmit(true, false, false, true, address(vault));
        emit Withdrawn(user1, depositAmount, userShares);
        vault.withdraw(userShares);
        vm.stopPrank();
    }
    
    function test_RevertWhenWithdrawingZeroShares() public {
        vm.prank(user1);
        vm.expectRevert("Cannot withdraw 0 shares");
        vault.withdraw(0);
    }
    
    function test_RevertWhenWithdrawingMoreSharesThanOwned() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        
        vm.expectRevert("Insufficient shares");
        vault.withdraw(userShares + 1);
        vm.stopPrank();
    }
    
    function test_AllowsPartialWithdrawals() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        uint256 withdrawShares = userShares / 2;
        
        vault.withdraw(withdrawShares);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), userShares - withdrawShares);
    }
    
    function test_DistributesTokensProportionallyWhenMultipleUsersWithdraw() public {
        uint256 depositAmount = 100 ether;
        
        // Both users deposit same amount
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        uint256 user1Shares = vault.shares(user1);
        uint256 user2Shares = vault.shares(user2);
        
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        
        // Both withdraw all shares
        vm.prank(user1);
        vault.withdraw(user1Shares);
        
        vm.prank(user2);
        vault.withdraw(user2Shares);
        
        uint256 user1BalanceAfter = token.balanceOf(user1);
        uint256 user2BalanceAfter = token.balanceOf(user2);
        
        // Both should receive same amount
        assertEq(user1BalanceAfter - user1BalanceBefore, depositAmount);
        assertEq(user2BalanceAfter - user2BalanceBefore, depositAmount);
    }
    
    // ============ Balance View Tests ============
    
    function test_ReturnsCorrectBalanceForUser() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), depositAmount);
    }
    
    function test_ReturnsZeroForUsersWithNoShares() public view {
        assertEq(vault.balanceOf(user1), 0);
    }
    
    function test_ReturnsZeroWhenTotalSharesIsZero() public view {
        assertEq(vault.balanceOf(user1), 0);
        assertEq(vault.totalShares(), 0);
    }
    
    function test_ReflectsProportionalBalanceForMultipleUsers() public {
        uint256 deposit1 = 100 ether;
        uint256 deposit2 = 200 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), deposit1);
        vault.deposit(deposit1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(vault), deposit2);
        vault.deposit(deposit2);
        vm.stopPrank();
        
        assertApproxEqAbs(vault.balanceOf(user1), deposit1, 0.01 ether);
        assertApproxEqAbs(vault.balanceOf(user2), deposit2, 0.01 ether);
    }
    
    // ============ Security Tests ============
    
    function test_HandlesEdgeCaseOfDepositingAfterAllWithdrawals() public {
        uint256 deposit1 = 100 ether;
        uint256 deposit2 = 200 ether;
        
        // First user deposits and withdraws
        vm.startPrank(user1);
        token.approve(address(vault), deposit1);
        vault.deposit(deposit1);
        
        uint256 shares1 = vault.shares(user1);
        vault.withdraw(shares1);
        vm.stopPrank();
        
        // Second user deposits after vault is empty
        vm.startPrank(user2);
        token.approve(address(vault), deposit2);
        vault.deposit(deposit2);
        vm.stopPrank();
        
        assertEq(vault.shares(user2), deposit2);
        assertEq(vault.totalShares(), deposit2);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_DepositAndWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 10_000 ether);
        
        vm.startPrank(user1);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        
        uint256 userShares = vault.shares(user1);
        vault.withdraw(userShares);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), 0);
        assertEq(vault.totalShares(), 0);
    }
    
    function testFuzz_MultipleDeposits(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 > 0 && amount1 <= 5_000 ether);
        vm.assume(amount2 > 0 && amount2 <= 5_000 ether);
        
        vm.startPrank(user1);
        token.approve(address(vault), amount1);
        vault.deposit(amount1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(vault), amount2);
        vault.deposit(amount2);
        vm.stopPrank();
        
        assertGt(vault.totalShares(), 0);
        assertGt(vault.shares(user1), 0);
        assertGt(vault.shares(user2), 0);
    }
}
