// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVelodromeRouter {
  struct route {
    address from;
    address to;
    bool stable;
  }

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    route[] calldata routes,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory);

  function addLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256, uint256, uint256);

  function removeLiquidity(
    address tokenA, 
    address tokenB,
    bool stable,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256, uint256);
}
