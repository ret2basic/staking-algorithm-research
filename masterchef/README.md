# MasterChef staking algorithm

The MasterChef contract uses a "rewardDebt" accounting mechanism to track rewards:
- `accSushiPerShare`: Accumulated rewards per staked token
- `rewardDebt`: User's debt, used to calculate pending rewards
- Formula: `pending = (user.amount * pool.accSushiPerShare) - user.rewardDebt`

**Note:**

1. I rearranged the code to emphasize the rewards concepts. You just have to read the 3 functions under "Core functions" section carefully.
2. MasterChef.sol is rewritten in solidity 0.8.24 for better readability and be compatible with current foundry version.

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

## Appendix: Migration

The optional `migrate` hook lets governance swap a pool’s LP token for a new contract without interrupting deposits. DeFi protocols frequently upgrade or move liquidity to newer AMMs, and without this escape hatch every staker would have to withdraw, migrate, and restake manually—risking slippage, downtime, and lost rewards. When `migrate` runs, MasterChef approves the configured `IMigratorChef` to pull the entire LP balance, invokes `migrate` to receive replacement tokens, and verifies the migrator returned the exact same balance so user stakes remain untouched. Because the new LP token address is stored back into `poolInfo`, subsequent deposits and withdrawals seamlessly use the migrated asset while any misbehaving migrator reverts via the balance parity check.

## Appendix: Multiplier and bonus

`getMultiplier` encapsulates the emission schedule: during the promotional window, blocks earn `BONUS_MULTIPLIER * sushiPerBlock`, and once `bonusEndBlock` passes the multiplier falls back to `1`. By multiplying the per-block emission by this factor before dividing by `totalAllocPoint`, `updatePool` boosts early stakers without touching pool weights or per-user math. Because the bonus only applies between `_from` and `_to`, even partial intervals across the cutoff are prorated, ensuring that the bonus ends cleanly and latecomers cannot claim retroactive rewards.

## Appendix: allocPoint

Each pool’s `allocPoint` is its share of the global emission pie: during `updatePool` the contract multiplies the base reward by `allocPoint / totalAllocPoint`, so doubling a pool’s points literally doubles its per-block SUSHI compared to an unchanged pool. This weighting happens before rewards reach the `accSushiPerShare` accumulator, which means user-level math stays identical regardless of how many pools exist or how governance rebalances incentives. Because `set` updates `totalAllocPoint` in sync with the new value, the ratio across all pools always sums to 100%, preventing “phantom” inflation when weights change.

## Appendix: 1e12 precision adjustment

MasterChef scales its per-share accumulator by `1e12` so that integer division does not zero out tiny reward increments when pools hold large LP balances. Because Solidity has no native decimal or fixed-point types and the rewards per deposit can be much smaller than one wei, multiplying by `1e12` before dividing by `lpSupply` preserves twelve decimal places of precision. The value is arbitrary (any large power of ten works) but `1e12` is a good trade-off: it keeps arithmetic within `uint256` range while ensuring rounding dust stays negligible when users later multiply their balance by `accSushiPerShare` and divide by the same `1e12` scale factor.
