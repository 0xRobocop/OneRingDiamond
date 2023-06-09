// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVelodromeGauge {
  function deposit(uint256 amount, uint256 tokenId) external;
  function getReward(address account, address[] memory tokens) external;
  function withdraw(uint256 amount) external;
  function balanceOf(address account) external view returns (uint256);
}