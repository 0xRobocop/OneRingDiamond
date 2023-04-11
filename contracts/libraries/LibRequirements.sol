// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {VaultStatus, LibStorage, VaultStorage, StrategyManagerStorage} from "./LibStorage.sol";

library LibRequirements {

  error Vault_Max_USDC_Limit();
  error Vault_Is_Not_Open();
  error Vault_Is_Not_Closed();
  error Vault_Invalid_Slippage();
  error Vault_Too_Much_Slippage();
  error Vault_Invalid_New_Max_USDC();
  error Vault_Token_Not_Supported();
  error Vault_Invalid_Withdrawal_Fee();
  error Vault_Zero_Address_Is_Invalid();
  error Vault_Invalid_Total_Allocation();
  error Vault_Cannot_Deposit_In_This_Block();
  error Vault_Cannot_Withdraw_In_This_Block();
  error StrategyManager_Invalid_Percentage();
  error StrategyManager_Invalid_New_Allocation();

  function vs() internal pure returns (VaultStorage storage) {
    return LibStorage.vaultStorage();
  }

  function sms() internal pure returns (StrategyManagerStorage storage) {
    return LibStorage.strategyManagerStorage();
  }

  function enforceVaultIsOpen() internal view {
    if(vs().status != VaultStatus.Open) revert Vault_Is_Not_Open();
  }

  function enforceVaultIsClosed() internal view {
    if(vs().status != VaultStatus.Closed) revert Vault_Is_Not_Closed();
  }

  function enforceIsValidMaxUSDC(uint256 newMaxUSDC) internal view {
    if(vs().maxUSDC > newMaxUSDC) revert Vault_Invalid_New_Max_USDC();
  }

  function enforceCapUSDC(uint256 deposit) internal view {
    if(vs().USDCDeposited + deposit > vs().maxUSDC) revert Vault_Max_USDC_Limit();
  }

  function enforceValidBlockForWithdraw() internal view {
    if(block.number < vs().lastBlockDepositWasCalled + 50) revert Vault_Cannot_Withdraw_In_This_Block();
  }

  function enforceValidBlockForDeposit() internal view {
    if(block.number < vs().lastBlockDepositWasCalled + 5) revert Vault_Cannot_Deposit_In_This_Block();
  }

  function enforceTokenIsEnabled(address token) internal view {
    if(!vs().isTokenEnabled[token]) revert Vault_Token_Not_Supported();
  }

  function enforceAddressIsNotZero(address account) internal pure {
    if(account == address(0)) revert Vault_Zero_Address_Is_Invalid();
  }

  /// @dev Valid Total Allocation must be 100%.
  function enforceValidTotalAllocation() internal view {
    if(sms().totalAllocation != 100) revert Vault_Invalid_Total_Allocation(); 
  }

  /// @dev This is used when activating a strategy
  /// this ensures tha the future total allocation is not greater than 100.
  function enforceAllocationIsValid(uint96 allocation) internal view {
    if((allocation + sms().totalAllocation) > 100) revert Vault_Invalid_Total_Allocation();  
  }

  /// @dev When changing the allocation of some strategy
  /// it ensures that the change will not break the invariant that totalAllocation must always be smaller or equal to 100.
  function enforceValidChangeAllocation(uint96 oldAllocation, uint96 newAllocation) internal view {
    uint96 pendingAlloc = sms().totalAllocation - oldAllocation;

    if(pendingAlloc + newAllocation > 100) revert StrategyManager_Invalid_New_Allocation(); 
  }

  function enforceValidMinting(uint256 amountToMint, uint256 minimumToMint) internal pure {
    if(amountToMint < minimumToMint) revert Vault_Too_Much_Slippage();
  }

  /// @dev slippage has units of 0.1%, this means that the denominator is 1,000.
  /// so the slippage cannot be greater than 1,000.
  /// and we also restrict the slippage to a max of 1% so it cannot be smaller than 990.
  function enforceValidSlippage(uint64 newSlippage) internal pure {
    if(newSlippage < 990 || newSlippage > 1000) revert Vault_Invalid_Slippage();
  }

  /// @dev withdrawal fee has unit of 0.01% this means that the denominator is 10,000.
  /// so a valid withdrawal fee cannot be greater than 10,000.
  /// nor smaller than 9800 that means that the largest withdrawal fee can be 2%.
  function enforceValidFee(uint64 newFee) internal pure {
    if(newFee < 9800 || newFee > 10000) revert Vault_Invalid_Withdrawal_Fee();
  }

  function enforceValidWithdraw(uint256 usdcWithdrawed, uint256 minimumUSDCToWithdraw) internal pure {
    if(usdcWithdrawed < minimumUSDCToWithdraw) revert Vault_Too_Much_Slippage();
  }

  /// @dev Percentage to withdraw from strategies has unit of 1%.
  /// so the allowable range is 1%-100% inclusive.
  function enforceValidPercentageToWithdraw(uint256 percentage) internal pure {
    if(percentage > 100 || percentage == 0) revert StrategyManager_Invalid_Percentage();
  }

}
