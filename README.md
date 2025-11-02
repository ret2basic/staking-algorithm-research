# Staking Algorithm Research

This repo is a companion for https://rareskills.io/post/staking-algorithm. The goal is to understanding MasterChef and Synthetix staking algorithms in depth and compare the differences between them.

## MasterChef staking algorithm

MasterChef distributes a fixed emission of rewards across many liquidity pools without looping over every staker. Each pool keeps an `accRewardPerShare` accumulator scaled by `1e12`. Whenever someone deposits or withdraws, the contract “catches up” emissions by multiplying the blocks elapsed since `lastRewardBlock` by `rewardPerBlock`, weighting the result by the pool’s allocation points, and adding the pro-rata reward to the accumulator. Users store two fields—`amount` of LP tokens deposited and `rewardDebt`. On interaction, MasterChef pays `pending = amount * accRewardPerShare - rewardDebt`, transfers the tokens immediately, and then updates `amount` and `rewardDebt` to the new snapshot. Because only the caller’s accounting changes and rewards are minted asynchronously, the system scales to thousands of users per pool with predictable gas—one update at the pool level and one transfer per interaction.

## Synthetix staking algorithm

Synthetix uses the same accumulator idea but is tailored to a single staking market with time-based emissions. Instead of block numbers, it tracks seconds via `rewardPerToken()` and `lastUpdateTime`. The contract defers transfers: `updateReward(account)` advances the global accumulator, stores the user’s share of the new rewards in a `rewards` mapping, and snapshots `userRewardPerTokenPaid`. Actual payouts happen only when the user later calls `getReward()`. This design keeps deposits and withdrawals pure balance updates while allowing governance to top up rewards through `notifyRewardAmount()`, which recalculates `rewardRate` for a fixed-duration campaign.

## MasterChef vs. Synthetix

The two designs share the core invariant—no state change, no reward accrual—but optimize for different trade-offs. MasterChef is better when you want instant settlement and multiple pools: it mints rewards on demand, updates per-user debt in a single transaction, and transfers tokens immediately. That costs an extra token transfer per interaction but avoids storing deferred rewards or asking users to submit a separate claim transaction. Synthetix shines when rewards come from a pre-funded pot and operators prefer explicit claims. By deferring transfers it avoids forcing every deposit/withdraw to touch the reward token, but it pays extra gas for the `rewards` mapping writes and forces users to send a second transaction to collect. If you prioritize operational simplicity and passive accrual (e.g., weekly reward programs with manual funding), Synthetix is more convenient. If you prioritize throughput, multiple markets, and minimizing total transactions per user, MasterChef’s approach remains more efficient overall.

## Gas cost comparison

For a single `deposit` or `withdraw`, MasterChef spends gas on updating the pool accumulator and on the immediate ERC-20 transfer, but it touches only one user storage slot (`rewardDebt`). Synthetix spends similar gas to advance its accumulator yet also reads and writes `rewards[account]` and `userRewardPerTokenPaid`, adding at least one extra `SSTORE`. Users then need a separate `getReward()` transaction, which repeats the update and finally performs the transfer. When you consider an entire reward cycle—stake, accrue, claim—the MasterChef path requires one transaction and one transfer, whereas Synthetix needs two transactions, extra storage writes, and still pays the transfer cost. Net gas ends up lower for MasterChef despite the upfront transfer, so it is generally the more gas-efficient design when measured over full participation lifecycle.

