// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IAavePool.sol";

contract DefensifStrategy {
    IAavePool public immutable aavePool;
    address public immutable ausdc;
    address public immutable adai;
    address public immutable ausdt;

    address public immutable usdc;
    address public immutable dai;
    address public immutable usdt;
    address public immutable daoRecipient;

    uint256 public constant AUSDC_ALLOCATION = 4000;
    uint256 public constant ADAI_ALLOCATION = 3500;
    uint256 public constant AUSDT_ALLOCATION = 2500;
    uint256 public constant ALLOCATION_DENOMINATOR = 10000;

    event DepositExecuted(
        address indexed user,
        uint256 usdcAmount,
        uint256 aUSDCAmount,
        uint256 aDAIAmount,
        uint256 aUSDTAmount
    );
    event WithdrawExecuted(address indexed user, uint256 totalUSDCWithdrawn);
    event YieldClaimed(uint256 aUSDCYield, uint256 aDAIYield, uint256 aUSDTYield);

    constructor(
        address _aavePool,
        address _usdc,
        address _dai,
        address _usdt,
        address _aUSDC,
        address _aDAI,
        address _aUSDT,
        address _daoRecipient
    ) {
        require(_aavePool != address(0) &&
                _usdc != address(0) &&
                _dai != address(0) &&
                _usdt != address(0) &&
                _aUSDC != address(0) &&
                _aDAI != address(0) &&
                _aUSDT != address(0) &&
                _daoRecipient != address(0),
                "invalid address");

        aavePool = IAavePool(_aavePool);
        usdc = _usdc;
        dai = _dai;
        usdt = _usdt;
        ausdc = _aUSDC;
        adai = _aDAI;
        ausdt = _aUSDT;
        daoRecipient = _daoRecipient;
    }

    function deposit(uint256 usdcAmount) external returns (bool) {
        require(usdcAmount > 0, "Amount must be > 0");

        require(IERC20(usdc).transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        IERC20(usdc).approve(address(aavePool), usdcAmount);
        IERC20(dai).approve(address(aavePool), type(uint256).max);
        IERC20(usdt).approve(address(aavePool), type(uint256).max);

        uint256 usdcAllocation = (usdcAmount * AUSDC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 daiAllocation = (usdcAmount * ADAI_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 usdtAllocation = (usdcAmount * AUSDT_ALLOCATION) / ALLOCATION_DENOMINATOR;

        uint256 daiFromUsdc = _swapUsdcToDai(daiAllocation);
        uint256 usdtFromUsdc = _swapUsdcToUsdt(usdtAllocation);

        aavePool.deposit(usdc, usdcAllocation, address(this), 0);
        aavePool.deposit(dai, daiFromUsdc, address(this), 0);
        aavePool.deposit(usdt, usdtFromUsdc, address(this), 0);

        uint256 aUSDCBalance = IERC20(ausdc).balanceOf(address(this));
        uint256 aDAIBalance = IERC20(adai).balanceOf(address(this));
        uint256 aUSDTBalance = IERC20(ausdt).balanceOf(address(this));

        emit DepositExecuted(msg.sender, usdcAmount, aUSDCBalance, aDAIBalance, aUSDTBalance);
        return true;
    }

    function withdraw() external returns (uint256 totalUSDC) {
        uint256 aUSDCBalance = IERC20(ausdc).balanceOf(address(this));
        uint256 aDAIBalance = IERC20(adai).balanceOf(address(this));
        uint256 aUSDTBalance = IERC20(ausdt).balanceOf(address(this));

        require(aUSDCBalance > 0 || aDAIBalance > 0 || aUSDTBalance > 0, "No balance to withdraw");

        IERC20(ausdc).approve(address(aavePool), aUSDCBalance);
        IERC20(adai).approve(address(aavePool), aDAIBalance);
        IERC20(ausdt).approve(address(aavePool), aUSDTBalance);

        aavePool.withdraw(usdc, aUSDCBalance, address(this));
        aavePool.withdraw(dai, aDAIBalance, address(this));
        aavePool.withdraw(usdt, aUSDTBalance, address(this));

        uint256 daiBalance = IERC20(dai).balanceOf(address(this));
        uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));

        if (daiBalance > 0) {
            uint256 usdcFromDai = _swapDaiToUsdc(daiBalance);
            totalUSDC += usdcFromDai;
        }
        if (usdtBalance > 0) {
            uint256 usdcFromUsdt = _swapUsdtToUsdc(usdtBalance);
            totalUSDC += usdcFromUsdt;
        }

        uint256 directUsdc = IERC20(usdc).balanceOf(address(this));
        totalUSDC += directUsdc;

        require(IERC20(usdc).transfer(msg.sender, totalUSDC), "USDC transfer failed");
        emit WithdrawExecuted(msg.sender, totalUSDC);
    }

    function claimYield() external returns (uint256 usdcYield) {
        uint256 aUSDCCurrent = IERC20(ausdc).balanceOf(address(this));
        uint256 aDAICurrent = IERC20(adai).balanceOf(address(this));
        uint256 aUSDTCurrent = IERC20(ausdt).balanceOf(address(this));

        uint256 yieldAUSDC = _calculateYield(aUSDCCurrent, ausdc);
        uint256 yieldADAI = _calculateYield(aDAICurrent, adai);
        uint256 yieldAUSDT = _calculateYield(aUSDTCurrent, ausdt);

        emit YieldClaimed(yieldAUSDC, yieldADAI, yieldAUSDT);

        usdcYield = yieldAUSDC;

        if (yieldADAI > 0) {
            IERC20(adai).approve(address(aavePool), yieldADAI);
            aavePool.withdraw(dai, yieldADAI, address(this));
            uint256 daiYield = IERC20(dai).balanceOf(address(this));
            usdcYield += _swapDaiToUsdc(daiYield);
        }
        if (yieldAUSDT > 0) {
            IERC20(ausdt).approve(address(aavePool), yieldAUSDT);
            aavePool.withdraw(usdt, yieldAUSDT, address(this));
            uint256 usdtYield = IERC20(usdt).balanceOf(address(this));
            usdcYield += _swapUsdtToUsdc(usdtYield);
        }

        uint256 clientYield = (usdcYield * 80) / 100;
        uint256 daoYield = usdcYield - clientYield;

        require(IERC20(usdc).transfer(msg.sender, clientYield), "Client transfer failed");
        require(IERC20(usdc).transfer(daoRecipient, daoYield), "DAO transfer failed");
        return clientYield;
    }

    function _swapUsdcToDai(uint256 amountUsdc) internal pure returns (uint256) {
        return amountUsdc;
    }

    function _swapUsdcToUsdt(uint256 amountUsdc) internal pure returns (uint256) {
        return amountUsdc;
    }

    function _swapDaiToUsdc(uint256 amountDai) internal pure returns (uint256) {
        return amountDai;
    }

    function _swapUsdtToUsdc(uint256 amountUsdt) internal pure returns (uint256) {
        return amountUsdt;
    }

    function _calculateYield(uint256 /*currentBalance*/, address /*aToken*/)
        internal
        pure
        returns (uint256)
    {
        return 0;
    }
}
