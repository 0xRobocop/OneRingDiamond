// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVelodromePair {
  function token0() external view returns(address);
  function token1() external view returns(address);
  function getReserves() external view returns(uint256, uint256, uint256);
}