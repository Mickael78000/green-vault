// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Vault
 * @dev A simple vault that allows users to deposit ERC20 tokens and withdraw them later.
 * Users receive shares proportional to their deposit amount.
 */
contract Vault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);

    /**
     * @dev Sets the underlying asset the Vault will use.
     * @param _asset The ERC20 token contract address
     */
    constructor(address _asset) Ownable(msg.sender) {
        require(_asset != address(0), "Invalid asset address");
        asset = IERC20(_asset);
    }

    /**
     * @dev Deposit tokens into the vault and mint shares to the sender.
     * @param amount The amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot deposit 0");
        
        uint256 _shares;
        uint256 _pool = asset.balanceOf(address(this));
        
        if (totalShares == 0 || _pool == 0) {
            _shares = amount;
        } else {
            _shares = (amount * totalShares) / _pool;
        }
        
        asset.safeTransferFrom(msg.sender, address(this), amount);
        shares[msg.sender] += _shares;
        totalShares += _shares;
        
        emit Deposited(msg.sender, amount, _shares);
    }

    /**
     * @dev Withdraw tokens from the vault by burning shares.
     * @param _shares The number of shares to burn
     */
    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "Cannot withdraw 0 shares");
        require(shares[msg.sender] >= _shares, "Insufficient shares");
        
        uint256 amount = (_shares * asset.balanceOf(address(this))) / totalShares;
        
        shares[msg.sender] -= _shares;
        totalShares -= _shares;
        
        asset.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, _shares);
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
}
