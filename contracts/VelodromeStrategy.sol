// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IStrategy.sol";
// import "./interfaces/IVelodromePair.sol";
import "./interfaces/IVelodromeRouter.sol";
import "./interfaces/IVelodromeGauge.sol";
import "hardhat/console.sol";
 
import {LibStorage} from "./libraries/LibStorage.sol";
import {LibVelodrome} from "./libraries/LibVelodrome.sol";
import {LibUtils} from "./libraries/LibUtils.sol";
import "hardhat/console.sol";

/// The Strategies Contracts contain the logic that its in charge of deposit and withdraw the underlyings 
/// that are invested to generate a yield.

/// Strategies can have different types. 
/// The types are classified depending on the logic needed to deposit and withdraw the underlyings and do not depend on the protocol
/// where they are invested. For example: SpiritSwap and Spookyswap are two different projects, but they both uses the same contracts
/// as sushiswap to incentivise liquidity providers through the contract MasterChef, so, even though they are different projects, 
/// the strategy type is the same for both. Another example is the project Granary, this project is a fork of AAVE, so if One Ring is
/// to create a new strategy for Granary or any other AAVE fork, they all will be the same strategy type.

/// Each type of strategy will have different logic to deposit and withdraw (MasterChef contract is different from AAVE in so many ways)
/// But they all need to share the same interface, because the other contracts (facets of the Diamond) do not know which strategy are
/// they calling, for example: if the facets invoke the function 'usdcToUnderlyingAndInvest' from a strategy, they expect that the
/// function will take USDC, convert the USDC to whatever the strategy needs (the underlying) and put that to work to generate yield,
/// and at the end return the value in PLAIN_USD (US dollar with 3 decimals) that was invested, without knowing which type of strategy
/// it called.

/// At the launch of the OneRing product, there is going to be only one type: The MasterChef Strategy. Even though the product
/// will start with only this type, the facets should not assume this, and they must mantain an agnostic position.

/// The MasteChef strategies are as follows:
/// 1.- You add liquidity to a pair and get LP tokens for doing that.
/// 2.- You deposit those LP Tokens to the masterchef contract and receive rewards for doing that.
/// In the context of OneRing the LP tokens represent the underlying.

/// This contract is expected to be used by the facets through the use delegatecall. Since the facets are also called through 
/// a delegatecall by the Diamond Contract, then this contract is executed in the context of the Diamond.

