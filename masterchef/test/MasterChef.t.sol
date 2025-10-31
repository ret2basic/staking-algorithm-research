// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "forge-std/Test.sol";
import "../src/MasterChef.sol";
import "../src/SushiToken.sol";

contract MasterChefTest is Test {
    MasterChef public masterChef;
    SushiToken public sushiToken;
    address public dev;
    
    function setUp() public {
        dev = address(0x1);
        sushiToken = new SushiToken();
        
        masterChef = new MasterChef(
            sushiToken,
            dev,
            100, // sushiPerBlock
            block.number,
            block.number + 1000 // bonusEndBlock
        );
        
        // Transfer ownership to MasterChef so it can mint
        sushiToken.transferOwnership(address(masterChef));
    }
    
    function testInitialState() public {
        assertEq(address(masterChef.sushi()), address(sushiToken));
        assertEq(masterChef.devaddr(), dev);
        assertEq(masterChef.sushiPerBlock(), 100);
    }
}
