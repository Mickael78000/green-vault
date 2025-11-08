# Guide Complet : Implémentation des 3 Vaults Green Vault avec Foundry

## Table des matières

1. [Architecture générale](#architecture-générale)
2. [Prérequis et setup](#prérequis-et-setup)
3. [Vault Défensif](#vault-défensif)
4. [Vault Modéré](#vault-modéré)
5. [Vault Dynamique](#vault-dynamique)
6. [Flux utilisateur complet](#flux-utilisateur-complet)
7. [Tests et déploiement](#tests-et-déploiement)

---

## Architecture générale

### Vue d'ensemble du système

Green Vault implémente trois coffres-forts décentralisés (vaults) sur Ethereum, basés exclusivement sur les aTokens d'Aave. Chaque vault :

- **Accepte les dépôts en USDC** du client
- **Alloue automatiquement** le capital entre les aTokens Aave (composition fixe par vault)
- **Génère des rendements** via les intérêts d'Aave
- **Prélève 20% des rendements** pour la DAO, 80% revenant au client
- **Convertit les rendements** en USDC dans le portefeuille du client
- **Permet la déallocation** pour changer de vault

### Flux de capital

```
Client USDC
    ↓
[Dépôt dans Vault]
    ↓
[Allocation Aave : aUSDC, aDAI, aWETH, aWBTC, aLINK]
    ↓
[Génération de rendements]
    ↓
[Conversion en USDC]
    ↓
Client : +80% des rendements → Portefeuille
DAO : +20% des rendements → Trésorerie
```

---

## Prérequis et setup

### Installation de l'environnement

```bash
# Installer Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Créer un nouveau projet Foundry
forge init green-vault
cd green-vault

# Installer les dépendances Aave et OpenZeppelin
forge install Aave/aave-v3-core
forge install OpenZeppelin/openzeppelin-contracts
```

### Structure du projet

```
green-vault/
├── src/
│   ├── interfaces/
│   │   ├── IAave.sol
│   │   ├── IVault.sol
│   │   └── IERC20.sol
│   ├── vaults/
│   │   ├── GreenVaultDefensif.sol
│   │   ├── GreenVaultModere.sol
│   │   ├── GreenVaultDynamique.sol
│   │   └── BaseVault.sol
│   ├── strategies/
│   │   ├── DefensifStrategy.sol
│   │   ├── ModereStrategy.sol
│   │   └── DynamiqueStrategy.sol
│   ├── tokens/
│   │   └── GreenVaultGovernance.sol
│   ├── managers/
│   │   ├── YieldManager.sol
│   │   └── AllocationManager.sol
│   └── GreenVaultCore.sol
├── test/
│   ├── DefensifVault.t.sol
│   ├── ModereVault.t.sol
│   ├── DynamiqueVault.t.sol
│   └── Integration.t.sol
├── script/
│   ├── Deploy.s.sol
│   └── Setup.s.sol
└── foundry.toml
```

### Configuration foundry.toml

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@aave=lib/aave-v3-core/",
    "@openzeppelin=lib/openzeppelin-contracts/",
]

[rpc_endpoints]
mainnet = "http://localhost:8545"

[etherscan]
mainnet = { key = "${ETHERSCAN_KEY}" }
```

---

## Vault Défensif

### Composition et caractéristiques

| Composant | Allocation | APY Cible | Risque |
|-----------|-----------|-----------|---------|
| aUSDC | 40% | 2-3% | Minimal |
| aDAI | 35% | 2-3% | Minimal |
| aUSDT | 25% | 2-3% | Minimal |
| **TOTAL** | **100%** | **3-4% brut** | **Très faible** |

**Rendement net client** : 2-3% APY (après retrait 1 point)
**Rendement DAO** : ~1-1.5% annuels

### Contrat DefensifStrategy.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/interfaces/IPool.sol";

interface IAToken is IERC20 {
    function scaledBalanceOf(address user) external view returns (uint256);
    function getScaledUserBalanceAndSupply(address user)
        external
        view
        returns (uint256, uint256);
}

contract DefensifStrategy {
    // Adresses Aave (mainnet Ethereum)
    address public constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address public constant aUSDC = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant aDAI = 0x028171bCA77440897B824Ee2f0Be8756720DC026;
    address public constant aUSDT = 0x71fc860F7D3A592A4f11F4913215dFb32D33b278;

    address public constant USDC = 0xA0b86991d40023CCb98f06bcc0C62f4e5EC5CCdE;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Uniswap V3

    // Paramètres de stratégie
    uint256 public constant AUSDC_ALLOCATION = 4000; // 40%
    uint256 public constant ADAI_ALLOCATION = 3500;  // 35%
    uint256 public constant AUSDT_ALLOCATION = 2500; // 25%
    uint256 public constant ALLOCATION_DENOMINATOR = 10000;

    // Événements
    event DepositExecuted(
        address indexed user,
        uint256 usdcAmount,
        uint256 aUSDCAmount,
        uint256 aDAIAmount,
        uint256 aUSDTAmount
    );
    event WithdrawExecuted(address indexed user, uint256 totalUSDCWithdrawn);
    event YieldClaimed(uint256 aUSDCYield, uint256 aDAIYield, uint256 aUSDTYield);

    // ============ DÉPÔT ============

    /// @notice Dépose USDC et l'alloue dans les aTokens Aave
    /// @param usdcAmount Montant USDC à investir
    function deposit(uint256 usdcAmount) external returns (bool) {
        require(usdcAmount > 0, "Amount must be > 0");

        // Transfert USDC du client vers ce contrat
        require(
            IERC20(USDC).transferFrom(msg.sender, address(this), usdcAmount),
            "USDC transfer failed"
        );

        // Approbation Aave Pool
        IERC20(USDC).approve(AAVE_POOL, usdcAmount);
        IERC20(DAI).approve(AAVE_POOL, type(uint256).max);
        IERC20(USDT).approve(AAVE_POOL, type(uint256).max);

        // Calcul des allocations
        uint256 usdcAllocation = (usdcAmount * AUSDC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 daiAllocation = (usdcAmount * ADAI_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 usdtAllocation = (usdcAmount * AUSDT_ALLOCATION) / ALLOCATION_DENOMINATOR;

        // Conversion USDC → DAI et USDT pour allocations
        uint256 daiFromUsdc = _swapUsdcToDai(daiAllocation);
        uint256 usdtFromUsdc = _swapUsdcToUsdt(usdtAllocation);

        // Dépôts dans Aave
        IPool(AAVE_POOL).deposit(USDC, usdcAllocation, address(this), 0);
        IPool(AAVE_POOL).deposit(DAI, daiFromUsdc, address(this), 0);
        IPool(AAVE_POOL).deposit(USDT, usdtFromUsdc, address(this), 0);

        uint256 aUSDCBalance = IERC20(aUSDC).balanceOf(address(this));
        uint256 aDAIBalance = IERC20(aDAI).balanceOf(address(this));
        uint256 aUSDTBalance = IERC20(aUSDT).balanceOf(address(this));

        emit DepositExecuted(msg.sender, usdcAmount, aUSDCBalance, aDAIBalance, aUSDTBalance);

        return true;
    }

    // ============ RETRAIT ============

    /// @notice Retire tous les aTokens convertis en USDC
    function withdraw() external returns (uint256 totalUSDC) {
        // Récupération des soldes aTokens
        uint256 aUSDCBalance = IERC20(aUSDC).balanceOf(address(this));
        uint256 aDAIBalance = IERC20(aDAI).balanceOf(address(this));
        uint256 aUSDTBalance = IERC20(aUSDT).balanceOf(address(this));

        require(aUSDCBalance > 0 || aDAIBalance > 0 || aUSDTBalance > 0, "No balance to withdraw");

        // Approvals
        IERC20(aUSDC).approve(AAVE_POOL, aUSDCBalance);
        IERC20(aDAI).approve(AAVE_POOL, aDAIBalance);
        IERC20(aUSDT).approve(AAVE_POOL, aUSDTBalance);

        // Retraits d'Aave
        IPool(AAVE_POOL).withdraw(USDC, aUSDCBalance, address(this));
        IPool(AAVE_POOL).withdraw(DAI, aDAIBalance, address(this));
        IPool(AAVE_POOL).withdraw(USDT, aUSDTBalance, address(this));

        // Conversion en USDC si nécessaire
        uint256 daiBalance = IERC20(DAI).balanceOf(address(this));
        uint256 usdtBalance = IERC20(USDT).balanceOf(address(this));

        if (daiBalance > 0) {
            uint256 usdcFromDai = _swapDaiToUsdc(daiBalance);
            totalUSDC += usdcFromDai;
        }

        if (usdtBalance > 0) {
            uint256 usdcFromUsdt = _swapUsdtToUsdc(usdtBalance);
            totalUSDC += usdcFromUsdt;
        }

        uint256 directUsdc = IERC20(USDC).balanceOf(address(this));
        totalUSDC += directUsdc;

        // Transfert vers client
        require(IERC20(USDC).transfer(msg.sender, totalUSDC), "USDC transfer failed");

        emit WithdrawExecuted(msg.sender, totalUSDC);
    }

    // ============ GESTION DES RENDEMENTS ============

    /// @notice Récupère les rendements accumulés
    /// @return usdcYield Rendements totaux en USDC (après retrait 20% DAO)
    function claimYield() external returns (uint256 usdcYield) {
        // Récupération des soldes actuels aTokens
        uint256 aUSDCCurrent = IERC20(aUSDC).balanceOf(address(this));
        uint256 aDAICurrent = IERC20(aDAI).balanceOf(address(this));
        uint256 aUSDTCurrent = IERC20(aUSDT).balanceOf(address(this));

        // Calcul du yield (différence entre solde actuel et dépôt initial)
        // Note: En production, stocker les quantités initiales
        uint256 yieldAUSDC = _calculateYield(aUSDCCurrent, aUSDC);
        uint256 yieldADAI = _calculateYield(aDAICurrent, aDAI);
        uint256 yieldAUSDT = _calculateYield(aUSDTCurrent, aUSDT);

        emit YieldClaimed(yieldAUSDC, yieldADAI, yieldAUSDT);

        // Conversion yield en USDC
        usdcYield = yieldAUSDC; // aUSDC déjà en USDC

        // Conversion DAI yield
        if (yieldADAI > 0) {
            IERC20(aDAI).approve(AAVE_POOL, yieldADAI);
            IPool(AAVE_POOL).withdraw(DAI, yieldADAI, address(this));
            uint256 daiYield = IERC20(DAI).balanceOf(address(this));
            usdcYield += _swapDaiToUsdc(daiYield);
        }

        // Conversion USDT yield
        if (yieldAUSDT > 0) {
            IERC20(aUSDT).approve(AAVE_POOL, yieldAUSDT);
            IPool(AAVE_POOL).withdraw(USDT, yieldAUSDT, address(this));
            uint256 usdtYield = IERC20(USDT).balanceOf(address(this));
            usdcYield += _swapUsdtToUsdc(usdtYield);
        }

        // Distribution : 80% client, 20% DAO
        uint256 clientYield = (usdcYield * 80) / 100;
        uint256 daoYield = usdcYield - clientYield;

        require(IERC20(USDC).transfer(msg.sender, clientYield), "Client transfer failed");
        require(IERC20(USDC).transfer(address(0x1), daoYield), "DAO transfer failed"); // À remplacer par adresse DAO

        return clientYield;
    }

    // ============ FONCTIONS INTERNES ============

    function _swapUsdcToDai(uint256 amountUsdc) internal returns (uint256) {
        // Implémentation Uniswap V3 swap
        // À implémenter avec SwapRouter
        return amountUsdc; // Placeholder
    }

    function _swapUsdcToUsdt(uint256 amountUsdc) internal returns (uint256) {
        // Implémentation Uniswap V3 swap
        return amountUsdc; // Placeholder
    }

    function _swapDaiToUsdc(uint256 amountDai) internal returns (uint256) {
        // Implémentation Uniswap V3 swap
        return amountDai; // Placeholder
    }

    function _swapUsdtToUsdc(uint256 amountUsdt) internal returns (uint256) {
        // Implémentation Uniswap V3 swap
        return amountUsdt; // Placeholder
    }

    function _calculateYield(uint256 currentBalance, address aToken)
        internal
        view
        returns (uint256)
    {
        // Logique de calcul du yield basée sur le taux d'intérêt Aave
        // À adapter selon l'implémentation
        return 0; // Placeholder
    }
}
```

---

## Vault Modéré

### Composition et caractéristiques

| Composant | Allocation | APY Cible | Risque |
|-----------|-----------|-----------|---------|
| aUSDC | 30% | 2-3% | Minimal |
| aDAI | 20% | 2-3% | Minimal |
| aWETH | 30% | 4-5% | Modéré |
| aWBTC | 20% | 4-5% | Modéré |
| **TOTAL** | **100%** | **5-7% brut** | **Modéré** |

**Rendement net client** : 4-6% APY
**Rendement DAO** : ~1-2% annuels

### Contrat ModereStrategy.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/interfaces/IPool.sol";

contract ModereStrategy {
    // Adresses Aave
    address public constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address public constant aUSDC = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant aDAI = 0x028171bCA77440897B824Ee2f0Be8756720DC026;
    address public constant aWETH = 0x030bA81f1577D535A42DF016819fFD169A18ef33;
    address public constant aWBTC = 0x9ff58f4fFB29fa2266Ab20ef74519E1314662Ba4;

    address public constant USDC = 0xA0b86991d40023CCb98f06bcc0C62f4e5EC5CCdE;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e8e4F27ead9083C756Cc2;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDd86a4EfC2eCCe;

    // Allocations (points de base)
    uint256 public constant AUSDC_ALLOCATION = 3000;  // 30%
    uint256 public constant ADAI_ALLOCATION = 2000;   // 20%
    uint256 public constant AWETH_ALLOCATION = 3000;  // 30%
    uint256 public constant AWBTC_ALLOCATION = 2000;  // 20%
    uint256 public constant ALLOCATION_DENOMINATOR = 10000;

    // Suivi des dépôts initiaux par utilisateur
    mapping(address => DepositInfo) public userDeposits;

    struct DepositInfo {
        uint256 initialUsdcAmount;
        uint256 depositTimestamp;
        uint256 initialAUSDC;
        uint256 initialADAI;
        uint256 initialAWETH;
        uint256 initialAWBTC;
    }

    event DepositExecuted(
        address indexed user,
        uint256 usdcAmount,
        uint256 timestamp
    );
    event YieldClaimed(
        address indexed user,
        uint256 clientYield,
        uint256 daoYield
    );
    event Rebalanced(
        uint256 newAWETHAmount,
        uint256 newAWBTCAmount,
        uint256 timestamp
    );

    // ============ DÉPÔT ============

    /// @notice Dépose USDC et l'alloue dans aUSDC, aDAI, aWETH, aWBTC
    function deposit(uint256 usdcAmount) external returns (bool) {
        require(usdcAmount > 0, "Amount must be > 0");

        // Transfert USDC
        require(
            IERC20(USDC).transferFrom(msg.sender, address(this), usdcAmount),
            "USDC transfer failed"
        );

        // Approvals
        _approveAllTokens();

        // Allocations
        uint256 ausdc = (usdcAmount * AUSDC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 adai = (usdcAmount * ADAI_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 aweth = (usdcAmount * AWETH_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 awbtc = (usdcAmount * AWBTC_ALLOCATION) / ALLOCATION_DENOMINATOR;

        // Conversions stablecoins
        uint256 daiAmount = _swapUsdcToDai(adai);
        uint256 wethAmount = _swapUsdcToWeth(aweth);
        uint256 wbtcAmount = _swapUsdcToWbtc(awbtc);

        // Dépôts Aave
        IPool(AAVE_POOL).deposit(USDC, ausdc, address(this), 0);
        IPool(AAVE_POOL).deposit(DAI, daiAmount, address(this), 0);
        IPool(AAVE_POOL).deposit(WETH, wethAmount, address(this), 0);
        IPool(AAVE_POOL).deposit(WBTC, wbtcAmount, address(this), 0);

        // Enregistrement du dépôt
        userDeposits[msg.sender] = DepositInfo(
            usdcAmount,
            block.timestamp,
            IERC20(aUSDC).balanceOf(address(this)),
            IERC20(aDAI).balanceOf(address(this)),
            IERC20(aWETH).balanceOf(address(this)),
            IERC20(aWBTC).balanceOf(address(this))
        );

        emit DepositExecuted(msg.sender, usdcAmount, block.timestamp);
        return true;
    }

    // ============ RÉÉQUILIBRAGE MENSUEL ============

    /// @notice Rééquilibre les positions mensuellement si conditions Aave changent
    /// @dev Doit être appelé par un oracle ou un keepers
    function rebalanceMonthly() external returns (bool) {
        require(block.timestamp % (30 days) < 1 hours, "Not in rebalance window");

        uint256 totalValue = getTotalPortfolioValue();

        uint256 targetAWETH = (totalValue * AWETH_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 targetAWBTC = (totalValue * AWBTC_ALLOCATION) / ALLOCATION_DENOMINATOR;

        uint256 currentAWETH = IERC20(aWETH).balanceOf(address(this));
        uint256 currentAWBTC = IERC20(aWBTC).balanceOf(address(this));

        // Ajustements si dérive > 5%
        if (_hasDeviated(currentAWETH, targetAWETH, 500) ||
            _hasDeviated(currentAWBTC, targetAWBTC, 500)) {
            // Rééquilibrage logique
        }

        emit Rebalanced(targetAWETH, targetAWBTC, block.timestamp);
        return true;
    }

    // ============ RETRAIT ============

    /// @notice Retire tous les aTokens convertis en USDC
    function withdraw() external returns (uint256 totalUSDC) {
        uint256 aUSDCBalance = IERC20(aUSDC).balanceOf(address(this));
        uint256 aDAIBalance = IERC20(aDAI).balanceOf(address(this));
        uint256 aWETHBalance = IERC20(aWETH).balanceOf(address(this));
        uint256 aWBTCBalance = IERC20(aWBTC).balanceOf(address(this));

        require(
            aUSDCBalance > 0 || aDAIBalance > 0 || aWETHBalance > 0 || aWBTCBalance > 0,
            "No balance to withdraw"
        );

        // Approvals
        _approveAllTokens();

        // Retraits Aave
        IPool(AAVE_POOL).withdraw(USDC, aUSDCBalance, address(this));
        IPool(AAVE_POOL).withdraw(DAI, aDAIBalance, address(this));
        IPool(AAVE_POOL).withdraw(WETH, aWETHBalance, address(this));
        IPool(AAVE_POOL).withdraw(WBTC, aWBTCBalance, address(this));

        // Conversions en USDC
        totalUSDC = IERC20(USDC).balanceOf(address(this));

        if (IERC20(DAI).balanceOf(address(this)) > 0) {
            totalUSDC += _swapDaiToUsdc(IERC20(DAI).balanceOf(address(this)));
        }
        if (IERC20(WETH).balanceOf(address(this)) > 0) {
            totalUSDC += _swapWethToUsdc(IERC20(WETH).balanceOf(address(this)));
        }
        if (IERC20(WBTC).balanceOf(address(this)) > 0) {
            totalUSDC += _swapWbtcToUsdc(IERC20(WBTC).balanceOf(address(this)));
        }

        require(IERC20(USDC).transfer(msg.sender, totalUSDC), "Transfer failed");
        return totalUSDC;
    }

    // ============ GESTION RENDEMENTS ============

    /// @notice Récupère les rendements avec distribution 80/20
    function claimYield() external returns (uint256 clientYield) {
        uint256 currentTotalValue = getTotalPortfolioValue();
        uint256 initialInvestment = userDeposits[msg.sender].initialUsdcAmount;

        uint256 grossYield = currentTotalValue > initialInvestment
            ? currentTotalValue - initialInvestment
            : 0;

        require(grossYield > 0, "No yield to claim");

        // Distribution 80/20
        clientYield = (grossYield * 80) / 100;
        uint256 daoYield = grossYield - clientYield;

        // Conversions en USDC si nécessaire
        uint256 usdcToTransfer = _convertToUsdc(clientYield);

        require(IERC20(USDC).transfer(msg.sender, usdcToTransfer), "Client transfer failed");
        // Envoyer daoYield à trésorerie DAO

        emit YieldClaimed(msg.sender, usdcToTransfer, daoYield);
        return usdcToTransfer;
    }

    // ============ VUES ============

    /// @notice Retourne la valeur totale du portefeuille en USDC
    function getTotalPortfolioValue() public view returns (uint256) {
        uint256 aUSDCValue = IERC20(aUSDC).balanceOf(address(this));
        uint256 aDAIValue = _convertToUsdc(IERC20(aDAI).balanceOf(address(this))); // DAI ≈ USDC
        uint256 aWETHValue = _getWethPriceInUsdc(IERC20(aWETH).balanceOf(address(this)));
        uint256 aWBTCValue = _getWbtcPriceInUsdc(IERC20(aWBTC).balanceOf(address(this)));

        return aUSDCValue + aDAIValue + aWETHValue + aWBTCValue;
    }

    // ============ FONCTIONS INTERNES ============

    function _approveAllTokens() internal {
        IERC20(USDC).approve(AAVE_POOL, type(uint256).max);
        IERC20(DAI).approve(AAVE_POOL, type(uint256).max);
        IERC20(WETH).approve(AAVE_POOL, type(uint256).max);
        IERC20(WBTC).approve(AAVE_POOL, type(uint256).max);
        IERC20(aUSDC).approve(AAVE_POOL, type(uint256).max);
        IERC20(aDAI).approve(AAVE_POOL, type(uint256).max);
        IERC20(aWETH).approve(AAVE_POOL, type(uint256).max);
        IERC20(aWBTC).approve(AAVE_POOL, type(uint256).max);
    }

    function _hasDeviated(uint256 current, uint256 target, uint256 basisPoints)
        internal
        pure
        returns (bool)
    {
        uint256 maxDeviation = (target * basisPoints) / 10000;
        return current > target + maxDeviation || current < target - maxDeviation;
    }

    function _swapUsdcToDai(uint256 amount) internal returns (uint256) {
        // Implémentation Uniswap
        return amount;
    }

    function _swapUsdcToWeth(uint256 amount) internal returns (uint256) {
        // Implémentation Uniswap
        return amount;
    }

    function _swapUsdcToWbtc(uint256 amount) internal returns (uint256) {
        // Implémentation Uniswap
        return amount;
    }

    function _swapDaiToUsdc(uint256 amount) internal returns (uint256) {
        return amount;
    }

    function _swapWethToUsdc(uint256 amount) internal returns (uint256) {
        // Utiliser Chainlink oracle pour prix
        return amount;
    }

    function _swapWbtcToUsdc(uint256 amount) internal returns (uint256) {
        // Utiliser Chainlink oracle pour prix
        return amount;
    }

    function _convertToUsdc(uint256 amount) internal view returns (uint256) {
        return amount; // Placeholder
    }

    function _getWethPriceInUsdc(uint256 wethAmount) internal view returns (uint256) {
        // Utiliser oracle Aave ou Chainlink
        return wethAmount;
    }

    function _getWbtcPriceInUsdc(uint256 wbtcAmount) internal view returns (uint256) {
        // Utiliser oracle Aave ou Chainlink
        return wbtcAmount;
    }
}
```

---

## Vault Dynamique

### Composition et caractéristiques

| Composant | Allocation | APY Cible | Risque |
|-----------|-----------|-----------|---------|
| aUSDC | 20% | 2-3% | Minimal |
| aWETH | 40% | 4-6% | Élevé |
| aWBTC | 25% | 4-6% | Élevé |
| aLINK | 15% | 5-7% | Élevé |
| **TOTAL** | **100%** | **9-12% brut** | **Élevé** |

**Rendement net client** : 8-11% APY
**Rendement DAO** : ~2-4% annuels

### Contrat DynamiqueStrategy.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/interfaces/IPool.sol";

contract DynamiqueStrategy {
    // Adresses Aave
    address public constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address public constant aUSDC = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant aWETH = 0x030bA81f1577D535A42Df016819fFD169A18ef33;
    address public constant aWBTC = 0x9ff58f4fFB29fa2266Ab20ef74519E1314662Ba4;
    address public constant aLINK = 0xa06bC25b5805e5ee5d2ec0681B25E1a68B6cA2Bb;

    address public constant USDC = 0xA0b86991d40023CCb98f06bcc0C62f4e5EC5CCdE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e8e4F27ead9083C756Cc2;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDd86a4EfC2eCCe;
    address public constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    address public constant AAVE_TOKEN = 0x7Fc66500c84A76Ad7e9c93437E434122A1f3b3A7;
    address public constant STAKING_CONTROLLER = 0xd784927Ff2819f32fDe7b100fdc6e3bf5d185a5b;

    // Allocations (points de base)
    uint256 public constant AUSDC_ALLOCATION = 2000;  // 20%
    uint256 public constant AWETH_ALLOCATION = 4000;  // 40%
    uint256 public constant AWBTC_ALLOCATION = 2500;  // 25%
    uint256 public constant ALINK_ALLOCATION = 1500;  // 15%
    uint256 public constant ALLOCATION_DENOMINATOR = 10000;

    // Paramètres d'optimisation
    uint256 public rebalanceIntervalDays = 7;
    uint256 public lastRebalanceTimestamp;
    bool public autoCompound = true;

    mapping(address => UserPosition) public userPositions;

    struct UserPosition {
        uint256 initialUsdcDeposit;
        uint256 depositTimestamp;
        uint256 cumulativeYield;
        bool isActive;
    }

    event DepositExecuted(
        address indexed user,
        uint256 usdcAmount,
        uint256 timestamp
    );
    event YieldClaimed(
        address indexed user,
        uint256 grossYield,
        uint256 clientYield,
        uint256 daoYield
    );
    event RebalancedDynamic(uint256 timestamp, string reason);
    event CompoundingExecuted(uint256 aaveRewardsReinvested);
    event WeeklyRebalance(
        uint256 newWethAllocation,
        uint256 newWbtcAllocation,
        uint256 newLinkAllocation,
        uint256 timestamp
    );

    // ============ DÉPÔT ============

    /// @notice Dépose USDC avec allocation aggressive
    function deposit(uint256 usdcAmount) external returns (bool) {
        require(usdcAmount > 0, "Amount must be > 0");
        require(!userPositions[msg.sender].isActive, "User already has active position");

        // Transfert USDC
        require(
            IERC20(USDC).transferFrom(msg.sender, address(this), usdcAmount),
            "USDC transfer failed"
        );

        _approveAllTokens();

        // Allocations
        uint256 ausdc = (usdcAmount * AUSDC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 aweth = (usdcAmount * AWETH_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 awbtc = (usdcAmount * AWBTC_ALLOCATION) / ALLOCATION_DENOMINATOR;
        uint256 alink = (usdcAmount * ALINK_ALLOCATION) / ALLOCATION_DENOMINATOR;

        // Conversions
        uint256 wethAmount = _swapUsdcToWeth(aweth);
        uint256 wbtcAmount = _swapUsdcToWbtc(awbtc);
        uint256 linkAmount = _swapUsdcToLink(alink);

        // Dépôts Aave
        IPool(AAVE_POOL).deposit(USDC, ausdc, address(this), 0);
        IPool(AAVE_POOL).deposit(WETH, wethAmount, address(this), 0);
        IPool(AAVE_POOL).deposit(WBTC, wbtcAmount, address(this), 0);
        IPool(AAVE_POOL).deposit(LINK, linkAmount, address(this), 0);

        // Enregistrement position
        userPositions[msg.sender] = UserPosition(
            usdcAmount,
            block.timestamp,
            0,
            true
        );

        emit DepositExecuted(msg.sender, usdcAmount, block.timestamp);
        return true;
    }

    // ============ RÉÉQUILIBRAGE DYNAMIQUE HEBDOMADAIRE ============

    /// @notice Rééquilibre hebdomadaire selon APY fluctuants d'Aave
    function rebalanceWeekly() external returns (bool) {
        require(
            block.timestamp >= lastRebalanceTimestamp + (7 days),
            "Not yet time to rebalance"
        );

        uint256 totalPortfolioValue = getTotalPortfolioValue();

        // Récupération APY actuels d'Aave v3
        (uint256 wethApy, uint256 wbtcApy, uint256 linkApy) = _getAaveApys();

        // Rééquilibrage basé sur meilleurs rendements
        uint256 newWethAlloc = _calculateOptimalAllocation(wethApy);
        uint256 newWbtcAlloc = _calculateOptimalAllocation(wbtcApy);
        uint256 newLinkAlloc = ALINK_ALLOCATION; // Stable pour diversification

        // Ajustements positions
        _rebalancePositions(newWethAlloc, newWbtcAlloc, newLinkAlloc);

        lastRebalanceTimestamp = block.timestamp;

        emit WeeklyRebalance(newWethAlloc, newWbtcAlloc, newLinkAlloc, block.timestamp);
        return true;
    }

    // ============ STAKING AAVE & COMPOUNDING ============

    /// @notice Accumule et réinvestit les récompenses AAVE
    function executeCompounding() external returns (uint256 aaveReinvested) {
        require(autoCompound, "Auto-compounding disabled");

        // Récupération rewards AAVE du protocole
        uint256 aaveBalance = IERC20(AAVE_TOKEN).balanceOf(address(this));

        if (aaveBalance > 0) {
            // Staking AAVE pour récompenses composées
            _stakeAaveTokens(aaveBalance);
            aaveReinvested = aaveBalance;
        }

        // Réinvestissement rewards dans meilleurs pools
        uint256 poolRewards = _claimPoolRewards();
        if (poolRewards > 0) {
            uint256 usdcFromRewards = _swapToUsdc(poolRewards);
            _reallocateRewards(usdcFromRewards);
        }

        emit CompoundingExecuted(aaveReinvested);
        return aaveReinvested;
    }

    // ============ RETRAIT ============

    /// @notice Retire tous les aTokens convertis en USDC
    function withdraw() external returns (uint256 totalUSDC) {
        require(userPositions[msg.sender].isActive, "No active position");

        uint256 aUSDCBalance = IERC20(aUSDC).balanceOf(address(this));
        uint256 aWETHBalance = IERC20(aWETH).balanceOf(address(this));
        uint256 aWBTCBalance = IERC20(aWBTC).balanceOf(address(this));
        uint256 aLINKBalance = IERC20(aLINK).balanceOf(address(this));

        _approveAllTokens();

        // Retraits Aave
        IPool(AAVE_POOL).withdraw(USDC, aUSDCBalance, address(this));
        IPool(AAVE_POOL).withdraw(WETH, aWETHBalance, address(this));
        IPool(AAVE_POOL).withdraw(WBTC, aWBTCBalance, address(this));
        IPool(AAVE_POOL).withdraw(LINK, aLINKBalance, address(this));

        // Conversions en USDC
        totalUSDC = IERC20(USDC).balanceOf(address(this));
        totalUSDC += _swapWethToUsdc(IERC20(WETH).balanceOf(address(this)));
        totalUSDC += _swapWbtcToUsdc(IERC20(WBTC).balanceOf(address(this)));
        totalUSDC += _swapLinkToUsdc(IERC20(LINK).balanceOf(address(this)));

        require(IERC20(USDC).transfer(msg.sender, totalUSDC), "Transfer failed");

        userPositions[msg.sender].isActive = false;
        return totalUSDC;
    }

    // ============ GESTION RENDEMENTS ============

    /// @notice Récupère les rendements avec distribution 80/20
    function claimYield() external returns (uint256 clientYield) {
        require(userPositions[msg.sender].isActive, "No active position");

        uint256 currentValue = getTotalPortfolioValue();
        uint256 initialInvestment = userPositions[msg.sender].initialUsdcDeposit;

        uint256 grossYield = currentValue > initialInvestment
            ? currentValue - initialInvestment
            : 0;

        require(grossYield > 0, "No yield to claim");

        // Distribution 80/20
        clientYield = (grossYield * 80) / 100;
        uint256 daoYield = grossYield - clientYield;

        uint256 usdcToTransfer = _convertToUsdc(clientYield);

        require(IERC20(USDC).transfer(msg.sender, usdcToTransfer), "Transfer failed");

        userPositions[msg.sender].cumulativeYield += usdcToTransfer;

        emit YieldClaimed(msg.sender, grossYield, usdcToTransfer, daoYield);
        return usdcToTransfer;
    }

    // ============ VUES ============

    /// @notice Retourne la valeur totale en USDC avec pricing oracle
    function getTotalPortfolioValue() public view returns (uint256) {
        uint256 usdcValue = IERC20(aUSDC).balanceOf(address(this));
        uint256 wethValue = _getWethPriceInUsdc(IERC20(aWETH).balanceOf(address(this)));
        uint256 wbtcValue = _getWbtcPriceInUsdc(IERC20(aWBTC).balanceOf(address(this)));
        uint256 linkValue = _getLinkPriceInUsdc(IERC20(aLINK).balanceOf(address(this)));

        return usdcValue + wethValue + wbtcValue + linkValue;
    }

    /// @notice Retourne les APY actuels des pools Aave
    function getPortfolioAPY() external view returns (uint256) {
        (uint256 wethApy, uint256 wbtcApy, uint256 linkApy) = _getAaveApys();
        uint256 averageApy = ((wethApy * 40) + (wbtcApy * 25) + (linkApy * 15)) / 100;
        return averageApy;
    }

    // ============ FONCTIONS INTERNES ============

    function _approveAllTokens() internal {
        IERC20(USDC).approve(AAVE_POOL, type(uint256).max);
        IERC20(WETH).approve(AAVE_POOL, type(uint256).max);
        IERC20(WBTC).approve(AAVE_POOL, type(uint256).max);
        IERC20(LINK).approve(AAVE_POOL, type(uint256).max);
        IERC20(aUSDC).approve(AAVE_POOL, type(uint256).max);
        IERC20(aWETH).approve(AAVE_POOL, type(uint256).max);
        IERC20(aWBTC).approve(AAVE_POOL, type(uint256).max);
        IERC20(aLINK).approve(AAVE_POOL, type(uint256).max);
    }

    function _getAaveApys() internal view returns (uint256, uint256, uint256) {
        // Query Aave v3 pour APY actuels
        // Utiliser ReserveData de Aave
        return (450, 420, 580); // Placeholder (4.5%, 4.2%, 5.8%)
    }

    function _calculateOptimalAllocation(uint256 currentApy)
        internal
        view
        returns (uint256)
    {
        // Ajuste allocation basée sur APY
        if (currentApy > 500) {
            // Si APY > 5%, augmenter allocation
            return 4500; // +10%
        } else if (currentApy < 400) {
            // Si APY < 4%, réduire
            return 3500; // -10%
        }
        return 4000; // Standard
    }

    function _rebalancePositions(uint256 wethAlloc, uint256 wbtcAlloc, uint256 linkAlloc)
        internal
    {
        // Logique de rééquilibrage
        // À implémenter selon stratégie
    }

    function _stakeAaveTokens(uint256 amount) internal {
        // Staking Aave pour cooldown et récompenses
        IERC20(AAVE_TOKEN).approve(STAKING_CONTROLLER, amount);
    }

    function _claimPoolRewards() internal returns (uint256) {
        // Claim des incentives Aave v3
        return 0; // Placeholder
    }

    function _reallocateRewards(uint256 usdcAmount) internal {
        // Réallouer rewards aux pools meilleurs rendements
    }

    function _swapUsdcToWeth(uint256 amount) internal returns (uint256) {
        // Uniswap swap
        return amount;
    }

    function _swapUsdcToWbtc(uint256 amount) internal returns (uint256) {
        return amount;
    }

    function _swapUsdcToLink(uint256 amount) internal returns (uint256) {
        return amount;
    }

    function _swapWethToUsdc(uint256 amount) internal returns (uint256) {
        return amount;
    }

    function _swapWbtcToUsdc(uint256 amount) internal returns (uint256) {
        return amount;
    }

    function _swapLinkToUsdc(uint256 amount) internal returns (uint256) {
        return amount;
    }

    function _swapToUsdc(uint256 amount) internal returns (uint256) {
        return amount;
    }

    function _convertToUsdc(uint256 amount) internal view returns (uint256) {
        return amount;
    }

    function _getWethPriceInUsdc(uint256 wethAmount) internal view returns (uint256) {
        return wethAmount;
    }

    function _getWbtcPriceInUsdc(uint256 wbtcAmount) internal view returns (uint256) {
        return wbtcAmount;
    }

    function _getLinkPriceInUsdc(uint256 linkAmount) internal view returns (uint256) {
        return linkAmount;
    }
}
```

---

## Flux utilisateur complet

### Étape 1 : Connexion et dépôt USDC

```
1. Client se connecte via Privy → wallet créé
2. Client connecte wallet et approuve USDC contract
3. Client saisit montant USDC à investir
4. Client sélectionne vault (Défensif / Modéré / Dynamique)
5. Client approuve transaction
   → Montant USDC transféré vers contrat vault
   → Allocation automatique en aTokens Aave
   → Position enregistrée dans userDeposits/userPositions
```

### Étape 2 : Accumulation des rendements

**Vault Défensif (passif)** :
- Intérêts aUSDC, aDAI, aUSDT générés automatiquement
- Aucune action requise du client

**Vault Modéré** (semi-actif) :
- Intérêts crypto générés
- Rééquilibrage mensuel maintient composition 50/50 stable/volatil

**Vault Dynamique** (très actif) :
- Intérêts maximize par APY optimal
- Rééquilibrage hebdomadaire selon conditions
- Compounding automatique des AAVE rewards

### Étape 3 : Réclamation des rendements

```
1. Client appelle claimYield()
2. Système calcule : Valeur actuelle - Valeur initiale = Rendement brut
3. Distribution:
   - 80% rendement → Portefeuille client en USDC
   - 20% rendement → Trésorerie DAO
4. Conversion automatique en USDC
5. Transfer client reçoit son USDC dans wallet Privy
```

### Étape 4 : Changement de vault

```
1. Client appelle withdraw() sur vault actuel
   → Tous les aTokens convertis en USDC
   → USDC retourné au wallet client
2. Client approuve nouveau vault
3. Client appelle deposit() sur nouveau vault avec son USDC
   → Allocation selon nouvelle composition
```

### Étape 5 : Sortie totale

```
1. Client appelle withdraw() sur vault actuel
2. Tous les aTokens liquidés en USDC
3. USDC transféré au portefeuille client
4. Position marquée inactive
5. Client peut retirer USDC du wallet
```

---

## Tests et déploiement

### Tests unitaires avec Foundry

```bash
# Tests vault défensif
forge test --match DefensifVault

# Tests vault modéré
forge test --match ModereVault

# Tests vault dynamique
forge test --match DynamiqueVault

# Tests intégration
forge test --match Integration

# Coverage
forge coverage
```

### Déploiement sur Mainnet Fork

```bash
# Démarrer fork local
anvil --fork-url https://eth-mainnet.alchemyapi.io/v2/{API_KEY}

# Exécuter script déploiement
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Checklist de déploiement

- [ ] Tous les tests passent (100% coverage)
- [ ] Audit interne des smart contracts
- [ ] Intégration Privy testée
- [ ] Swaps Uniswap v3 intégrés et testés
- [ ] Oracles Chainlink configurés
- [ ] Paramètres allocations vérifiés
- [ ] Limites TVL et rééquilibrage définies
- [ ] Événements correctement émis
- [ ] Dashboard d'affichage des positions opérationnel
- [ ] Documentation complète rédigée

---

## Prochaines étapes

1. **Implémentation complète des swaps** : Uniswap v3 intégration avec slippage protection
2. **Oracles de prix** : Chainlink pour WETH, WBTC, LINK en USDC
3. **Dashboard React** : Affichage portfolio, APY, rendements
4. **Gouvernance DAO** : Snapshot voting intégré
5. **Tests e2e** : Scénarios complets utilisateur
6. **Monitoring en production** : Alertes pour déviations APY

