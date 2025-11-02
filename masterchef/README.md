# MasterChef staking algorithm

The MasterChef contract uses a "rewardDebt" accounting mechanism to track rewards:
- `accSushiPerShare`: Accumulated rewards per staked token
- `rewardDebt`: User's debt, used to calculate pending rewards
- Formula: `pending = (user.amount * pool.accSushiPerShare) - user.rewardDebt`

Note: I rearranged the code to emphasize the rewards concepts.

## MasterChef.sol Walkthrough

This section distills the RareSkills article on staking algorithms into a tour of the key routines inside `src/MasterChef.sol`.

### Reward accrual without per-block transactions

- `getMultiplier` and `updatePool` implement the “catch-up” idea from the article: they defer minting until someone interacts, then multiply the skipped blocks by `sushiPerBlock` to mint everything owed in one shot.
- When a pool has no deposits, `updatePool` simply bumps `lastRewardBlock`, preserving the invariant that rewards only accrue while stake exists.
- The bonus window is encoded via `BONUS_MULTIPLIER` so early blocks distribute `BONUS_MULTIPLIER * sushiPerBlock`, matching the bonus schedule discussed in the article.

### Pool-level accounting with reward-per-token accumulator

- Each pool keeps `accSushiPerShare`, the scaled accumulator for “how much SUSHI one LP token has earned since the pool opened,” exactly mirroring the article's global counter concept.
- On every `updatePool`, new rewards are divided by the pool's LP supply and added to `accSushiPerShare`, so the value can only increase and never resets.
- The accumulator is scaled by `1e12` to avoid precision loss from integer division, a common MasterChef pattern.

### User-level accounting with reward debt

- `UserInfo.amount` tracks deposited LPs, while `rewardDebt` snapshots the accumulator at the moment the user's balance changes.
- On deposit or withdraw, pending rewards are computed with the formula `amount * accSushiPerShare - rewardDebt`, ensuring users cannot claim for blocks that precede their stake.
- After paying out, `rewardDebt` resets to the new `amount * accSushiPerShare`, so future calls only deliver incremental rewards.

### Pool management and safety valves

- `add`, `set`, and `totalAllocPoint` allow the owner to manage multiple pools by adjusting their relative weights, letting one MasterChef coordinate many staking markets as described in the article's comparison to Synthetix.
- `massUpdatePools` and `updatePool` ensure all pools remain consistent before configuration changes, preventing retroactive dilution.
- `migrate` (if configured) hands LP tokens to an external migrator, while `emergencyWithdraw` lets users exit without rewards—both features limit operational risk when the staking program needs maintenance.
- `safeSushiTransfer` protects against rounding dust that might otherwise block withdrawals, and the `dev` address split mirrors the original SushiSwap tokenomics.

### Putting it together

During a typical `deposit` call the sequence is: update the pool to “catch up” rewards, pay the caller their pending SUSHI using the accumulator, transfer in new LP tokens, and finally refresh the caller's `rewardDebt`. `withdraw` mirrors the flow but burns LP balance first. Because all state transitions funnel through these functions, the contract never has to iterate over every staker—the core gas optimization highlighted by RareSkills.

