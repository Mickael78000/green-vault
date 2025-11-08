// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IAavePool.sol";

contract DynamiqueStrategy {
    IAavePool public immutable aavePool;

    address public immutable usdc;
    address public immutable weth;
    address public immutable wbtc;
    address public immutable link;

    address public immutable ausdc;
    address public immutable aweth;
    address public immutable awbtc;
    address public immutable alink;

    address public immutable daoRecipient;

    uint256 public constant AUSDC_ALLOCATION = 2000;  // 20%
    uint256 public constant AWETH_ALLOCATION = 4000;  // 40%
    uint256 public constant AWBTC_ALLOCATION = 2500;  // 25%
    uint256 public constant ALINK_ALLOCATION = 1500;  // 15%
    uint256 public constant ALLOCATION_DENOMINATOR = 10000;

    uint256 public rebalanceIntervalDays = 7;
    uint256 public lastRebalanceTimestamp;
    bool public autoCompound = true;

    struct UserPosition {
        uint256 initialUsdcDeposit;
        uint256 depositTimestamp;
        uint256 cumulativeYield;
        bool isActive;
    }

    mapping(address => UserPosition) public userPositions;

    event DepositExecuted(address indexed user, uint256 usdcAmount, uint256 timestamp);
    event YieldClaimed(address indexed user, uint256 grossYield, uint256 clientYield, uint256 daoYield);
    event RebalancedDynamic(uint256 timestamp, string reason);
    event CompoundingExecuted(uint256 aaveRewardsReinvested);
    event WeeklyRebalance(uint256 newWethAllocation, uint256 newWbtcAllocation, uint256 newLinkAllocation, uint256 timestamp);

    constructor(
        address _aavePool,
        address _usdc,
        address _weth,
        address _wbtc,
        address _link,
        address _aUSDC,
        address _aWETH,
        address _aWBTC,
        address _aLINK,
        address _daoRecipient
    ) {
        require(
            _aavePool != address(0) &&
            _usdc != address(0) &&
            _weth != address(0) &&
            _wbtc != address(0) &&
            _link != address(0) &&
            _aUSDC != address(0) &&
            _aWETH != address(0) &&
            _aWBTC != address(0) &&
            _aLINK != address(0) &&
            _daoRecipient != address(0),
            "invalid address"
        );
        aavePool = IAavePool(_aavePool);
        usdc = _usdc;
        weth = _weth;
        wbtc = _wbtc;
        link = _link;
        ausdc = _aUSDC;
        aweth = _aWETH;
        awbtc = _aWBTC;
        alink = _aLINK;
        daoRecipient = _daoRecipient;
    }

    function deposit(uint256 usdcAmount) external returns (bool) {
        require(usdcAmount > 0, "Amount must be > 0");
        require(!userPositions[msg.sender].isActive, "User already has active position");

        require(IERC20(usdc).transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        _approveAllTokens();

        uint256 ausdcAmt = (usdcAmount * AUSDC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 awethAmt = (usdcAmount * AWETH_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 awbtcAmt = (usdcAmount * AWBTC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 alinkAmt = (usdcAmount * ALINK_ALLOCATION) / ALLOCATION_DENOMINATOR;

        uint256 wethAmount = _swapUsdcToWeth(awethAmt);
        uint256 wbtcAmount = _swapUsdcToWbtc(awbtcAmt);
        uint256 linkAmount = _swapUsdcToLink(alinkAmt);

        aavePool.deposit(usdc, ausdcAmt, address(this), 0);
        aavePool.deposit(weth, wethAmount, address(this), 0);
        aavePool.deposit(wbtc, wbtcAmount, address(this), 0);
        aavePool.deposit(link, linkAmount, address(this), 0);

        userPositions[msg.sender] = UserPosition({
            initialUsdcDeposit: usdcAmount,
            depositTimestamp: block.timestamp,
            cumulativeYield: 0,
            isActive: true
        });

        emit DepositExecuted(msg.sender, usdcAmount, block.timestamp);
        return true;
    }

    function rebalanceWeekly() external returns (bool) {
        require(block.timestamp >= lastRebalanceTimestamp + (rebalanceIntervalDays * 1 days), "Not yet time to rebalance");
        (uint256 wethApy, uint256 wbtcApy, uint256 linkApy) = _getAaveApys();

        uint256 newWethAlloc = _calculateOptimalAllocation(wethApy);
        uint256 newWbtcAlloc = _calculateOptimalAllocation(wbtcApy);
        uint256 newLinkAlloc = ALINK_ALLOCATION; // Stable for diversification

        // silence unused var (kept for parity with guide)
        linkApy;
        _rebalancePositions(newWethAlloc, newWbtcAlloc, newLinkAlloc);
        lastRebalanceTimestamp = block.timestamp;
        emit WeeklyRebalance(newWethAlloc, newWbtcAlloc, newLinkAlloc, block.timestamp);
        return true;
    }

    function executeCompounding() external returns (uint256 aaveReinvested) {
        require(autoCompound, "Auto-compounding disabled");
        // Placeholder for staking and reinvesting rewards
        uint256 rewards = _claimPoolRewards();
        if (rewards > 0) {
            uint256 usdcFromRewards = _swapToUsdc(rewards);
            _reallocateRewards(usdcFromRewards);
            aaveReinvested = rewards;
        }
        emit CompoundingExecuted(aaveReinvested);
        return aaveReinvested;
    }

    function withdraw() external returns (uint256 totalUSDC) {
        require(userPositions[msg.sender].isActive, "No active position");

        uint256 aUSDCBalance = IERC20(ausdc).balanceOf(address(this));
        uint256 aWETHBalance = IERC20(aweth).balanceOf(address(this));
        uint256 aWBTCBalance = IERC20(awbtc).balanceOf(address(this));
        uint256 aLINKBalance = IERC20(alink).balanceOf(address(this));

        aavePool.withdraw(usdc, aUSDCBalance, address(this));
        aavePool.withdraw(weth, aWETHBalance, address(this));
        aavePool.withdraw(wbtc, aWBTCBalance, address(this));
        aavePool.withdraw(link, aLINKBalance, address(this));

        totalUSDC = IERC20(usdc).balanceOf(address(this));
        totalUSDC += _swapWethToUsdc(IERC20(weth).balanceOf(address(this)));
        totalUSDC += _swapWbtcToUsdc(IERC20(wbtc).balanceOf(address(this)));
        totalUSDC += _swapLinkToUsdc(IERC20(link).balanceOf(address(this)));

        require(IERC20(usdc).transfer(msg.sender, totalUSDC), "Transfer failed");
        userPositions[msg.sender].isActive = false;
        return totalUSDC;
    }

    function claimYield() external returns (uint256 clientYield) {
        require(userPositions[msg.sender].isActive, "No active position");

        uint256 currentValue = getTotalPortfolioValue();
        uint256 initialInvestment = userPositions[msg.sender].initialUsdcDeposit;
        uint256 grossYield = currentValue > initialInvestment ? currentValue - initialInvestment : 0;
        require(grossYield > 0, "No yield to claim");

        clientYield = (grossYield * 80) / 100;
        uint256 daoYield = grossYield - clientYield;

        uint256 usdcToTransfer = _convertToUsdc(clientYield);
        require(IERC20(usdc).transfer(msg.sender, usdcToTransfer), "Transfer failed");
        userPositions[msg.sender].cumulativeYield += usdcToTransfer;
        require(IERC20(usdc).transfer(daoRecipient, daoYield), "DAO transfer failed");

        emit YieldClaimed(msg.sender, grossYield, usdcToTransfer, daoYield);
        return usdcToTransfer;
    }

    function getTotalPortfolioValue() public view returns (uint256) {
        uint256 usdcValue = IERC20(ausdc).balanceOf(address(this));
        uint256 wethValue = _getWethPriceInUsdc(IERC20(aweth).balanceOf(address(this)));
        uint256 wbtcValue = _getWbtcPriceInUsdc(IERC20(awbtc).balanceOf(address(this)));
        uint256 linkValue = _getLinkPriceInUsdc(IERC20(alink).balanceOf(address(this)));
        return usdcValue + wethValue + wbtcValue + linkValue;
    }

    function _approveAllTokens() internal {
        IERC20(usdc).approve(address(aavePool), type(uint256).max);
        IERC20(weth).approve(address(aavePool), type(uint256).max);
        IERC20(wbtc).approve(address(aavePool), type(uint256).max);
        IERC20(link).approve(address(aavePool), type(uint256).max);
        IERC20(ausdc).approve(address(aavePool), type(uint256).max);
        IERC20(aweth).approve(address(aavePool), type(uint256).max);
        IERC20(awbtc).approve(address(aavePool), type(uint256).max);
        IERC20(alink).approve(address(aavePool), type(uint256).max);
    }

    function _getAaveApys() internal pure returns (uint256, uint256, uint256) {
        return (450, 420, 580);
    }

    function _calculateOptimalAllocation(uint256 currentApy) internal pure returns (uint256) {
        if (currentApy > 500) return 4500; // +10%
        if (currentApy < 400) return 3500; // -10%
        return 4000; // Standard
    }

    function _rebalancePositions(uint256 /*wethAlloc*/, uint256 /*wbtcAlloc*/, uint256 /*linkAlloc*/) internal pure {
        // Placeholder logic
    }

    function _claimPoolRewards() internal pure returns (uint256) { return 0; }
    function _reallocateRewards(uint256) internal pure {}

    function _swapUsdcToWeth(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapUsdcToWbtc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapUsdcToLink(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapWethToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapWbtcToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapLinkToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _swapToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _convertToUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _getWethPriceInUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _getWbtcPriceInUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
    function _getLinkPriceInUsdc(uint256 amount) internal pure returns (uint256) { return amount; }
}
