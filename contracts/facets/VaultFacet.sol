// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@solidstate/contracts/token/ERC20/SolidStateERC20.sol";

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {WithStorage} from "../libraries/LibStorage.sol";
import {LibVault} from "../libraries/LibVault.sol";
import {LibRequirements} from "../libraries/LibRequirements.sol";

/// Security Considerations: OneRing is conscious on the high centralization of the contract,
/// and on the front running opportunities the owner of the contract has on the change of the configuration of the contract.
/// (NOTE: Only front running opportunities by the owner are accepted, please report if an arbitrary user can benefit from front running).

/// To mitigate the centralization risk of losing the control of the ownership, 
/// one ring will transfer the ownership to a multisig contract.

/// The Diamond Pattern will allow One Ring in the future to evolve into a more decentralized system and add more strategy types.

contract VaultFacet is WithStorage, SolidStateERC20 {

  event RewardsWithdrawed(address recipient);
  event Redeem(address sender, address owner, uint256 usdcWithdrawed, uint256 oneUSDRedeem);
  event Deposit(
    address sender, 
    address recipient, 
    address token, 
    uint256 amountDeposited, 
    uint256 oneUSDMinted, 
    uint256 blockNumber
  );

  error Vault_Not_Enough_Allowance();
  
  /// @notice Validates the requirements to do a deposit
  /// invokes the function _swapTokenToUSDC to convert the token deposited to USDC.
  /// and then invest the usdc accross all the active strategies (through _deposit) and mint 1USD accordingly.
  /// @dev Should allow to designate a recipient different from msg.sender. 
  /// @param token, the address of the token being deposited, it must be a stable coin (this is controlled by a whitelist).
  /// @param recipient, the address of where to mint 1USD tokens.
  /// @param amountToDeposit, the quantity of tokens being deposited. These are transferred from the msg.sender not from recipient. 
  /// @return The quantity of 1USD minted to recipient.
  /// Security Considerations: LibVault._swapTokenToUSDC --> Read it on the library LibVault.
  /// LibVault._deposit --> This function must return a valid amount of 1USD to mint. No less than a minimum (to protect the user).
  /// No more than the USDC gotten from converting 'token' to USDC (to protect the contract).
  function deposit(address token, address recipient, uint256 amountToDeposit) external returns(uint256) {
    LibRequirements.enforceAddressIsNotZero(recipient);
    LibRequirements.enforceTokenIsEnabled(token);
    LibRequirements.enforceVaultIsOpen();
    LibRequirements.enforceValidTotalAllocation();
    LibRequirements.enforceValidBlockForDeposit();
    LibRequirements.enforceCapUSDC(amountToDeposit);

    vs().USDCDeposited += amountToDeposit;
    
    uint256 totalAmountUSDC = LibVault._swapTokenToUSDC(token, amountToDeposit);
    uint256 amount1USDToMint = LibVault._deposit(totalAmountUSDC);
    _mint(recipient, amount1USDToMint);

    emit Deposit(msg.sender, recipient, token, totalAmountUSDC, amount1USDToMint, block.number);

    return amount1USDToMint;
  }

  /// @notice Burns owner's 1USD for USDC.
  /// @dev A user can give permission to other accounts to burn his 1USD.
  /// @param owner, the address who owns the 1USD to be burned.
  /// @param oneUSDAmount, the amount of 1USD to be burned. 
  /// @return The amount of USDC that was sent to user.
  /// Security Consideration: No one should be allowed to call redeem behalf other account, unless they are approved to do so.
  /// LibVault._withdraw --> This function returns the amount of USDC that was sent to the user 
  /// (the transfer happen inside LibVault._withdraw),
  /// this value must be no less than a minimum (to protect the user), 
  /// and no more than the equivalent of USDC in 1USD (1USD is 1:1 with the dollar), (to protect the contract).
  function redeem(address owner, uint256 oneUSDAmount) external returns(uint256) {
    LibRequirements.enforceAddressIsNotZero(owner);
    LibRequirements.enforceVaultIsOpen();
    LibRequirements.enforceValidTotalAllocation();
    LibRequirements.enforceValidBlockForWithdraw();
    
    if(msg.sender != owner) {
      uint256 currentAllowance = _allowance(owner, msg.sender);
      if(currentAllowance < oneUSDAmount) {
        revert Vault_Not_Enough_Allowance();
      }
      _approve(owner, msg.sender, currentAllowance - oneUSDAmount);
    }

    uint256 usdcSendToUser;

    if(vs().dontChargeFee[owner]) {
      _burn(owner, oneUSDAmount);

      usdcSendToUser = LibVault._withdraw(owner, oneUSDAmount);
    }

    else {
       uint256 oneUSDWithdrawalFee = (oneUSDAmount * vs().withdrawalFee) / 10000;

      /// Take withdrawal fee in the form of 1USD
      _transfer(owner, address(this), oneUSDAmount - oneUSDWithdrawalFee);

      _burn(owner, oneUSDWithdrawalFee);
    
      usdcSendToUser = LibVault._withdraw(owner, oneUSDWithdrawalFee);
    }

    vs().USDCDeposited -= usdcSendToUser;
    
    emit Redeem(msg.sender, owner, usdcSendToUser, oneUSDAmount);

    return usdcSendToUser; 
  }

  /// @notice Withdraw all the rewards and send them to recipient.
  function claimRewards(address recipient) external {
    LibDiamond.enforceIsContractOwner();
    LibRequirements.enforceAddressIsNotZero(recipient);

    LibVault._claimRewards(recipient);

    emit RewardsWithdrawed(recipient);
  } 
}