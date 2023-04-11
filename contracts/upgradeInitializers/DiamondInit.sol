// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import {LibDiamond} from "../libraries/LibDiamond.sol";
import { IDiamondLoupe } from "../interfaces/Diamond/IDiamondLoupe.sol";
import { IDiamondCut } from "../interfaces/Diamond/IDiamondCut.sol";
import { IERC173 } from "../interfaces/Diamond/IERC173.sol";
import { IERC165 } from "../interfaces/Diamond/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

contract DiamondInit {    
    using SafeERC20 for IERC20;

    enum VaultStatus {Closed,Open}

    struct Layout {
      string name;
      string symbol;
      uint8 decimals;
    }

    struct VaultStorage {
      uint64 slippage; 
      uint64 withdrawalFee;
      uint128 lastBlockDepositWasCalled; 
      VaultStatus status;    
      mapping(address => bool) dontChargeFee; 
      mapping(address => bool) isTokenEnabled; 
    }

    bytes32 internal constant STORAGE_SLOT = keccak256('solidstate.contracts.storage.ERC20Metadata');
    bytes32 constant VAULT_STORAGE_POSITION =  keccak256("onering.vault.storage");
   
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function vaultStorage() internal pure returns (VaultStorage storage vs) {
        bytes32 position = VAULT_STORAGE_POSITION;
        assembly {
            vs.slot := position
        }
    }

    // You can add parameters to this function in order to pass in 
    // data to set your own state variables
    function init() external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        Layout storage layout_ = layout();
        VaultStorage storage vs = vaultStorage();
        layout_.name = "1USD";
        layout_.symbol = "1USD";
        layout_.decimals = 18;
        vs.slippage = 995;
        vs.withdrawalFee = 9995;
        // add your own state variables 
        // EIP-2535 specifies that the `diamondCut` function takes two optional 
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface 
    }
}
