// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {LibStorage, StrategyManagerStorage, Strategy} from "./LibStorage.sol";

library LibUtils {

  function sms() internal pure returns (StrategyManagerStorage storage) {
    return LibStorage.strategyManagerStorage();
  }

  function ios(bytes32 position) internal pure returns (Strategy storage) {
    return LibStorage.strategyStorage(position);
  }

  /// @notice Returns true if the strategy is currently being used to deposit user funds, it returns false otherwise.
  /// @dev If the strategy is active it must be at the array strategyToIndexAtArray at the Strategy Manager Storage.
  function _isStrategyActive(bytes32 strategyPosition) internal view returns(bool) {
    if(sms().numberOfStrategiesActive == 0) {
      return false;
    }
    
    uint256 supposedIndex = sms().strategyToIndexAtArray[strategyPosition];
    bytes32 supposedStrategyPosition = sms().activeStrategiesArray[supposedIndex];

    if(supposedStrategyPosition != strategyPosition) {
      return false;
    }

    return true;
  }

  /// @notice Returns true if the strategy has been created, it returns false otherwise.
  /// @dev If a strategy has been created it must have a pointer of where its contract logic is.
  function _hasStrategyBeenCreated(bytes32 strategyPosition) internal view returns(bool) {
    if(ios(strategyPosition).strategyAddress == address(0)) {
      return false;
    }

    return true;
  }
  
  /// @notice Changes the decimals of an amount.
  /// @dev amount must have at least (fromDecimals + 1) digits.
  /// this must be validated before calling this function.
  /// @param amount, the amount to change its decimals.
  /// @param fromDecimals, the original number of decimals that amount has.
  /// @param toDecimals, the decimals to convert amount to. 
  function _convertFromDecimalsToDecimals(uint256 amount, uint256 fromDecimals, uint256 toDecimals) 
    internal pure returns(uint256)
  {
    if (toDecimals >= fromDecimals) {
      return (amount * (10 ** (toDecimals - fromDecimals)));
    }

    else {
      return (amount) / (10 ** (fromDecimals - toDecimals));
    }
  }

  function _balanceOfERC20(address token, address account) internal view returns(uint256) {
    return IERC20(token).balanceOf(account);
  }

  /// @notice Make a safe transfer of amount of token to 'to'
  function _transferERC20(address token, address to, uint256 amount) internal {
    IERC20(token).transfer(to, amount);
  }

  /// @notice Make a safe transferFrom of amount of token from 'from' to 'to'
  function _transferFromERC20(address token, address from, address to, uint256 amount) internal {
    IERC20(token).transferFrom(from, to, amount);
  }
}