/// The strategies contracts do not do any type of input validation nor any verification of a valid returned value, as far as these 
/// contracts concerns, they can be manipulated. It is the job of whoever called these contracts to validate any input they pass and
/// verified the values returned. 
contract VelodromeStrategy is IStrategy {
  
  uint256 public constant USDC_DECIMALS = 6;
  address public constant USDC_CONTRACT = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
  address public constant VELODROME_ROUTER = 0x9c12939390052919aF3155f41Bf4160Fd3666A6f;
  address public constant VELODROME_TOKEN = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;

  address public immutable TOKEN_1;
  address public immutable LP_TOKEN;
  address public immutable VELODROME_GAUGE;
  uint256 public immutable POOL_ID;
  uint256 public immutable TOKEN_1_DECIMALS;

  constructor(
    address token1,
    address lpToken,
    address velodromeGauge,
    uint256 poolID
  ) 
  {
    uint256 token1Decimals = uint256(ERC20(token1).decimals());
    TOKEN_1 = token1;
    LP_TOKEN = lpToken;
    VELODROME_GAUGE = velodromeGauge;
    POOL_ID = poolID;
    TOKEN_1_DECIMALS = token1Decimals;
  }
  
  /// @notice The function converts USDC to the underlying needed, and then put to work the underlying.
  /// Because we are in the SpiritswapV2 type, the underlying are LP Tokens.
  /// @param amount, amount of usdc to convert.
  /// @return addedInPlainUSD The amount of PLAIN_USD added.
  /// Security Considerations: 
  /// LibMasterChefUtils._getPlainUSDFromLPTokens --> It is used to calculate the PLAIN_USD of an amount of LP Tokens.
  /// it does this by reading the spot reserves of the pair, these reserves can be manipulated but its not in the scope
  /// of this function to protect the contract against this manipulation.
  function usdcToUnderlyingAndInvest(uint256 amount) 
    external returns(uint256 addedInPlainUSD) 
  {
    uint256 halfToken0 = LibVelodrome._calculateFirstHalf(amount, LP_TOKEN, USDC_DECIMALS, TOKEN_1_DECIMALS);
    uint256 halfToken1 = amount - halfToken0;

    uint256 token0Amount = halfToken0;
    uint256 token1Ideal = LibUtils._convertFromDecimalsToDecimals(halfToken1, USDC_DECIMALS, TOKEN_1_DECIMALS);
    uint256 minimumToken1Receive = (token1Ideal * 996) / 1000;

    IVelodromeRouter.route[] memory _route = new IVelodromeRouter.route[](1);
    _route[0] = IVelodromeRouter.route({ from: USDC_CONTRACT, to: TOKEN_1, stable: true});

    uint256 token1Amount = IVelodromeRouter(VELODROME_ROUTER).swapExactTokensForTokens(
      halfToken1,
      minimumToken1Receive,
      _route,
      address(this),
      block.timestamp
    )[1];

    (, , uint256 liquidity) = IVelodromeRouter(VELODROME_ROUTER).addLiquidity(
      USDC_CONTRACT,
      TOKEN_1,
      true,
      token0Amount, // 1:1 is assumed
      token1Amount, // 1:1 is assumed
      (token0Amount * 98) / 100 , // %2 tolerance on the assumption of 1:1 
      (token1Amount * 98) / 100, // %2 tolerance on the assumption of 1:1
      address(this),
      block.timestamp
    );
  
    addedInPlainUSD = LibVelodrome._getPlainUSDFromLPTokens(liquidity, LP_TOKEN, USDC_DECIMALS, TOKEN_1_DECIMALS);
    // console.log(liquidity);
    // console.log(LP_TOKEN);
    // console.log(USDC_DECIMALS);
    // console.log(TOKEN_1_DECIMALS);
    // console.log(addedInPlainUSD);
    LibVelodrome._investLPToken(LP_TOKEN, VELODROME_GAUGE, POOL_ID); 
  }

  /// @notice Withdraws a given amount of USDC from the strategy, it does that by converting some underlying back to USDC.
  /// @dev It calculates how much underlying to withdraw from the strategy using the following formula:
  /// (totalAmountOfUnderlyingInvested * usdcAmountToWithdraw) / (usdcValueOfTotalUnderlyingDeposited).
  /// unit analysis == (underlying * usdc) / usdc, that leaves us with underlying at the end.
  /// @param usdcAmountToWithdraw, the amount of USDC that is wanted to obtain.
  /// @return The amount of USDC that was gotten from transforming the underlying.
  /// Because we are in the MasterChef type, underlying means LP Tokens.
  /// Security Considerations: 
  /// LibMasterChefUtils._getPlainUSDFRomLPTokens --> Same as described in the 'tokenToUnderlyingAndInvest' function.
  /// LibMasterChefUtils._swapLPTokensForUSDC --> Read it at the library LibMasterChefUtils.
  function withdrawUSDC(uint256 usdcAmountToWithdraw) 
    external returns(uint256) 
  {
    //console.log(usdcAmountToWithdraw);
    uint256 lpTokensBalance = LibVelodrome._getLPBalance(VELODROME_GAUGE);
    uint256 valueInPlainUSD = LibVelodrome._getPlainUSDFromLPTokens(lpTokensBalance, LP_TOKEN, USDC_DECIMALS, TOKEN_1_DECIMALS);
    // console.log(lpTokensBalance);
    // console.log(valueInPlainUSD);
    // console.log(USDC_DECIMALS);
    // console.log(TOKEN_1_DECIMALS);
    //console.log(valueInPlainUSD);
    if(valueInPlainUSD == 0) {
      return 0;
    }

    uint256 denominator = 
        (LibUtils._convertFromDecimalsToDecimals(valueInPlainUSD, LibStorage.PLAIN_USD_DECIMALS, USDC_DECIMALS));

    //console.log(lpTokensBalance * usdcAmountToWithdraw);
    //console.log(denominator);
    
    uint256 amountOfLPTokensToWithdraw = (lpTokensBalance * usdcAmountToWithdraw) / denominator;
      
    IVelodromeGauge(VELODROME_GAUGE).withdraw(amountOfLPTokensToWithdraw);

    return LibVelodrome._swapLPTokensForUSDC(amountOfLPTokensToWithdraw, TOKEN_1, TOKEN_1_DECIMALS);
  }

  /// @notice Withdraw all the rewards and send them to recipient.
  function withdrawRewardsToRecipient(address recipient) external {
    address[] memory _tokens = new address[](1);
    _tokens[0] = VELODROME_TOKEN;

    IVelodromeGauge(VELODROME_GAUGE).getReward(address(this), _tokens);

    uint256 rewardBalance = LibUtils._balanceOfERC20(VELODROME_TOKEN, address(this));

    LibUtils._transferERC20(VELODROME_TOKEN, recipient, rewardBalance);
  }

  /// @notice Withdraw all underlying and all the rewards and send them to recipient.
  function exitAndSendToRecipient(address recipient) external {
    uint256 lpTokensBalance = LibVelodrome._getLPBalance(VELODROME_GAUGE);

    if(lpTokensBalance != 0) {
      IVelodromeGauge(VELODROME_GAUGE).withdraw(lpTokensBalance);
    }

    address[] memory _tokens = new address[](1);
    _tokens[0] = VELODROME_TOKEN;
    IVelodromeGauge(VELODROME_GAUGE).getReward(address(this), _tokens);

    uint256 lpBalance = LibUtils._balanceOfERC20(LP_TOKEN, address(this));
    uint256 rewardBalance = LibUtils._balanceOfERC20(VELODROME_TOKEN, address(this));

    LibUtils._transferERC20(LP_TOKEN, recipient, lpBalance);
    LibUtils._transferERC20(VELODROME_TOKEN, recipient, rewardBalance);
  }

  /// @notice Withdraw a percentage of the underlying deposited and send them to recipient.
  function withdrawPercentage(address recipient, uint256 percentage) external {
    uint256 totalBalance = LibVelodrome._getLPBalance(VELODROME_GAUGE);

    uint256 balanceToWithdraw = (totalBalance * percentage) / 100;

    IVelodromeGauge(VELODROME_GAUGE).withdraw(balanceToWithdraw);

    LibUtils._transferERC20(LP_TOKEN, recipient, balanceToWithdraw);
  }

  function investUnderlying(uint256 amount) external {
    LibUtils._transferFromERC20(LP_TOKEN, msg.sender, address(this), amount);
    LibVelodrome._investLPToken(LP_TOKEN, VELODROME_GAUGE, POOL_ID);
  }

}