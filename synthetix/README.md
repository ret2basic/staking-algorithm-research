# Synthetix staking algorithm

This walkthrough distills the RareSkills article on staking algorithms into the concrete mechanics implemented in `src/StakingRewards.sol`.

## Reward accrual via timestamp catch-up

The contract streams rewards at a fixed `rewardRate` until `periodFinish`, but it defers payout until a mutating call arrives, mirroring the article's "catch-up" idea and relying on the invariant that balances only move during explicit transactions. The helper `lastTimeRewardApplicable()` keeps the accumulator from growing past the campaign by returning `periodFinish` once the window expires. With those guardrails in place, `rewardPerToken()` captures how much reward a single staked token has earned "since the beginning of time" by considering the seconds elapsed since `lastUpdateTime`, multiplying by `rewardRate`, scaling by `1e18` for precision, and dividing by `_totalSupply`, exactly matching the article's global reward-per-token counter.

## Per-user snapshots instead of reward debt

Before any stake, withdraw, or claim logic executes, the `updateReward(account)` modifier advances `rewardPerTokenStored` to the latest value and refreshes `lastUpdateTime`, ensuring future calls only consider new time slices. Rather than MasterChef's reward-debt subtraction, Synthetix snapshots `userRewardPerTokenPaid`; the difference between that snapshot and the current accumulator, multiplied by the user's balance, is added to the deferred `rewards[account]` bucket. Because payouts remain in this mapping until `getReward()` runs, users can batch claims and avoid dust transfers, echoing the RareSkills discussion about Synthetix's storage-heavy yet operationally simple approach.

## Core flows: stake, withdraw, claim

Calling `stake(amount)` requires a positive value, settles pending rewards via the modifier, updates `_totalSupply` and `_balances`, and pulls tokens with `safeTransferFrom`, emitting events that mirror the user's new position. Withdrawals follow the same accrual step, then burn stake from supply and balance before returning tokens, allowing partial exits without claiming because rewards are already settled. When `getReward()` executes, the caller's deferred balance is zeroed out and the reward token is transferred, meaning deposits and withdrawals do not automatically pay out and explicit claims are how stakers realize earnings, just as the article notes. The `exit()` helper simply sequences a full withdraw followed by `getReward()`, giving participants a one-transaction escape hatch.

## Admin controls and emission scheduling

Governance interacts with emissions through `notifyRewardAmount(reward)`, which starts or refreshes a program and, if a previous window is still active, folds the leftover emission into the new total so `rewardRate` remains continuous and loyal stakers are not underpaid. The guard `rewardRate <= balance / rewardsDuration` enforces that the contract is fully funded for the announced schedule, reflecting Synthetix's assumption that rewards are pre-deposited rather than minted on demand. Owners can prepare for a new campaign by calling `setRewardsDuration()` after the current period ends, preventing mid-stream timeline changes, while `recoverERC20()` rescues stray tokens (other than the staking asset) to keep accounting clean.

## Architectural contrasts with MasterChef

Synthetix uses `block.timestamp` with a fixed-duration window, whereas MasterChef relies on block numbers and can run indefinitely with adjustable pools. Emissions stream from pre-funded balances rather than being minted during updates, a consequence of Synthetix's governance-controlled reward pool. Because the contract serves a single staking market, there are no allocation weights or pool arrays, and bookkeeping uses per-user snapshots plus deferred rewards instead of the reward-debt pattern; the RareSkills article points out that this costs a bit more storage but keeps transfer logic simpler.

## Putting it together

Whenever any staker interacts, `updateReward` advances the global accumulator, tallies that staker's newly earned rewards, and stores the latest snapshot before the core function adjusts balances or transfers tokens. Events log each step, and because only the caller's record changes, the contract scales to many participants without looping, fulfilling the efficiency goals laid out in the RareSkills discussion.
