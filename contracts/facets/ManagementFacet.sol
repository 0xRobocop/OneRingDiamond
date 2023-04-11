// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {VaultStatus,WithStorage,Strategy} from "../libraries/LibStorage.sol";
import {LibUtils} from "../libraries/LibUtils.sol";
import {LibManagement} from "../libraries/LibManagement.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibRequirements} from "../libraries/LibRequirements.sol";

import "../VelodromeStrategy.sol";

contract ManagementFacet is WithStorage {

  address public constant USDC_CONTRACT = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
  address public constant VELODROME_ROUTER = 0x9c12939390052919aF3155f41Bf4160Fd3666A6f;

  event StatusChanged(VaultStatus newStatus);
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

  error Management_Strategy_Is_Not_Active();
  error Management_Strategy_Has_Been_Created();
  error Management_Strategy_Is_Already_Active();
  error Management_Strategy_Has_Not_Been_Created();
  error Management_New_Allocation_Cannot_Be_Zero();
  /////////////////////////////////////////// Functions to manage the Vault Storage ////////////////////////////////////////////////////
  function changeStatus(VaultStatus newStatus) external {
    LibDiamond.enforceIsContractOwner();
    
    LibManagement._changeStatus(newStatus);
  }

  function changeMaxUSDC(uint256 newMax) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceIsValidMaxUSDC(newMax);

    LibManagement._changeMaxUSDC(newMax);

  }
  
  function changeSlippage(uint64 newSlippage) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceValidSlippage(newSlippage);

    LibManagement._changeSlippage(newSlippage);
  }

  function changeWithdrawalFee(uint64 newFee) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceValidFee(newFee);

    LibManagement._changeWithdrawalFee(newFee);
  }

  function enableTokens(address[] calldata tokens, bool truthValue) external {
    LibDiamond.enforceIsContractOwner();  

    LibManagement._enableTokens(tokens, truthValue);
  }

  function whitelistAddress(address account, bool truthValue) external {
    LibDiamond.enforceIsContractOwner(); 

    LibManagement._whitelistAddress(account, truthValue);
  }

  function approveERC20sSpender(address[] calldata tokens, address spender) external {
    LibDiamond.enforceIsContractOwner();  
 
    LibManagement._approveERC20sSpender(tokens, spender);
  }

  function withdrawERC20(address erc20Contract, address recipient) external {
    LibDiamond.enforceIsContractOwner();  
    LibRequirements.enforceAddressIsNotZero(recipient);

    LibManagement._withdrawERC20(erc20Contract, recipient);
  }

  ///////////////////////////////////////// These are functions to manage any type of strategy ///////////////////////////////////////////
  
  /// @notice Activates a given strategy.
  /// Activation means to add the strategy to the array of active strategies
  /// so it can recieve user funds accordingly with the allocation given.
  /// @param allocation, the percentage of the total deposit to be send to this strategy.
  /// @param position, the storage position of the strategy to be activated.
  /// Security Considerations: Only strategies that have been created can be activated,
  /// and the same strategy cannot be twice at the active strategies array (activated again without been deactivated before).
  /// The allocation given to this strategy must be valid, that means that when added to the totalAllocation, the new totalAllocation
  /// cannot be greater than 100%.
  function activateStrategy(uint96 allocation, bytes32 position) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceAllocationIsValid(allocation);
    LibRequirements.enforceVaultIsClosed();
    
    if(!LibUtils._hasStrategyBeenCreated(position)) {
      revert Management_Strategy_Has_Not_Been_Created();
    }

    if(LibUtils._isStrategyActive(position)) {
      revert Management_Strategy_Is_Already_Active();
    }

    LibManagement._activateStrategy(allocation, position);
  }

  /// @notice Deactivate a given strategy and send all the funds to recipient.
  /// Deactivation means to remove the strategy from the active strategies array
  /// that means that it wont longer recieve user funds.
  /// Security Considerations: Only activated strategies can be deactivated,
  /// when deactivating the strategy all the funds including rewards must be send to recipient,
  /// and the allocation of the strategy must be set to zero.
  function deActivateStrategy(address recipient, bytes32 position) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceAddressIsNotZero(recipient);
    LibRequirements.enforceVaultIsClosed();
    
    if(!LibUtils._isStrategyActive(position)) {
      revert Management_Strategy_Is_Not_Active();
    }

    LibManagement._deActivateStrategy(recipient, position);
  }

  /// @notice Deposit an amount of underlying to a given strategy and invest it.
  /// @dev This is used when migrating to other strategies or adjusting to new allocations.
  function depositUnderlyingToStrategy(uint256 amountUnderlying, bytes32 position) external {
    LibDiamond.enforceIsContractOwner();

    LibManagement._depositUnderlyingToStrategy(amountUnderlying, position);
  }

  /// @notice Withdraws a percentage of the underlying of a given strategy.
  /// @dev This is used when migrating to other strategies or adjusting to new allocations.
  /// @param recipient, account to send the underlying withdrawed.
  /// @param percentage, the percentage to be withdrawed.
  /// @param position, position of the strategy in storage following the Diamond Storage Pattern.
  function withdrawPercentageFromStrategy(address recipient, uint256 percentage, bytes32 position) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceAddressIsNotZero(recipient);
    LibRequirements.enforceValidPercentageToWithdraw(percentage);
    LibRequirements.enforceVaultIsClosed();

    LibManagement._withdrawPercentageFromStrategy(recipient, percentage, position);
  }

  /// @notice Change the contract address of the logic of a given strategy.
  /// @param newStrategyLogic, the new logic of the strategy.
  /// @param position, position of the strategy in storage following the Diamond Storage Pattern.
  /// Security Considerations: This only can be done to strategies that have been created,
  /// and changing the logic for that strategy must not stop the correct functionality of this contract (when activated), 
  /// if it conforms to the corresponded interface and is implemented correctly
  function changeStrategyAddressLogic(address newStrategyLogic, bytes32 position) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceAddressIsNotZero(newStrategyLogic);

    if(!LibUtils._hasStrategyBeenCreated(position)) {
      revert Management_Strategy_Has_Not_Been_Created();
    }

    LibManagement._changeStrategyAddressLogic(newStrategyLogic, position);
  }

  /// @notice Change the allocation of a given strategy.
  /// @dev If the total allocation is 100%,
  /// then newAllocation < currentAllocation.
  /// @param newAllocation, the new allocation of the strategy.
  /// @param position of the strategy in storage following the Diamond Storage Pattern.
  function changeAllocationOfStrategy(uint96 newAllocation, bytes32 position) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceVaultIsClosed();

    uint96 oldAllocation = ios(position).allocation;

    /// If you want to set it to zero, use the deactivate function.
    if(newAllocation == 0) {
      revert Management_New_Allocation_Cannot_Be_Zero();
    }

    // The change of allocation is only possible on active strategies.
    if(!LibUtils._isStrategyActive(position)) {
      revert Management_Strategy_Is_Not_Active();
    }

    // Not all changes are valid.
    LibRequirements.enforceValidChangeAllocation(oldAllocation, newAllocation);

    LibManagement._changeAllocationOfStrategy(oldAllocation, newAllocation, position);
  }

  /////////////////////////////////// These are functions to manage the velodrome strategy type /////////////////////////////////////
  function createVelodromeStrategy (
    bytes32 position,
    address token1,
    address lpToken,
    address lpGauge,
    uint256 poolID
  ) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceAddressIsNotZero(token1);
    LibRequirements.enforceAddressIsNotZero(lpToken);
    LibRequirements.enforceAddressIsNotZero(lpGauge);

    if(LibUtils._hasStrategyBeenCreated(position)) {
      revert Management_Strategy_Has_Been_Created();
    }

    VelodromeStrategy logicAddress = new VelodromeStrategy(token1, lpToken, lpGauge, poolID);

    LibManagement._createVelodromeStrategy(
      position, address(logicAddress), lpToken, lpGauge, VELODROME_ROUTER, USDC_CONTRACT, token1);
  }
} 

