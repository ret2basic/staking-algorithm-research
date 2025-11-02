# Synthetix staking algorithm

This walkthrough distills the RareSkills article on staking algorithms into the concrete mechanics implemented in `src/StakingRewards.sol`.

## Reward accrual via timestamp catch-up

The contract streams rewards at a fixed `rewardRate` until `periodFinish`, but it defers payout until a mutating call arrives, mirroring the article's "catch-up" idea and relying on the invariant that balances only move during explicit transactions. The helper `lastTimeRewardApplicable()` keeps the accumulator from growing past the campaign by returning `periodFinish` once the window expires. With those guardrails in place, `rewardPerToken()` captures how much reward a single staked token has earned "since the beginning of time" by considering the seconds elapsed since `lastUpdateTime`, multiplying by `rewardRate`, scaling by `1e18` for precision, and dividing by `_totalSupply`, exactly matching the article's global reward-per-token counter.

## Per-user snapshots instead of reward debt

Before any stake, withdraw, or claim logic executes, the `updateReward(account)` modifier advances `rewardPerTokenStored` to the latest value and refreshes `lastUpdateTime`, ensuring future calls only consider new time slices. Rather than MasterChef's reward-debt subtraction, Synthetix snapshots `userRewardPerTokenPaid`; the difference between that snapshot and the current accumulator, multiplied by the user's balance, is added to the deferred `rewards[account]` bucket. Because payouts remain in this mapping until `getReward()` runs, users can batch claims and avoid dust transfers, echoing the RareSkills discussion about Synthetix's storage-heavy yet operationally simple approach.

## Core flows: stake, withdraw, claim

Calling `stake(amount)` requires a positive value, settles pending rewards via the modifier, updates `_totalSupply` and `_balances`, and pulls tokens with `safeTransferFrom`, emitting events that mirror the user's new position. Withdrawals follow the same accrual step, then burn stake from supply and balance before returning tokens, allowing partial exits without claiming because rewards are already settled. When `getReward()` executes, the caller's deferred balance is zeroed out and the reward token is transferred, meaning deposits and withdrawals do not automatically pay out and explicit claims are how stakers realize earnings, just as the article notes. The `exit()` helper simply sequences a full withdraw followed by `getReward()`, giving participants a one-transaction escape hatch.
