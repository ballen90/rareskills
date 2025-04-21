// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/SanctionedToken.sol";

contract SanctionedTokenTest is Test {
    SanctionedToken token;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address admin;

    function setUp() public {
        admin = address(this); // test contract is the owner
        token = new SanctionedToken("Sanctioned USD", "sUSD", 1_000_000 ether);
        token.transfer(user1, 1000 ether);
    }

    function testCanTransferWhenNotBanned() public {
        vm.prank(user1);
        token.transfer(user2, 500 ether);
        assertEq(token.balanceOf(user2), 500 ether);
    }

    function testSenderCannotTransferIfBanned() public {
        token.ban(user1);
        vm.prank(user1);
        vm.expectRevert("Sender is banned");
        token.transfer(user2, 100 ether);
    }

    function testRecipientCannotReceiveIfBanned() public {
        token.ban(user2);
        vm.prank(user1);
        vm.expectRevert("Recipient is banned");
        token.transfer(user2, 100 ether);
    }

    function testAdminCanBanAndUnban() public {
        token.ban(user1);
        assertTrue(token.isBanned(user1));

        token.unban(user1);
        assertFalse(token.isBanned(user1));
    }

    function testCannotBanTwice() public {
        token.ban(user1);
        vm.expectRevert("User is already banned");
        token.ban(user1);
    }

    function testCannotUnbanIfNotBanned() public {
        vm.expectRevert("User is not banned");
        token.unban(user1);
    }
}
