// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// The Diamond Storage Pattern is used

/// The storage of the Vault Configuration is saved in the struct VaultStorage at keccak256("onering.vault.storage")

/// The storage regarding the information of all the strategies is saved in the StrategyManagerStorage at
/// keccak256("onering.strategymanager.storage"). This part of the storage is used to iterate overall the active strategies
/// to deposit the user funds.

/// Each strategy will use the Strategy struct saved at keccak("onering." + {strategyType} + "." + {protocol} + "." + {tokensInvolved})
/// For example: keccak256("onering.masterchef.spirit.usdcfrax")

/// Because different variables ared needed depending on the type of the strategy, is expected that the strategies will have 
/// initialized only the variabled needed to work.

enum VaultStatus {Closed,Open}

struct VaultStorage {
  uint64 slippage; 
  uint64 withdrawalFee;
  uint128 lastBlockDepositWasCalled; 
  uint256 maxUSDC;
  uint256 USDCDeposited;
  VaultStatus status;    
  mapping(address => bool) dontChargeFee; 
  mapping(address => bool) isTokenEnabled; 
}

struct Strategy {
  address strategyAddress;
  uint96 allocation;
}

struct StrategyManagerStorage {
  uint96 totalAllocation;
  uint160 numberOfStrategiesActive;
  bytes32[] activeStrategiesArray;
  mapping(bytes32 => uint256) strategyToIndexAtArray;
}

library LibStorage {
  bytes32 constant VAULT_STORAGE_POSITION =  keccak256("onering.vault.storage");
  bytes32 constant STRATEGY_MANAGER_STORAGE_POSITION = keccak256("onering.strategymanager.storage");

  uint256 public constant ONE_USD_DECIMALS = 18;
  uint256 public constant PLAIN_USD_DECIMALS = 3;   
  uint256 public constant USDC_DECIMALS = 6;
  address public constant USDC_CONTRACT = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;    

  function vaultStorage() internal pure returns (VaultStorage storage vs) {
    bytes32 position = VAULT_STORAGE_POSITION;
    assembly {
      vs.slot := position
    }
  }

  function strategyManagerStorage() internal pure returns (StrategyManagerStorage storage sms) {
    bytes32 position = STRATEGY_MANAGER_STORAGE_POSITION;
    assembly {
      sms.slot := position
    }
  }

  function strategyStorage(bytes32 position) internal pure returns (Strategy storage ss) {
    assembly {
      ss.slot := position
    }
  }
}

/**
 * The `WithStorage` contract provides a base contract for Facet contracts to inherit.
 *
 * It mainly provides internal helpers to access the storage structs, which reduces
 * calls like `LibStorage.vaultStorage()` to just `vs()`.
 *
 */

contract WithStorage {
  function vs() internal pure returns (VaultStorage storage) {
    return LibStorage.vaultStorage();
  }

  function sms() internal pure returns (StrategyManagerStorage storage) {
    return LibStorage.strategyManagerStorage();
  }

  function ios(bytes32 position) internal pure returns(Strategy storage) {
    return LibStorage.strategyStorage(position);
  }
}
  