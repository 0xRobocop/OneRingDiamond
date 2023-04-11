// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IERC173 } from "../interfaces/Diamond/IERC173.sol";

contract OwnershipFacet is IERC173 {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.proposePotentialOwner(_newOwner);
    }

    function acceptOwnership() external {
        LibDiamond.enforceIsPotentialOwner();
        LibDiamond.setContractOwner(msg.sender);
    }

    function owner() external override view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    function potentialOwner() external view returns (address potential) {
        potential = LibDiamond.potentialOwner();
    }
}
