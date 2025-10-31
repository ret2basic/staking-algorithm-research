# MasterChef Foundry Project

Minimal Foundry setup for researching the MasterChef staking algorithm.

## Structure

```
masterchef/
├── src/
│   ├── MasterChef.sol      # Main MasterChef staking contract
│   └── SushiToken.sol      # Reward token contract
├── test/
│   └── MasterChef.t.sol    # Test file
├── lib/                     # Dependencies (OpenZeppelin, forge-std)
├── foundry.toml             # Foundry configuration
└── remappings.txt           # Import remappings
```

## Dependencies

- OpenZeppelin Contracts v3.4.0 (Solidity 0.6.x compatible)
- Forge Standard Library

## Building

```bash
forge build --skip test
```

**Note:** Due to Solidity 0.6.12 limitations with forge-std, skip the test directory during build.

## Key Contracts

- **MasterChef.sol**: Implements the reward distribution algorithm using per-share accounting
- **SushiToken.sol**: ERC20 token that can be minted by MasterChef

## Research Focus

The MasterChef contract uses a "rewardDebt" accounting mechanism to track rewards:
- `accSushiPerShare`: Accumulated rewards per staked token
- `rewardDebt`: User's debt, used to calculate pending rewards
- Formula: `pending = (user.amount * pool.accSushiPerShare) - user.rewardDebt`

