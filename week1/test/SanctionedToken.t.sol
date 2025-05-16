// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/SanctionedToken.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract SanctionedTokenTest is Test {
    SanctionedToken public token;
    address public owner;
    address public user1;
    address public user2;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;

    function setUp() public {
        owner = address(this);
        user1 = vm.addr(1);
        user2 = vm.addr(2);

        // Deploy token
        token = new SanctionedToken("Test Token", "TEST", INITIAL_SUPPLY);

        // Give some tokens to test addresses
        token.transfer(user1, 1000 * 10**18);
        token.transfer(user2, 1000 * 10**18);
    }

    function testCanTransferWhenNotBanned() public {
        uint256 amount = 100 * 10**18;
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);

        vm.prank(user1);
        token.transfer(user2, amount);

        assertEq(token.balanceOf(user1), user1BalanceBefore - amount);
        assertEq(token.balanceOf(user2), user2BalanceBefore + amount);
    }

    function testAdminCanBanAndUnban() public {
        // Ban user1
        token.ban(user1);
        assertTrue(token.isBanned(user1));

        // Unban user1
        token.unban(user1);
        assertFalse(token.isBanned(user1));
    }

    function testSenderCannotTransferIfBanned() public {
        uint256 amount = 100 * 10**18;
        
        // Ban user1
        token.ban(user1);

        // Try to transfer from banned address
        vm.prank(user1);
        vm.expectRevert("Sender is banned");
        token.transfer(user2, amount);
    }

    function testRecipientCannotReceiveIfBanned() public {
        uint256 amount = 100 * 10**18;
        
        // Ban user2
        token.ban(user2);

        // Try to transfer to banned address
        vm.prank(user1);
        vm.expectRevert("Recipient is banned");
        token.transfer(user2, amount);
    }

    function testCannotBanTwice() public {
        // Ban user1
        token.ban(user1);
        
        // Try to ban again
        vm.expectRevert("User is already banned");
        token.ban(user1);
    }

    function testCannotUnbanIfNotBanned() public {
        // Try to unban an address that isn't banned
        vm.expectRevert("User is not banned");
        token.unban(user1);
    }
} 