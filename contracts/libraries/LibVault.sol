// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {LibStorage, VaultStorage, StrategyManagerStorage, Strategy} from "./LibStorage.sol";
import {LibUtils} from "./LibUtils.sol";
import {LibRequirements} from "./LibRequirements.sol";

import "hardhat/console.sol";

library LibVault {
  

  function vs() internal pure returns (VaultStorage storage) {
    return LibStorage.vaultStorage();
  }

  function sms() internal pure returns (StrategyManagerStorage storage) {
    return LibStorage.strategyManagerStorage();
  }

  function ios(bytes32 position) internal pure returns (Strategy storage) {
    return LibStorage.strategyStorage(position);
  }

  /// @notice Takes amount of token from msg.sender and swap it for USDC.
  /// @dev If token is USDC, it does not do the swap.
  /// @param  token, the address of the token being swapped.
  /// @param  amount, the quantity of tokens to be swapped.
  /// @return The total amount of USDC that was returned from the swap. 
  /// Security Considerations: It is assumed that USDC will never lose its peg.
  function _swapTokenToUSDC(address token, uint256 amount) internal returns (uint256) {
    LibUtils._transferFromERC20(token, msg.sender, address(this), amount);
    return amount;
  }

  /// @notice Checks the amount of USDC to deposit is valid, calculates the minimum of 1USD the user can recieve
  /// , calls the function _usdcToUnderlyingAndInvest and update the state variables usdcTVL and lastBlockDepositWasCalled.
  /// @param totalAmountUSDC, amount of usdc to convert to underlying.
  /// @return The total amount of 1USD to mint to user.
  /// Security Considerations: It is expected that _usdcToUnderlyingAndInvest returns a valid amount of 1USD tokens to mint.
  /// no less than a minimum (controlled by a slippage) to protect the user 
  /// and no more than the equivalent of USDC deposited in 1USD tokens to protect the contract.
  function _deposit(uint256 totalAmountUSDC) internal returns(uint256) {
    // Ideally the contract should mint 1:1 with the amount of USDC deposited
    uint256 expected1USDTokens = 
            LibUtils._convertFromDecimalsToDecimals(totalAmountUSDC, LibStorage.USDC_DECIMALS, LibStorage.ONE_USD_DECIMALS);
    
    // But the contract has some tolerance controlled by the slippage variable.
    uint256 minimum1USDTokens = _getMinimumAmount(expected1USDTokens); 

    // We convert the USDC to the underlying and then invest it.
    uint256 amount1USDToMint = _usdcToUnderlyingAndInvest(totalAmountUSDC, minimum1USDTokens);

    vs().lastBlockDepositWasCalled = uint128(block.number);

    return amount1USDToMint;
  }

  /// @notice Converts USDC to the underlying of each strategy and then invest that underlying.
  /// @dev It does a delegatecall to the strategy contract, this call is agnostic of the type of the strategy.
  /// @param amountUSDC, the amount of USDC to convert.
  /// @param minimum1USDTokens, the minimum of 1USDTokens to mint.
  /// @return The amount of 1USD to mint.
  /// Security Considerations: This function invokes the function usdcToUnderlyingAndInvest via a delegatecall
  /// this function returns the amount of PLAIN_USD that was invested in each strategy, but the reported value could have been
  /// manipulated (check security considerations at usdcToUnderlyingAndInvest for more details).
  /// Short story: usdcToUnderlyingAndInvest does not make anything to prevent any manipulation to happen.
  /// Is in the scope of this function to protect the contract for any manipulation that could happen at usdcToUnderlyingAndInvest.
  /// It does that by reverting any minting that is smaller than the minimumt to mint.
  /// and by ensuring the contract does not mint more 1USD tokens than its equivalent in the parameter 'amountUSDC'.
  /// The contract also have another reduntant protection (state variable lastBlockDepositWasCalled)
  /// that should avoid flash loans that is the most used tool across defi to manipulate markets.
  function _usdcToUnderlyingAndInvest(uint256 amountUSDC, uint256 minimum1USDTokens) internal returns(uint256) {
    uint256 depositedInPlainUSD;
    uint256 usdcConvertedSoFar;

    uint256 amountOfStrategiesActive = sms().numberOfStrategiesActive;
   
    for(uint256 index = 0; index < amountOfStrategiesActive; index++) {
      bytes32 position = sms().activeStrategiesArray[index];
      Strategy storage strategyInfo = ios(position);
      
      // Total Allocation is always 100 for this function to be executed.
      uint256 usdcToConvert = (amountUSDC * strategyInfo.allocation) / 100;
      
      if(index == amountOfStrategiesActive - 1) {
        usdcToConvert = amountUSDC - usdcConvertedSoFar;
      }
      //console.log(usdcToConvert);
      (bool success, bytes memory data) = strategyInfo.strategyAddress.delegatecall(
        abi.encodeWithSignature("usdcToUnderlyingAndInvest(uint256)", usdcToConvert));

      if(!success) {
        if (data.length == 0) revert();
        assembly {
            revert(add(32, data), mload(data))
        }
      }
      
      uint256 plainUSDAdded = abi.decode(data,(uint256));
      //console.log(plainUSDAdded);
      depositedInPlainUSD += plainUSDAdded;
      usdcConvertedSoFar += usdcToConvert; 
    }

    //console.log(depositedInPlainUSD);
                      
    uint256 liquidityInUSDC = 
        LibUtils._convertFromDecimalsToDecimals(depositedInPlainUSD, LibStorage.PLAIN_USD_DECIMALS, LibStorage.USDC_DECIMALS);

    // Avoids to report more liquidity than the function parameter amountUSDC.
    // This must stop any manipulation.
    if(liquidityInUSDC > amountUSDC) {
      depositedInPlainUSD = 
        LibUtils._convertFromDecimalsToDecimals(amountUSDC, LibStorage.USDC_DECIMALS, LibStorage.PLAIN_USD_DECIMALS);
    }

    uint256 amount1USDToMint = 
      LibUtils._convertFromDecimalsToDecimals(depositedInPlainUSD, LibStorage.PLAIN_USD_DECIMALS, LibStorage.ONE_USD_DECIMALS);
    
    //console.log(amount1USDToMint);
    //console.log(minimum1USDTokens);
    LibRequirements.enforceValidMinting(amount1USDToMint, minimum1USDTokens);

    return amount1USDToMint;
  }

  /// @notice Withdraw from the strategies an amount of USDC denpending on the 1USD amount.
  /// @dev The contract checks if it has enough USDC. If not, the contract uses the function withdrawWithDistribution, 
  /// to withdraw the USDC needed from the strategies.
  /// @param oneUSDAmount, the total of 1USD equivalent to the USDC to withdraw.
  /// @return the total USDC withdrawed.
  /// Security Considerations: This function transfers USDC to 'owner' based on the returned value of the internal call
  /// of _withdrawWithDistribution, but this function can return a manipulated value (check _withdrawWithDistribution for more details).
  /// Given that, this function must prevent than any manipulation harm the contract or the user.
  /// To achieve that it prevents to transfer less USDC than a minimum (to protec the user).
  /// and it prevents transfering more USDC than the equivalent of the parameter oneUSDAmount transformed to usdc.
  function _withdraw(address owner, uint256 oneUSDAmount) internal returns(uint256) {
    // Ideally the contract will give USDC 1:1 with the 1USD burned
    uint256 usdcToWithdraw = 
        LibUtils._convertFromDecimalsToDecimals(oneUSDAmount, LibStorage.ONE_USD_DECIMALS, LibStorage.USDC_DECIMALS);

    uint256 contractBalance = LibUtils._balanceOfERC20(LibStorage.USDC_CONTRACT, address(this));

    if(contractBalance >= usdcToWithdraw) {
      LibUtils._transferERC20(LibStorage.USDC_CONTRACT, owner, usdcToWithdraw);
      return usdcToWithdraw;
    }

    // We cannot get less amount of USDC than this amount.
    uint256 minimumUSDCToWithdraw = _getMinimumAmount(usdcToWithdraw); 

    uint256 usdcMissing = usdcToWithdraw - contractBalance;
    
    // Withdraw 0.5% more
    uint256 usdcReceived = _withdrawWithDistribution((usdcMissing * 1005) / 1000);
    
    uint256 usdcToSendToUser = contractBalance + usdcReceived;

    // This avoids any manipulation that could happen
    if(usdcToSendToUser > usdcToWithdraw) {
      usdcToSendToUser = usdcToWithdraw;
    }

    LibRequirements.enforceValidWithdraw(usdcToSendToUser, minimumUSDCToWithdraw);
    LibUtils._transferERC20(LibStorage.USDC_CONTRACT, owner, usdcToSendToUser);

    return usdcToSendToUser;
  }

  /// @notice Asks every strategy accordingly to each allocation to withdraw USDC.
  /// @param amountUSDC the total of USDC to be withdrawed.
  /// @return the total USDC withdrawed.
  /// Security Considerations: This function call withdrawUSDC through a delegatecall.
  /// withdrawUSDC returns the amount of USDC that each strategy withdrawed, but this returned value
  /// can be manipulated (check MasterChefStrategy.withdrawUSDC for more details).
  /// Short Story: MasterChefStrategy.withdrawUSDC does nothing to prevent any manipulation to  happen.
  /// Given that, this functiona also does not any to prevent the manipulation, so it will bubble up to the function
  /// that called _withdrawWithDistribution.
  function _withdrawWithDistribution(uint256 amountUSDC) internal returns(uint256) {
    uint256 totalUSDCWithdrawed;
    uint256 totalUSDCToBeWithdrawed = amountUSDC;

    uint256 amountStrategies = sms().numberOfStrategiesActive;

    for (uint256 index = 0; index < amountStrategies; index++) {
      bytes32 position = sms().activeStrategiesArray[index];
      Strategy storage strategyInfo = ios(position);
      
      // Total Allocation is always 100 for this function to be executed.
      uint256 amountUSDCToWithdrawFromThisStrategy = (amountUSDC * strategyInfo.allocation) / 100;

      if(index == amountStrategies - 1) {
        amountUSDCToWithdrawFromThisStrategy = totalUSDCToBeWithdrawed;
      }

      totalUSDCToBeWithdrawed -= amountUSDCToWithdrawFromThisStrategy;

      (bool success, bytes memory data) = strategyInfo.strategyAddress.delegatecall(
        abi.encodeWithSignature("withdrawUSDC(uint256)", 
          amountUSDCToWithdrawFromThisStrategy)
      );

      if(!success) {
        if (data.length == 0) revert();
        assembly {
            revert(add(32, data), mload(data))
        }
      }

      totalUSDCWithdrawed += abi.decode(data,(uint256));
    }

    return totalUSDCWithdrawed;
  }

  /// @notice Asks every strategy to send their rewards to the recipient.
  function _claimRewards(address recipient) internal {
    uint256 amountStrategies = sms().numberOfStrategiesActive;

    for (uint256 index = 0; index < amountStrategies; index++) {
      bytes32 position = sms().activeStrategiesArray[index];
      Strategy storage _strategyInfo = ios(position);

      (bool success, bytes memory data) = _strategyInfo.strategyAddress.delegatecall(
        abi.encodeWithSignature("withdrawRewardsToRecipient(address)",recipient));

      if(!success) {
        if (data.length == 0) revert();
        assembly {
            revert(add(32, data), mload(data))
        }
      } 
    }
  }

  /// @notice Given an amount, this function calculates the minimum amount given a slippage
  function _getMinimumAmount(uint256 amount) internal view returns(uint256) {
    return (amount * vs().slippage) / 1000;
  }
}