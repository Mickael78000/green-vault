// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VaultEnhanced.sol";
import "../src/MockERC20.sol";

contract VaultEnhancedTest is Test {
    VaultEnhanced public vault;
    MockERC20 public token;
    
    address public owner;
    address public user1;
    address public user2;
    address public feeRecipient;
    
    event Deposited(address indexed user, uint256 amount, uint256 shares, uint256 fee);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares, uint256 fee);
    event FeesUpdated(uint256 depositFee, uint256 withdrawalFee);
    event FeeRecipientUpdated(address indexed newRecipient);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        feeRecipient = makeAddr("feeRecipient");
        
        // Deploy MockERC20 token
        token = new MockERC20("Test Token", "TEST", 1_000_000 ether);
        
        // Deploy VaultEnhanced
        vault = new VaultEnhanced(address(token));
        
        // Mint tokens to users for testing
        token.mint(user1, 10_000 ether);
        token.mint(user2, 10_000 ether);
    }
    
    // ============ Deployment Tests ============
    
    function test_DeploymentSetsCorrectAsset() public view {
        assertEq(address(vault.asset()), address(token));
    }
    
    function test_DeploymentSetsCorrectOwner() public view {
        assertEq(vault.owner(), owner);
    }
    
    function test_DeploymentSetsOwnerAsFeeRecipient() public view {
        assertEq(vault.feeRecipient(), owner);
    }
    
    function test_RevertWhenAssetAddressIsZero() public {
        vm.expectRevert("Invalid asset address");
        new VaultEnhanced(address(0));
    }
    
    function test_StartsWithZeroFees() public view {
        assertEq(vault.depositFee(), 0);
        assertEq(vault.withdrawalFee(), 0);
    }
    
    // ============ Fee Configuration Tests ============
    
    function test_OwnerCanSetFees() public {
        uint256 depositFee = 100; // 1%
        uint256 withdrawalFee = 50; // 0.5%
        
        vault.setFees(depositFee, withdrawalFee);
        
        assertEq(vault.depositFee(), depositFee);
        assertEq(vault.withdrawalFee(), withdrawalFee);
    }
    
    function test_EmitsFeesUpdatedEvent() public {
        uint256 depositFee = 100;
        uint256 withdrawalFee = 50;
        
        vm.expectEmit(false, false, false, true, address(vault));
        emit FeesUpdated(depositFee, withdrawalFee);
        vault.setFees(depositFee, withdrawalFee);
    }
    
    function test_RevertWhenDepositFeeTooHigh() public {
        vm.expectRevert("Deposit fee too high");
        vault.setFees(1001, 0); // Over 10%
    }
    
    function test_RevertWhenWithdrawalFeeTooHigh() public {
        vm.expectRevert("Withdrawal fee too high");
        vault.setFees(0, 1001); // Over 10%
    }
    
    function test_RevertWhenNonOwnerSetsFees() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.setFees(100, 50);
    }
    
    function test_OwnerCanSetFeeRecipient() public {
        vault.setFeeRecipient(feeRecipient);
        assertEq(vault.feeRecipient(), feeRecipient);
    }
    
    function test_EmitsFeeRecipientUpdatedEvent() public {
        vm.expectEmit(true, false, false, false, address(vault));
        emit FeeRecipientUpdated(feeRecipient);
        vault.setFeeRecipient(feeRecipient);
    }
    
    function test_RevertWhenFeeRecipientIsZero() public {
        vm.expectRevert("Invalid fee recipient");
        vault.setFeeRecipient(address(0));
    }
    
    // ============ Deposit with Fees Tests ============
    
    function test_DepositWithNoFee() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), depositAmount);
    }
    
    function test_DepositWithFee() public {
        uint256 depositAmount = 100 ether;
        uint256 depositFee = 100; // 1%
        
        vault.setFees(depositFee, 0);
        vault.setFeeRecipient(feeRecipient);
        
        uint256 expectedFee = (depositAmount * depositFee) / 10000;
        uint256 expectedShares = depositAmount - expectedFee;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        assertEq(vault.shares(user1), expectedShares);
        assertEq(token.balanceOf(feeRecipient), expectedFee);
    }
    
    function test_EmitsDepositedEventWithFee() public {
        uint256 depositAmount = 100 ether;
        uint256 depositFee = 100; // 1%
        
        vault.setFees(depositFee, 0);
        vault.setFeeRecipient(feeRecipient);
        
        uint256 expectedFee = (depositAmount * depositFee) / 10000;
        uint256 amountAfterFee = depositAmount - expectedFee;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        
        vm.expectEmit(true, false, false, true, address(vault));
        emit Deposited(user1, amountAfterFee, amountAfterFee, expectedFee);
        vault.deposit(depositAmount);
        vm.stopPrank();
    }
    
    // ============ Withdrawal with Fees Tests ============
    
    function test_WithdrawWithNoFee() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        uint256 balanceBefore = token.balanceOf(user1);
        
        vault.withdraw(userShares);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1) - balanceBefore, depositAmount);
    }
    
    function test_WithdrawWithFee() public {
        uint256 depositAmount = 100 ether;
        uint256 withdrawalFee = 50; // 0.5%
        
        vault.setFees(0, withdrawalFee);
        vault.setFeeRecipient(feeRecipient);
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        uint256 balanceBefore = token.balanceOf(user1);
        
        vault.withdraw(userShares);
        vm.stopPrank();
        
        uint256 expectedFee = (depositAmount * withdrawalFee) / 10000;
        uint256 expectedAmount = depositAmount - expectedFee;
        
        assertEq(token.balanceOf(user1) - balanceBefore, expectedAmount);
        assertEq(token.balanceOf(feeRecipient), expectedFee);
    }
    
    // ============ Pausability Tests ============
    
    function test_OwnerCanPauseVault() public {
        vault.pause();
        assertTrue(vault.paused());
    }
    
    function test_OwnerCanUnpauseVault() public {
        vault.pause();
        vault.unpause();
        assertFalse(vault.paused());
    }
    
    function test_RevertWhenNonOwnerPauses() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.pause();
    }
    
    function test_RevertWhenDepositingWhilePaused() public {
        vault.pause();
        
        vm.startPrank(user1);
        token.approve(address(vault), 100 ether);
        vm.expectRevert();
        vault.deposit(100 ether);
        vm.stopPrank();
    }
    
    function test_RevertWhenWithdrawingWhilePaused() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        vm.stopPrank();
        
        vault.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        vault.withdraw(userShares);
    }
    
    // ============ Emergency Withdrawal Tests ============
    
    function test_EmergencyWithdrawWorksWhenPaused() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        vault.pause();
        
        uint256 userShares = vault.shares(user1);
        uint256 balanceBefore = token.balanceOf(user1);
        
        vm.prank(user1);
        vault.emergencyWithdraw(userShares);
        
        assertEq(token.balanceOf(user1) - balanceBefore, depositAmount);
        assertEq(vault.shares(user1), 0);
    }
    
    function test_EmergencyWithdrawNoFees() public {
        uint256 depositAmount = 100 ether;
        
        vault.setFees(0, 100); // Set withdrawal fee
        vault.setFeeRecipient(feeRecipient);
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        uint256 balanceBefore = token.balanceOf(user1);
        
        vault.emergencyWithdraw(userShares);
        vm.stopPrank();
        
        // Should receive full amount without fees
        assertEq(token.balanceOf(user1) - balanceBefore, depositAmount);
        assertEq(token.balanceOf(feeRecipient), 0);
    }
    
    function test_EmitsEmergencyWithdrawalEvent() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.shares(user1);
        
        vm.expectEmit(true, false, false, true, address(vault));
        emit EmergencyWithdrawal(user1, depositAmount);
        vault.emergencyWithdraw(userShares);
        vm.stopPrank();
    }
    
    // ============ Statistics Tests ============
    
    function test_GetStatsReturnsCorrectValues() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        (
            uint256 totalShares,
            uint256 totalDeposited,
            uint256 totalWithdrawn,
            uint256 currentBalance
        ) = vault.getStats();
        
        assertEq(totalShares, depositAmount);
        assertEq(totalDeposited, depositAmount);
        assertEq(totalWithdrawn, 0);
        assertEq(currentBalance, depositAmount);
    }
    
    function test_TotalValueLockedReturnsCorrectAmount() public {
        uint256 depositAmount = 100 ether;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        assertEq(vault.totalValueLocked(), depositAmount);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_DepositWithVariableFees(uint256 amount, uint256 fee) public {
        amount = bound(amount, 1 ether, 10_000 ether);
        fee = bound(fee, 0, 1000); // Max 10%
        
        vault.setFees(fee, 0);
        vault.setFeeRecipient(feeRecipient);
        
        vm.startPrank(user1);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
        
        uint256 expectedFee = (amount * fee) / 10000;
        uint256 expectedShares = amount - expectedFee;
        
        assertEq(vault.shares(user1), expectedShares);
        assertEq(token.balanceOf(feeRecipient), expectedFee);
    }
    
    function testFuzz_WithdrawWithVariableFees(uint256 amount, uint256 fee) public {
        amount = bound(amount, 1 ether, 10_000 ether);
        fee = bound(fee, 0, 1000); // Max 10%
        
        vault.setFees(0, fee);
        vault.setFeeRecipient(feeRecipient);
        
        vm.startPrank(user1);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        
        uint256 userShares = vault.shares(user1);
        uint256 balanceBefore = token.balanceOf(user1);
        
        vault.withdraw(userShares);
        vm.stopPrank();
        
        uint256 expectedFee = (amount * fee) / 10000;
        uint256 expectedAmount = amount - expectedFee;
        
        assertApproxEqAbs(token.balanceOf(user1) - balanceBefore, expectedAmount, 1);
        assertApproxEqAbs(token.balanceOf(feeRecipient), expectedFee, 1);
    }
}
