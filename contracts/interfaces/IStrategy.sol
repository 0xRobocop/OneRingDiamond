// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
                          
  function usdcToUnderlyingAndInvest(uint256 amount) external returns(uint256);

  function withdrawUSDC(uint256 amountUSDC) external returns(uint256); 

  function withdrawRewardsToRecipient(address recipient) external;

  function exitAndSendToRecipient(address recipient) external;

  function investUnderlying(uint256 amount) external;

  function withdrawPercentage(address recipient, uint256 percentage) external; 
}