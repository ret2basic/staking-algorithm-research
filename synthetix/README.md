# Synthetix StakingRewards Foundry Project

Minimal Foundry setup for researching the Synthetix staking algorithm.

## Structure

```
synthetix/
├── src/
│   ├── StakingRewards.sol              # Main staking contract
│   ├── Owned.sol                       # Ownership contract
│   ├── Pausable.sol                    # Pausable functionality
│   ├── RewardsDistributionRecipient.sol # Rewards distribution
│   └── interfaces/
│       └── IStakingRewards.sol         # Interface
├── test/
│   └── StakingRewards.t.sol            # Test file
├── lib/                                 # Dependencies (OpenZeppelin, forge-std)
├── foundry.toml                         # Foundry configuration
└── remappings.txt                       # Import remappings
```

## Dependencies

- OpenZeppelin Contracts v2.3.0 (Solidity 0.5.x compatible)
- Forge Standard Library

## Building

```bash
forge build --skip test
```

**Note:** Forge-std doesn't support Solidity 0.5.16, so skip the test directory during build.

## Testing

Not available with standard forge-std due to Solidity version constraints. Consider upgrading the contracts to Solidity 0.8.x for testing support.

## Key Contracts

- **StakingRewards.sol**: Implements time-weighted reward distribution
- **Owned.sol**: Ownership pattern from Synthetix
- **Pausable.sol**: Emergency pause functionality
- **RewardsDistributionRecipient.sol**: Manages reward notifications

## Research Focus

The StakingRewards contract uses a time-weighted reward mechanism:
- `rewardPerToken`: Calculates accumulated rewards per token over time
- `rewardRate`: Rewards distributed per second
- `periodFinish`: End time for the current reward period
- Formula: `earned = (balance * (rewardPerToken - userRewardPerTokenPaid)) + rewards[account]`

