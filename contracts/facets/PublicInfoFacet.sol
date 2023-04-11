// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {VaultStatus,WithStorage,LibStorage,Strategy} from "../libraries/LibStorage.sol";
import {LibUtils} from "../libraries/LibUtils.sol";
import {LibVelodrome} from "../libraries/LibVelodrome.sol";

/// Facet only meant to be used by off-chain user to gather information about the contract //

contract PublicInfoFacet is WithStorage {
  /////////////////////////////////////////////////////////// Vault Storage Info //////////////////////////////////////////////
  function getStatus() external view returns(VaultStatus) {
    return vs().status;
  }

  function getSlippage() external view returns(uint64) {
    return vs().slippage;
  }

  function getWithdrawalFee() external view returns(uint64) {
    return vs().withdrawalFee;
  }

  function getLastBlockDepositWasCalled() external view returns(uint128) {
    return vs().lastBlockDepositWasCalled;
  }

  function getIfFeeCharged(address account) external view returns(bool) {
    return vs().dontChargeFee[account];
  }

  function getIfTokenEnabled(address token) external view returns(bool) {
    return vs().isTokenEnabled[token];
  }

  ////////////////////////////////////////////////////// Strategy Manager Storage Info //////////////////////////////////////////
  
  function getTotalAllocation() external view returns(uint96) {
    return sms().totalAllocation;
  }

  function getNumberOfStrategies() external view returns(uint160) {
    return sms().numberOfStrategiesActive;
  }

  function getStrategyPosition(uint256 index) external view returns(bytes32) {
    return sms().activeStrategiesArray[index];
  }

  function getIndexOfStrategy(bytes32 strategyPosition) external view returns(uint256) {
    return sms().strategyToIndexAtArray[strategyPosition];
  }

  ///////////////////////////////////////////////////// Any Strategy Type Info //////////////////////////////////////////////////////
  function getAllocationOfStrategy(bytes32 strategyPosition) external view returns(uint96) {
    return ios(strategyPosition).allocation;
  }

  function getStrategyAddressLogic(bytes32 strategyPosition) external view returns(address) {
    return ios(strategyPosition).strategyAddress;
  }

  // @notice Checks if the given strategy is active (If the vaul is using it to deposit user's funds)
  function isStrategyActive(bytes32 strategyPosition) external view returns(bool) {
    return LibUtils._isStrategyActive(strategyPosition);
  }

  // @notice Check if the given strategy have already been initilized (it can be an active strategy or an inactive one).
  function hasStrategyBeenCreated(bytes32 strategyPosition) external view returns(bool) {
    return LibUtils._hasStrategyBeenCreated(strategyPosition);
  }

  function calculatePositionForStrategy(string calldata chain, string calldata protocol, string calldata tokensInvolved) 
    external pure returns(bytes32) 
  {
    bytes memory stringPosition = abi.encodePacked("onering.",chain,".",protocol,".",tokensInvolved); 
    return keccak256(stringPosition); 
  }

  ///////////////////////////////////////////////////// Velodrome Strategy Type Info //////////////////////////////////////////////////////
  /// @notice Returns the LP balance invested in a given masterchef strategy
  function getLPBalanceAtSpiritswapV2Strategy(address lpGauge) external view returns(uint256) {
    return LibVelodrome._getLPBalance(lpGauge);
  } 

  /// @notice Return the PLAIN_USD value invested in a given masterchef strategy
  function getPlainUSDInvestedAtSpiritswapV2Strategy(address lpGauge, address lpToken, uint256 token1Decimals) external view returns(uint256) {
    return LibVelodrome._getPlainUSDInvestedAtStrategy(lpGauge, lpToken, 6, token1Decimals);
  } 
}