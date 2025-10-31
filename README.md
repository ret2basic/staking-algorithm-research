# Staking Algorithm Research

Research on MasterChef and Synthetix staking algorithms with Foundry projects.

## Project Structure

This repository contains two independent Foundry projects:

### 1. MasterChef (`masterchef/`)
- **Solidity Version:** 0.6.12
- **Main Contract:** `MasterChef.sol`
- **Algorithm:** Per-share accounting with reward debt mechanism
- **Build:** `cd masterchef && forge build --skip test`

### 2. Synthetix StakingRewards (`synthetix/`)
- **Solidity Version:** 0.5.16
- **Main Contract:** `StakingRewards.sol`
- **Algorithm:** Time-weighted reward distribution
- **Build:** `cd synthetix && forge build --skip test`

## Quick Start

Each directory is a self-contained Foundry project:

```bash
# MasterChef
cd masterchef
forge build --skip test

# Synthetix
cd synthetix
forge build --skip test
```

## Algorithm Comparison

### MasterChef
- Uses accumulator pattern with `accSushiPerShare`
- Tracks user reward debt to calculate pending rewards
- Suitable for variable reward rates and multiple pools
- Formula: `pending = (user.amount * pool.accSushiPerShare) - user.rewardDebt`

### Synthetix
- Uses time-weighted rewards with `rewardPerToken`
- Distributes rewards over a fixed period
- Suitable for periodic reward distributions
- Formula: `earned = (balance * (rewardPerToken - userRewardPerTokenPaid)) + rewards[account]`

## Notes

Both projects use older Solidity versions (0.6.12 and 0.5.16) to maintain compatibility with the original implementations. Due to forge-std requirements, tests are not fully compatible with these versions. For testing, consider upgrading contracts to Solidity 0.8.x or use alternative testing frameworks.

