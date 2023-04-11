// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IVelodromePair.sol";

import {VaultStatus, LibStorage, VaultStorage, StrategyManagerStorage, Strategy} from "./LibStorage.sol";
import {LibUtils} from "./LibUtils.sol";

library LibManagement {
  event StatusChanged(VaultStatus newStatus);
  event MaxUSDCChanged(uint256 newMax);
  event TokenEnabled(address token, bool truthValue);
  event AccountWhitelisted(address account, bool truthValue);
  event WithdrawalFeeChanged(uint64 oldFee, uint64 newFee);
  event StrategyLogicChanged(bytes32 position, address oldStrategyLogic, address newLogic);
  event AllocationChanged(bytes32 position, uint96 oldAllocation, uint96 newAllocation); 
  event UnderlyingDepositedToStrategy(bytes32 position, uint256 amountUnderlying);
  event ERC20FundsWithdrawed(address erc20Contract, uint256 balance);
  event SlippageChanged(uint64 oldSlippage, uint64 newSlippage);
  event StrategyDeActivated(bytes32 position, address recipient);
  event StrategyActivated(bytes32 position, uint96 _allocation);
  event PercentageWithdrawed(bytes32 position, address recipient, uint256 percentage);
  event VelodromeStrategyCreated(bytes32 position, address strategyLogicAddress, address lpToken);

  function vs() internal pure returns (VaultStorage storage) {
    return LibStorage.vaultStorage();
  }

  function sms() internal pure returns (StrategyManagerStorage storage) {
    return LibStorage.strategyManagerStorage();
  }

  function ios(bytes32 position) internal pure returns (Strategy storage) {
    return LibStorage.strategyStorage(position);
  }

  /////////////////////////////////////////////////// Management of the Vault storage //////////////////////////////////////////////////////

  function _changeStatus(VaultStatus newStatus) internal {
    vs().status = newStatus;

    emit StatusChanged(newStatus);
  }

  function _changeMaxUSDC(uint256 newMax) internal {
    vs().maxUSDC = newMax;

    emit MaxUSDCChanged(newMax);
  }

  function _changeSlippage(uint64 newSlippage) internal {
    uint64 oldSlippage = vs().slippage;
    vs().slippage = newSlippage;
    
    emit SlippageChanged(oldSlippage, newSlippage);
  }

  function _changeWithdrawalFee(uint64 newFee) internal {
    uint64 oldFee = vs().withdrawalFee;
    vs().withdrawalFee = newFee;

    emit WithdrawalFeeChanged(oldFee, newFee);
  }

  function _enableTokens(address[] calldata tokens, bool truthValue) internal {
    if(truthValue) {
      for (uint256 i = 0; i < tokens.length; i++) {
        vs().isTokenEnabled[tokens[i]] = true;
        emit TokenEnabled(tokens[i], truthValue);
      }
    }

    if(!truthValue) {
      for (uint256 i = 0; i < tokens.length; i++) {
        vs().isTokenEnabled[tokens[i]] = false;
        emit TokenEnabled(tokens[i], truthValue);
      }
    }
  }

  function _whitelistAddress(address account, bool truthValue) internal {
    vs().dontChargeFee[account] = truthValue;

    emit AccountWhitelisted(account, truthValue);
  }

  function _approveERC20sSpender(address[] calldata tokens, address spender) internal {
    for (uint256 i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).approve(spender, type(uint256).max);
    }
  }

  function _withdrawERC20(address erc20Contract, address recipient) internal {
    uint256 balance = LibUtils._balanceOfERC20(erc20Contract, address(this));

    LibUtils._transferERC20(erc20Contract, recipient, balance);
    
    emit ERC20FundsWithdrawed(erc20Contract, balance);
  }
  //////////////////////////////////////////////////// Management of Any Type Of Strategy //////////////////////////////////////////////////

  /// @dev Activate a strategy means to put it on the array of active strategies.
  /// and grant it a given allocation.
  function _activateStrategy(uint96 _allocation, bytes32 position) internal {
    sms().totalAllocation += _allocation;
    sms().activeStrategiesArray.push(position);
    sms().numberOfStrategiesActive += 1;
    sms().strategyToIndexAtArray[position] = sms().numberOfStrategiesActive - 1;

    ios(position).allocation = _allocation;

    emit StrategyActivated(position, _allocation);
  }

  /// @dev Deactivation of a strategy means to withdraw all the underlying and all the rewards, send them to recipient.
  /// and the removing the strategy from the active strategies.
  function _deActivateStrategy(address recipient, bytes32 position) internal {
    Strategy storage strategyInfo = ios(position);

    (bool success, bytes memory data) = strategyInfo.strategyAddress.delegatecall(
      abi.encodeWithSignature("exitAndSendToRecipient(address)", recipient));

    if(!success) {
      if (data.length == 0) revert();
      assembly {
        revert(add(32, data), mload(data))
      }
    }
  
    _removeStrategy(position);

    emit StrategyDeActivated(position, recipient);
  }

  /// @dev It does a delegatecall to the logic of the given strategy, then the strategy invest the underlying.
  function _depositUnderlyingToStrategy(uint256 amountUnderlying, bytes32 position) internal {
    Strategy storage strategyInfo = ios(position);
    
    (bool success, bytes memory data) = strategyInfo.strategyAddress.delegatecall(
      abi.encodeWithSignature("investUnderlying(uint256)",amountUnderlying)
    );

    if(!success) {
      if (data.length == 0) revert();
      assembly {
        revert(add(32, data), mload(data))
      }
    }

    emit UnderlyingDepositedToStrategy(position, amountUnderlying);
  }
  
  /// @dev It removes a given strategy, it swaps the last strategy with the strategy that is going to be removed.
  /// then it just pop the last item of the array.
  function _removeStrategy(bytes32 position) internal {
    uint256 index = sms().strategyToIndexAtArray[position];

    uint256 lastIndex = sms().numberOfStrategiesActive - 1;

    bytes32 lastStrategy = sms().activeStrategiesArray[lastIndex];

    // Last strategy is put at the place of the strategy to remove
    sms().activeStrategiesArray[index] = lastStrategy;
    sms().strategyToIndexAtArray[lastStrategy] = index;

    sms().activeStrategiesArray.pop();
    sms().numberOfStrategiesActive -= 1;
    sms().totalAllocation -= ios(position).allocation;
    
    ios(position).allocation = 0;
    
    delete sms().strategyToIndexAtArray[position];
  }

  /// @dev It makes a delegatecall to the logic of a given strategy, asking to withdraw a given percentage of underlying.
  /// the underlying will be send to recipient.
  function _withdrawPercentageFromStrategy(address recipient, uint256 percentage, bytes32 position) internal {
    Strategy storage strategyInfo = ios(position);

    (bool success, bytes memory data) = strategyInfo.strategyAddress.delegatecall(
      abi.encodeWithSignature("withdrawPercentage(address,uint256)",recipient,percentage)
    );

    if(!success) {
      if (data.length == 0) revert();
      assembly {
        revert(add(32, data), mload(data))
      }
    }

    emit PercentageWithdrawed(position, recipient, percentage);
  }

  function _changeStrategyAddressLogic(address newLogic, bytes32 position) internal {
    address oldStrategyLogic = ios(position).strategyAddress;

    ios(position).strategyAddress = newLogic;

    emit StrategyLogicChanged(position, oldStrategyLogic, newLogic);
  }
  
  /// @dev For totalAllocation to not exceed 100%, the newAllocation parameter is validated before calling
  /// this function.
  function _changeAllocationOfStrategy(uint96 oldAllocation, uint96 newAllocation, bytes32 position) internal {
    sms().totalAllocation -= oldAllocation;
    sms().totalAllocation += newAllocation;

    ios(position).allocation = newAllocation;

    emit AllocationChanged(position, oldAllocation, newAllocation); 
  }

  //////////////////////////////////////////////////// Management of MasterChef Strategies /////////////////////////////////////////////////

  function _createVelodromeStrategy(
    bytes32 position,
    address strategyLogicAddress,
    address lpToken,
    address lpGauge,
    address dexRouter,
    address token0,
    address token1
  ) internal {
      ios(position).strategyAddress = strategyLogicAddress;

      // DexRouter only needs approval for the LP Token and the tokens that made the LP token.
      IERC20(lpToken).approve(dexRouter, type(uint256).max);
      IERC20(token0).approve(dexRouter, type(uint256).max);
      IERC20(token1).approve(dexRouter, type(uint256).max);
      
      // Gauge Contract only needs approval for the LP Token
      IERC20(lpToken).approve(lpGauge, type(uint256).max);

      emit VelodromeStrategyCreated(position, strategyLogicAddress, lpToken);
  }
}



    