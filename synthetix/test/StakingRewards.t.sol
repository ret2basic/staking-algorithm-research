pragma solidity ^0.5.16;

import "forge-std/Test.sol";
import "../src/StakingRewards.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) public {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) public {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract StakingRewardsTest is Test {
    StakingRewards public stakingRewards;
    MockERC20 public rewardsToken;
    MockERC20 public stakingToken;
    address public owner;
    address public rewardsDistribution;
    
    function setUp() public {
        owner = address(this);
        rewardsDistribution = address(0x1);
        
        rewardsToken = new MockERC20("Reward Token", "RWD");
        stakingToken = new MockERC20("Staking Token", "STK");
        
        stakingRewards = new StakingRewards(
            owner,
            rewardsDistribution,
            address(rewardsToken),
            address(stakingToken)
        );
    }
    
    function testInitialState() public {
        assertEq(address(stakingRewards.rewardsToken()), address(rewardsToken));
        assertEq(address(stakingRewards.stakingToken()), address(stakingToken));
        assertEq(stakingRewards.rewardsDistribution(), rewardsDistribution);
    }
}
