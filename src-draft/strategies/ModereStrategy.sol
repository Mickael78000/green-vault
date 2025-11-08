// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IAavePool.sol";

contract ModereStrategy {
    IAavePool public immutable aavePool;

    address public immutable usdc;
    address public immutable dai;
    address public immutable weth;
    address public immutable wbtc;

    address public immutable ausdc;
    address public immutable adai;
    address public immutable aweth;
    address public immutable awbtc;

    address public immutable daoRecipient;

    uint256 public constant AUSDC_ALLOCATION = 3000;  // 30%
    uint256 public constant ADAI_ALLOCATION = 2000;   // 20%
    uint256 public constant AWETH_ALLOCATION = 3000;  // 30%
    uint256 public constant AWBTC_ALLOCATION = 2000;  // 20%
    uint256 public constant ALLOCATION_DENOMINATOR = 10000;

    struct DepositInfo {
        uint256 initialUsdcAmount;
        uint256 depositTimestamp;
        uint256 initialAUSDC;
        uint256 initialADAI;
        uint256 initialAWETH;
        uint256 initialAWBTC;
    }

    mapping(address => DepositInfo) public userDeposits;

    event DepositExecuted(address indexed user, uint256 usdcAmount, uint256 timestamp);
    event YieldClaimed(address indexed user, uint256 clientYield, uint256 daoYield);
    event Rebalanced(uint256 newAWETHAmount, uint256 newAWBTCAmount, uint256 timestamp);

    constructor(
        address _aavePool,
        address _usdc,
        address _dai,
        address _weth,
        address _wbtc,
        address _aUSDC,
        address _aDAI,
        address _aWETH,
        address _aWBTC,
        address _daoRecipient
    ) {
        require(
            _aavePool != address(0) &&
            _usdc != address(0) &&
            _dai != address(0) &&
            _weth != address(0) &&
            _wbtc != address(0) &&
            _aUSDC != address(0) &&
            _aDAI != address(0) &&
            _aWETH != address(0) &&
            _aWBTC != address(0) &&
            _daoRecipient != address(0),
            "invalid address"
        );
        aavePool = IAavePool(_aavePool);
        usdc = _usdc;
        dai = _dai;
        weth = _weth;
        wbtc = _wbtc;
        ausdc = _aUSDC;
        adai = _aDAI;
        aweth = _aWETH;
        awbtc = _aWBTC;
        daoRecipient = _daoRecipient;
    }

    function deposit(uint256 usdcAmount) external returns (bool) {
        require(usdcAmount > 0, "Amount must be > 0");

        require(IERC20(usdc).transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");

        _approveAllTokens();

        uint256 ausdcAmt = (usdcAmount * AUSDC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 adaiAmt = (usdcAmount * ADAI_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 awethAmt = (usdcAmount * AWETH_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 awbtcAmt = (usdcAmount * AWBTC_ALLOCATION) / ALLOCATION_DENOMINATOR;

        uint256 daiAmount = _swapUsdcToDai(adaiAmt);
        uint256 wethAmount = _swapUsdcToWeth(awethAmt);
        uint256 wbtcAmount = _swapUsdcToWbtc(awbtcAmt);

        aavePool.deposit(usdc, ausdcAmt, address(this), 0);
        aavePool.deposit(dai, daiAmount, address(this), 0);
        aavePool.deposit(weth, wethAmount, address(this), 0);
        aavePool.deposit(wbtc, wbtcAmount, address(this), 0);

        userDeposits[msg.sender] = DepositInfo({
            initialUsdcAmount: usdcAmount,
            depositTimestamp: block.timestamp,
            initialAUSDC: IERC20(ausdc).balanceOf(address(this)),
            initialADAI: IERC20(adai).balanceOf(address(this)),
            initialAWETH: IERC20(aweth).balanceOf(address(this)),
            initialAWBTC: IERC20(awbtc).balanceOf(address(this))
        });

        emit DepositExecuted(msg.sender, usdcAmount, block.timestamp);
        return true;
    }

    function rebalanceMonthly() external returns (bool) {
        // placeholder: restrict to a periodic window in production
        uint256 totalValue = getTotalPortfolioValue();
        uint256 targetAWETH = (totalValue * AWETH_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 targetAWBTC = (totalValue * AWBTC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        emit Rebalanced(targetAWETH, targetAWBTC, block.timestamp);
        return true;
    }

    function withdraw() external returns (uint256 totalUSDC) {
        uint256 aUSDCBalance = IERC20(ausdc).balanceOf(address(this));
        uint256 aDAIBalance = IERC20(adai).balanceOf(address(this));
        uint256 aWETHBalance = IERC20(aweth).balanceOf(address(this));
        uint256 aWBTCBalance = IERC20(awbtc).balanceOf(address(this));
        require(
            aUSDCBalance > 0 || aDAIBalance > 0 || aWETHBalance > 0 || aWBTCBalance > 0,
            "No balance to withdraw"
        );

        _approveAllTokens();

        aavePool.withdraw(usdc, aUSDCBalance, address(this));
        aavePool.withdraw(dai, aDAIBalance, address(this));
        aavePool.withdraw(weth, aWETHBalance, address(this));
        aavePool.withdraw(wbtc, aWBTCBalance, address(this));

        totalUSDC = IERC20(usdc).balanceOf(address(this));
        if (IERC20(dai).balanceOf(address(this)) > 0) {
            totalUSDC += _swapDaiToUsdc(IERC20(dai).balanceOf(address(this)));
        }
        if (IERC20(weth).balanceOf(address(this)) > 0) {
            totalUSDC += _swapWethToUsdc(IERC20(weth).balanceOf(address(this)));
        }
        if (IERC20(wbtc).balanceOf(address(this)) > 0) {
            totalUSDC += _swapWbtcToUsdc(IERC20(wbtc).balanceOf(address(this)));
        }

        require(IERC20(usdc).transfer(msg.sender, totalUSDC), "Transfer failed");
        return totalUSDC;
    }

    function claimYield() external returns (uint256 clientYield) {
        // Placeholder: compute based on current - initial
        uint256 currentTotalValue = getTotalPortfolioValue();
        uint256 initialInvestment = userDeposits[msg.sender].initialUsdcAmount;
        uint256 grossYield = currentTotalValue > initialInvestment ? currentTotalValue - initialInvestment : 0;
        require(grossYield > 0, "No yield to claim");

        clientYield = (grossYield * 80) / 100;
        uint256 daoYield = grossYield - clientYield;

        uint256 usdcToTransfer = _convertToUsdc(clientYield);
        require(IERC20(usdc).transfer(msg.sender, usdcToTransfer), "Client transfer failed");
        require(IERC20(usdc).transfer(daoRecipient, daoYield), "DAO transfer failed");
        emit YieldClaimed(msg.sender, usdcToTransfer, daoYield);
        return usdcToTransfer;
    }

    function getTotalPortfolioValue() public view returns (uint256) {
        uint256 aUSDCValue = IERC20(ausdc).balanceOf(address(this));
        uint256 aDAIValue = _convertToUsdc(IERC20(adai).balanceOf(address(this)));
        uint256 aWETHValue = _getWethPriceInUsdc(IERC20(aweth).balanceOf(address(this)));
        uint256 aWBTCValue = _getWbtcPriceInUsdc(IERC20(awbtc).balanceOf(address(this)));
        return aUSDCValue + aDAIValue + aWETHValue + aWBTCValue;
    }

    function _approveAllTokens() internal {
        IERC20(usdc).approve(address(aavePool), type(uint256).max);
        IERC20(dai).approve(address(aavePool), type(uint256).max);
        IERC20(weth).approve(address(aavePool), type(uint256).max);
        IERC20(wbtc).approve(address(aavePool), type(uint256).max);
        IERC20(ausdc).approve(address(aavePool), type(uint256).max);
        IERC20(adai).approve(address(aavePool), type(uint256).max);
        IERC20(aweth).approve(address(aavePool), type(uint256).max);
        IERC20(awbtc).approve(address(aavePool), type(uint256).max);
    }

    function _swapUsdcToDai(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapUsdcToWeth(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapUsdcToWbtc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapDaiToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapWethToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapWbtcToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _convertToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _getWethPriceInUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _getWbtcPriceInUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
}
