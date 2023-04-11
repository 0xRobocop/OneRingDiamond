// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/IVelodromePair.sol";
import "../interfaces/IVelodromeRouter.sol";
import "../interfaces/IVelodromeGauge.sol";
import "hardhat/console.sol";

import {Strategy, LibStorage} from "./LibStorage.sol";
import {LibUtils} from "./LibUtils.sol";

library LibVelodrome {
  uint256 public constant USDC_DECIMALS = 6;
  address public constant USDC_CONTRACT = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
  address public constant VELODROME_ROUTER = 0x9c12939390052919aF3155f41Bf4160Fd3666A6f;
  address public constant VELODROME_TOKEN = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;

  /// @notice Take an amount of LP tokens, remove the liquidity and swap the tokens for USDC.
  /// @param amountOfLPTokens, the amount of lp tokens to be remove.
  /// @param token1, the address of the second token of the lp pair.
  /// @return The amount of USDC that was gotten by selling the tokens that made up the LP Token.
  /// Security Considerations: When reading the balance of token0 and token1 it is possible that there were tokens
  /// that were not gotten from the removeLiquidity function, for example, the contract can have 1000 DAI (or any other) 
  /// before removing liquidity. This will make the contract swap 1000 DAI + whatever the contract got from removing liquidity to USDC.
  /// This scenario will make this contract to report that more USDC was gotten from the removal of liquidity than actually was. 
  /// This will bubble up to whichever function called this function. 
  /// It is not in the scope of this function to protect the contract against this scenario.
  function _swapLPTokensForUSDC(uint256 amountOfLPTokens, address token1, uint256 token1Decimals) 
    internal returns(uint256) 
  {
    // console.log(amountOfLPTokens);
    // console.log(token1);
    // console.log(token1Decimals);

    IVelodromeRouter(VELODROME_ROUTER).removeLiquidity(
      USDC_CONTRACT,
      token1,
      true,
      amountOfLPTokens,
      1,
      1,
      address(this),
      block.timestamp
    );

    uint256 token0Amount = LibUtils._balanceOfERC20(USDC_CONTRACT, address(this));
    uint256 token1Amount = LibUtils._balanceOfERC20(token1, address(this));
    //console.log(token0Amount);
    uint256 usdcIdeal = LibUtils._convertFromDecimalsToDecimals(token1Amount, token1Decimals, USDC_DECIMALS);
    uint256 minimumUSDC = (usdcIdeal * 990) / 1000;
    //console.log(minimumUSDC);


    IVelodromeRouter.route[] memory _route = new IVelodromeRouter.route[](1);
    _route[0] = IVelodromeRouter.route({ from: token1, to: USDC_CONTRACT, stable: true});
    console.log(token1Amount);
    console.log(minimumUSDC);
    uint256 USDCToken1Amount = IVelodromeRouter(VELODROME_ROUTER).swapExactTokensForTokens(
      token1Amount,
      minimumUSDC,
      _route,
      address(this),
      block.timestamp
    )[1];

    console.log(USDCToken1Amount);

    return(token0Amount + USDCToken1Amount);
  }

  /// @notice Deposit all the lp tokens to the gauge contract.
  /// @param lpToken, the address of the lp pair to be deposited.
  /// @param lpGauge, the address of the gauge of the lp pair being deposit.
  function _investLPToken(address lpToken, address lpGauge, uint256 tokenID) internal {
    uint256 balanceLP = LibUtils._balanceOfERC20(lpToken, address(this));
    IVelodromeGauge(lpGauge).deposit(balanceLP, tokenID); 
  }

  /// @notice Returns the amount of LP the strategy holds.
  function _getLPBalance(address lpGauge) 
    internal view returns (uint256 balance) 
  {
    balance = IVelodromeGauge(lpGauge).balanceOf(address(this));
  }

  /// @notice Returns the amount of PLAIN_USD invested at a given pool id.
  /// @param lpToken, the address of the LP pair.
  /// @return Plain USD value invested at a pool id of a masterchef contract.
  function _getPlainUSDInvestedAtStrategy(address lpGauge, address lpToken, uint256 token0Decimals, uint256 token1Decimals) 
    internal view returns (uint256) 
  {
    uint256 totalLPTokens = _getLPBalance(lpGauge);

    return _getPlainUSDFromLPTokens(totalLPTokens, lpToken, token0Decimals, token1Decimals);
  }

  /// @notice Returns the PLAIN_USD value of lpTokenAmount.
  /// @dev It calculates the PLAIN_USD value reading the spot reserves of the LP Pair.
  /// @param lpTokenAmount, the amount of lp tokens to get the value from.
  /// @param lpToken, the address of token0 and token1 pair at the dex
  /// @param token0Decimals, decimals of the first token of the lp pair
  /// @param token1Decimals, decimals of the second token of the lp pair.
  /// @return Plain USD value of lp token amount.
  /// Math Done:
  /// amount0 and amount1 represent the amount of token0 and token1 the lpTokenAmount is entitled
  /// plus adding 3 zeros from the PLAIN_USD_DECIMALS.
  /// Because we only work with stablecoins, we consider that any stable coin == 1 Plain USD.
  /// For example 1 USDC == 1 Plain USD, 1 DAI == 1 Plain USD, etc.
  /// Given that we calculate the amount of PLAIN USD with the following formula:
  /// (amount0 / token0 zeros) + (amount1 / token1 zeros) REMEMBER amount0 and amount1 already have the decimal zeros (3 zeros)
  /// of PLAIN_USD.
  /// To avoid rounding errors we transformed the above formula in order to have as denominator
  /// token0 zeros * token1 zeros.
  function _getPlainUSDFromLPTokens(uint256 lpTokenAmount, address lpToken, uint256 token0Decimals, uint256 token1Decimals) 
    internal view returns (uint256) {
    if (lpTokenAmount > 0) {
      (uint256 reserves0, uint256 reserves1, ) = IVelodromePair(lpToken).getReserves();

      uint256 totalSupply = IERC20(lpToken).totalSupply();

      uint256 amount0 = (reserves0 * lpTokenAmount * (10 ** LibStorage.PLAIN_USD_DECIMALS)) / (totalSupply);
      uint256 amount1 = (reserves1 * lpTokenAmount * (10 ** LibStorage.PLAIN_USD_DECIMALS)) / (totalSupply);

      uint256 numerator = (amount0 * ( 10 ** token1Decimals) + amount1 * (10 ** token0Decimals));
      uint256 denominator = ((10 ** token0Decimals) * (10 ** token1Decimals));
    
      uint256 totalAmountInPlainUSD = numerator / denominator;
 
      return totalAmountInPlainUSD;
    }

    return 0;
  }

  function _calculateFirstHalf(
    uint256 amount, 
    address lpToken, 
    uint256 token0Decimals, 
    uint256 token1Decimals
  ) internal view returns(uint256) {

    (uint256 reserves0, uint256 reserves1, ) = IVelodromePair(lpToken).getReserves();

    uint256 amountToken1 = ((1_000_000) * reserves1) / reserves0;

    if (token0Decimals == token1Decimals) {
      uint256 totalEquation = 1_000_000 + amountToken1;

      return ((amount * 10 ** USDC_DECIMALS) / totalEquation);
    }

    else {
      uint256 decimalsMore = token1Decimals - token0Decimals;
      uint256 newAmountToken1 = amountToken1 / (10 ** decimalsMore);

      uint256 totalEquation = 1_000_000 + newAmountToken1;

      return ((amount * 10 ** USDC_DECIMALS) / totalEquation);
    }
  }
}