pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingRewards.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract StakingRewardsTest is Test {
    uint256 constant REWARD_DURATION = 100;
    uint256 constant STAKE_AMOUNT = 100 ether;
    uint256 constant REWARD_AMOUNT = 1_000 ether;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA);

    StakingRewards internal stakingRewards;
    MockERC20 internal rewardsToken;
    MockERC20 internal stakingToken;
    address internal owner;
    address internal rewardsDistribution;

    function setUp() public {
        owner = address(this);
        rewardsDistribution = address(0x1);

        rewardsToken = new MockERC20("Reward Token", "RWD");
        stakingToken = new MockERC20("Staking Token", "STK");

        stakingRewards = new StakingRewards(owner, rewardsDistribution, address(rewardsToken), address(stakingToken));

        vm.warp(1);
        stakingRewards.setRewardsDuration(REWARD_DURATION);
    }

    /* ========== Helpers ========== */

    function _stake(address user, uint256 amount) internal {
        stakingToken.mint(user, amount);
        vm.startPrank(user);
        stakingToken.approve(address(stakingRewards), amount);
        stakingRewards.stake(amount);
        vm.stopPrank();
    }

    function _notify(uint256 reward) internal {
        rewardsToken.mint(address(stakingRewards), reward);
        vm.prank(rewardsDistribution);
        stakingRewards.notifyRewardAmount(reward);
    }

    /* ========== Happy paths ========== */

    function testStakeUpdatesBalances() public {
        _stake(alice, STAKE_AMOUNT);
        assertEq(stakingRewards.totalSupply(), STAKE_AMOUNT);
        assertEq(stakingRewards.balanceOf(alice), STAKE_AMOUNT);
        assertEq(stakingToken.balanceOf(address(stakingRewards)), STAKE_AMOUNT);
    }

    function testSingleStakerAccruesRewards() public {
        _stake(alice, STAKE_AMOUNT);
        _notify(REWARD_AMOUNT);

        vm.warp(block.timestamp + REWARD_DURATION / 2);

        uint256 expected = REWARD_AMOUNT / 2;
        assertEq(stakingRewards.earned(alice), expected);

        vm.prank(alice);
        stakingRewards.getReward();

        assertEq(rewardsToken.balanceOf(alice), expected);
        assertEq(stakingRewards.rewards(alice), 0);
    }

    function testMultipleStakersSplitRewards() public {
        _stake(alice, STAKE_AMOUNT);
        _notify(REWARD_AMOUNT);

        vm.warp(block.timestamp + 40);

        _stake(bob, STAKE_AMOUNT);

        vm.warp(block.timestamp + (REWARD_DURATION - 40));

        vm.prank(alice);
        stakingRewards.getReward();
        vm.prank(bob);
        stakingRewards.getReward();

        assertEq(rewardsToken.balanceOf(alice), 700 ether);
        assertEq(rewardsToken.balanceOf(bob), 300 ether);
    }

    function testExitReturnsStakeAndRewards() public {
        _stake(alice, STAKE_AMOUNT);
        _notify(REWARD_AMOUNT);

        vm.warp(block.timestamp + REWARD_DURATION);

        vm.prank(alice);
        stakingRewards.exit();

        assertEq(stakingToken.balanceOf(alice), STAKE_AMOUNT);
        assertEq(rewardsToken.balanceOf(alice), REWARD_AMOUNT);
        assertEq(stakingRewards.totalSupply(), 0);
    }

    function testNotifyRollsOverLeftover() public {
        _stake(alice, STAKE_AMOUNT);
        _notify(REWARD_AMOUNT);

        vm.warp(block.timestamp + REWARD_DURATION / 2);
        uint256 initialRate = stakingRewards.rewardRate();
        uint256 leftover = (REWARD_DURATION - (REWARD_DURATION / 2)) * initialRate;

        uint256 newReward = 200 ether;
        rewardsToken.mint(address(stakingRewards), newReward);

        vm.prank(rewardsDistribution);
        stakingRewards.notifyRewardAmount(newReward);

        assertEq(stakingRewards.rewardRate(), (newReward + leftover) / REWARD_DURATION);
    }

    function testRewardsStopAfterPeriodFinish() public {
        _stake(alice, STAKE_AMOUNT);
        _notify(REWARD_AMOUNT);

        vm.warp(block.timestamp + REWARD_DURATION);
        uint256 fullReward = stakingRewards.earned(alice);

        vm.warp(block.timestamp + 1_000);
        assertEq(stakingRewards.earned(alice), fullReward);
    }

    /* ========== Edge cases ========== */

    function testStakeZeroReverts() public {
        vm.expectRevert("Cannot stake 0");
        stakingRewards.stake(0);
    }

    function testWithdrawZeroReverts() public {
        vm.expectRevert("Cannot withdraw 0");
        stakingRewards.withdraw(0);
    }

    function testNotifyRequiresFunding() public {
        vm.expectRevert("Provided reward too high");
        vm.prank(rewardsDistribution);
        stakingRewards.notifyRewardAmount(REWARD_AMOUNT);
    }

    function testOnlyRewardsDistributionCanNotify() public {
        rewardsToken.mint(address(stakingRewards), REWARD_AMOUNT);
        vm.expectRevert("Caller is not RewardsDistribution contract");
        stakingRewards.notifyRewardAmount(REWARD_AMOUNT);
    }

    function testCannotSetRewardsDurationDuringActivePeriod() public {
        _stake(alice, STAKE_AMOUNT);
        _notify(REWARD_AMOUNT);

        vm.expectRevert("Previous rewards period must be complete before changing the duration for the new period");
        stakingRewards.setRewardsDuration(50);
    }

    function testRecoverERC20CannotTakeStakingToken() public {
        rewardsToken.mint(address(stakingRewards), 1 ether);
        vm.expectRevert("Cannot withdraw the staking token");
        stakingRewards.recoverERC20(address(stakingToken), 1 ether);
    }

    function testRecoverERC20SucceedsForOtherToken() public {
        MockERC20 other = new MockERC20("Other", "OTH");
        other.mint(address(stakingRewards), 5 ether);

        stakingRewards.recoverERC20(address(other), 5 ether);

        assertEq(other.balanceOf(owner), 5 ether);
    }
}
