// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title VaultEnhanced
 * @dev Enhanced vault with fees, pausability, and emergency withdrawal
 */
contract VaultEnhanced is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    // Fee configuration (in basis points, 100 = 1%)
    uint256 public depositFee = 0; // Default 0%
    uint256 public withdrawalFee = 0; // Default 0%
    uint256 public constant MAX_FEE = 1000; // Max 10%
    address public feeRecipient;

    // Performance tracking
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;

    event Deposited(address indexed user, uint256 amount, uint256 shares, uint256 fee);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares, uint256 fee);
    event FeesUpdated(uint256 depositFee, uint256 withdrawalFee);
    event FeeRecipientUpdated(address indexed newRecipient);
    event EmergencyWithdrawal(address indexed user, uint256 amount);

    /**
     * @dev Sets the underlying asset the Vault will use.
     * @param _asset The ERC20 token contract address
     */
    constructor(address _asset) Ownable(msg.sender) {
        require(_asset != address(0), "Invalid asset address");
        asset = IERC20(_asset);
        feeRecipient = msg.sender;
    }

    /**
     * @dev Deposit tokens into the vault and mint shares to the sender.
     * @param amount The amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot deposit 0");
        
        // Calculate fee
        uint256 fee = (amount * depositFee) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        // Calculate shares based on amount after fee
        uint256 _shares;
        uint256 _pool = asset.balanceOf(address(this));
        
        if (totalShares == 0 || _pool == 0) {
            _shares = amountAfterFee;
        } else {
            _shares = (amountAfterFee * totalShares) / _pool;
        }
        
        // Transfer tokens
        asset.safeTransferFrom(msg.sender, address(this), amount);
        
        // Transfer fee if applicable
        if (fee > 0 && feeRecipient != address(0)) {
            asset.safeTransfer(feeRecipient, fee);
        }
        
        // Update state
        shares[msg.sender] += _shares;
        totalShares += _shares;
        totalDeposited += amountAfterFee;
        
        emit Deposited(msg.sender, amountAfterFee, _shares, fee);
    }

    /**
     * @dev Withdraw tokens from the vault by burning shares.
     * @param _shares The number of shares to burn
     */
    function withdraw(uint256 _shares) external nonReentrant whenNotPaused {
        require(_shares > 0, "Cannot withdraw 0 shares");
        require(shares[msg.sender] >= _shares, "Insufficient shares");
        
        // Calculate withdrawal amount
        uint256 amount = (_shares * asset.balanceOf(address(this))) / totalShares;
        
        // Calculate fee
        uint256 fee = (amount * withdrawalFee) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        // Update state
        shares[msg.sender] -= _shares;
        totalShares -= _shares;
        totalWithdrawn += amountAfterFee;
        
        // Transfer fee if applicable
        if (fee > 0 && feeRecipient != address(0)) {
            asset.safeTransfer(feeRecipient, fee);
        }
        
        // Transfer tokens to user
        asset.safeTransfer(msg.sender, amountAfterFee);
        
        emit Withdrawn(msg.sender, amountAfterFee, _shares, fee);
    }

    /**
     * @dev Emergency withdrawal - allows users to withdraw even when paused
     * No fees applied during emergency withdrawal
     * @param _shares The number of shares to burn
     */
    function emergencyWithdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "Cannot withdraw 0 shares");
        require(shares[msg.sender] >= _shares, "Insufficient shares");
        
        uint256 amount = (_shares * asset.balanceOf(address(this))) / totalShares;
        
        shares[msg.sender] -= _shares;
        totalShares -= _shares;
        
        asset.safeTransfer(msg.sender, amount);
        
        emit EmergencyWithdrawal(msg.sender, amount);
    }

    /**
     * @dev Get the underlying token balance of a user based on their shares.
     * @param user The address of the user
     * @return The estimated token balance
     */
    function balanceOf(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares[user] * asset.balanceOf(address(this))) / totalShares;
    }

    /**
     * @dev Get the total value locked in the vault
     * @return The total amount of tokens in the vault
     */
    function totalValueLocked() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @dev Set deposit and withdrawal fees (only owner)
     * @param _depositFee The new deposit fee in basis points
     * @param _withdrawalFee The new withdrawal fee in basis points
     */
    function setFees(uint256 _depositFee, uint256 _withdrawalFee) external onlyOwner {
        require(_depositFee <= MAX_FEE, "Deposit fee too high");
        require(_withdrawalFee <= MAX_FEE, "Withdrawal fee too high");
        
        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
        
        emit FeesUpdated(_depositFee, _withdrawalFee);
    }

    /**
     * @dev Set the fee recipient address (only owner)
     * @param _feeRecipient The new fee recipient address
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
        
        emit FeeRecipientUpdated(_feeRecipient);
    }

    /**
     * @dev Pause the vault (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the vault (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get vault statistics
     * @return _totalShares Total shares in circulation
     * @return _totalDeposited Total amount deposited (excluding fees)
     * @return _totalWithdrawn Total amount withdrawn (excluding fees)
     * @return _currentBalance Current token balance in vault
     */
    function getStats() external view returns (
        uint256 _totalShares,
        uint256 _totalDeposited,
        uint256 _totalWithdrawn,
        uint256 _currentBalance
    ) {
        return (
            totalShares,
            totalDeposited,
            totalWithdrawn,
            asset.balanceOf(address(this))
        );
    }
}
