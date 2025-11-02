// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/MasterChef.sol";
import "../src/SushiToken.sol";
import "../src/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("LP Token", "LPT") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MasterChefTest is Test {
    MasterChef public masterChef;
    SushiToken public sushiToken;
    MockERC20 public lpToken;

    address public dev = address(0x1);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 internal constant PID = 0;

    function setUp() public {
        sushiToken = new SushiToken();
        lpToken = new MockERC20();

        masterChef = new MasterChef(
            sushiToken,
            dev,
            100 ether, // sushiPerBlock
            block.number,
            block.number + 1000 // bonusEndBlock
        );

        // Transfer ownership to MasterChef so it can mint
        sushiToken.transferOwnership(address(masterChef));

        // Seed LP tokens for test participants
        lpToken.mint(alice, 1_000 ether);
        lpToken.mint(bob, 1_000 ether);

        // Register a single pool
        masterChef.add(100, lpToken, false);
    }

    function testInitialState() public view {
        assertEq(address(masterChef.sushi()), address(sushiToken));
        assertEq(masterChef.devaddr(), dev);
        assertEq(masterChef.sushiPerBlock(), 100 ether);
        assertEq(masterChef.poolLength(), 1);
        (IERC20 token,,,) = masterChef.poolInfo(PID);
        assertEq(address(token), address(lpToken));
    }

    function testSingleStakerAccruesRewards() public {
        vm.startPrank(alice);
        lpToken.approve(address(masterChef), 100 ether);
        masterChef.deposit(PID, 100 ether);
        vm.stopPrank();

        // Advance 10 blocks
        vm.roll(block.number + 10);

        vm.prank(alice);
        masterChef.withdraw(PID, 0);

        // Alice earns (10 blocks * BONUS_MULTIPLIER) * 100 ether = 10_000 ether. Dev gets 10%.
        assertEq(sushiToken.balanceOf(alice), 10_000 ether);
        assertEq(sushiToken.balanceOf(dev), 1_000 ether);

        (uint256 amount, uint256 rewardDebt) = masterChef.userInfo(PID, alice);
        assertEq(amount, 100 ether);
        (,,, uint256 accSushiPerShare) = masterChef.poolInfo(PID);
        assertEq(rewardDebt, (amount * accSushiPerShare) / 1e12);
    }

    function testDualStakerRewardSplit() public {
        vm.startPrank(alice);
        lpToken.approve(address(masterChef), 100 ether);
        masterChef.deposit(PID, 100 ether);
        vm.stopPrank();

        vm.roll(block.number + 10);

        vm.startPrank(bob);
        lpToken.approve(address(masterChef), 100 ether);
        masterChef.deposit(PID, 100 ether);
        vm.stopPrank();

        vm.roll(block.number + 10);

        vm.prank(alice);
        masterChef.withdraw(PID, 0);
        vm.prank(bob);
        masterChef.withdraw(PID, 0);

        // alice: 10 blocks solo (10_000 ether) + 10 blocks shared (5_000 ether)
        assertEq(sushiToken.balanceOf(alice), 15_000 ether);
        // bob only shares the last 10 blocks => 5_000 ether
        assertEq(sushiToken.balanceOf(bob), 5_000 ether);
        // Dev receives 10% of total minted (20_000 ether)
        assertEq(sushiToken.balanceOf(dev), 2_000 ether);
    }

    function testPendingSushiReflectsAccruedRewards() public {
        vm.startPrank(alice);
        lpToken.approve(address(masterChef), 100 ether);
        masterChef.deposit(PID, 100 ether);
        vm.stopPrank();

        vm.roll(block.number + 5);

        uint256 pending = masterChef.pendingSushi(PID, alice);
        assertEq(pending, 5_000 ether);
    }

    function testEmergencyWithdrawClearsUserState() public {
        vm.startPrank(alice);
        lpToken.approve(address(masterChef), 100 ether);
        masterChef.deposit(PID, 100 ether);
        masterChef.emergencyWithdraw(PID);
        vm.stopPrank();

        assertEq(lpToken.balanceOf(alice), 1_000 ether);
        (uint256 amount, uint256 rewardDebt) = masterChef.userInfo(PID, alice);
        assertEq(amount, 0);
        assertEq(rewardDebt, 0);
        // No SUSHI rewards are paid out during emergency withdraw
        assertEq(sushiToken.balanceOf(alice), 0);
    }

    function testWithdrawMoreThanBalanceReverts() public {
        vm.startPrank(alice);
        lpToken.approve(address(masterChef), 100 ether);
        masterChef.deposit(PID, 100 ether);
        vm.expectRevert("withdraw: not good");
        masterChef.withdraw(PID, 200 ether);
        vm.stopPrank();
    }

    function testSafeSushiTransferHandlesInsufficientBalance() public {
        vm.startPrank(alice);
        lpToken.approve(address(masterChef), 100 ether);
        masterChef.deposit(PID, 100 ether);
        vm.stopPrank();

        vm.roll(block.number + 10);

        // Owner updates the pool so rewards accrue to the contract
        masterChef.massUpdatePools();

        uint256 contractBalance = sushiToken.balanceOf(address(masterChef));
        assertEq(contractBalance, 10_000 ether);

        // Drain SUSHI from the MasterChef to simulate rounding errors
        vm.prank(address(masterChef));
        sushiToken.transfer(dev, contractBalance);

        vm.prank(alice);
        masterChef.withdraw(PID, 0);

        // Transfer succeeds but pays out only the available balance (zero)
        assertEq(sushiToken.balanceOf(alice), 0);
        // Dev balance includes drained rewards plus dev share from update
        assertEq(sushiToken.balanceOf(dev), 11_000 ether);
    }
}
