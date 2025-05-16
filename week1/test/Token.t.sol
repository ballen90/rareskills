// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/Token.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenTest is Test {
    Token public token;
    address public owner;
    address public god;
    address public alice;
    address public bob;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;

    event GodAddressChanged(address indexed previousGod, address indexed newGod);
    event GodTransfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        owner = address(this);
        god = vm.addr(1);
        alice = vm.addr(2);
        bob = vm.addr(3);

        // Deploy token with god mode
        token = new Token("Test Token", "TEST", god, INITIAL_SUPPLY);

        // Give some tokens to test addresses
        token.transfer(alice, 1000 * 10**18);
        token.transfer(bob, 1000 * 10**18);
    }

    function testInitialState() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.godAddress(), god);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 2000 * 10**18);
        assertEq(token.balanceOf(alice), 1000 * 10**18);
        assertEq(token.balanceOf(bob), 1000 * 10**18);
    }

    function testGodTransfer() public {
        uint256 amount = 500 * 10**18;
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        vm.prank(god);
        vm.expectEmit(true, true, false, true);
        emit GodTransfer(alice, bob, amount);
        token.godTransfer(alice, bob, amount);

        assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(token.balanceOf(bob), bobBalanceBefore + amount);
    }

    function testGodTransferWithoutApproval() public {
        uint256 amount = 500 * 10**18;
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        // Even without approval, god can transfer
        vm.prank(god);
        token.transferFrom(alice, bob, amount);

        assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(token.balanceOf(bob), bobBalanceBefore + amount);
    }

    function test_RevertWhen_NonGodTransfersWithoutApproval() public {
        uint256 amount = 500 * 10**18;
        
        // Non-god address cannot transfer without approval
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, owner, 0, amount));
        token.transferFrom(alice, bob, amount);
    }

    function testSetGodAddress() public {
        address newGod = vm.addr(4);
        
        vm.expectEmit(true, true, false, true);
        emit GodAddressChanged(god, newGod);
        token.setGodAddress(newGod);
        
        assertEq(token.godAddress(), newGod);
    }

    function test_RevertWhen_NonOwnerSetsGodAddress() public {
        address newGod = vm.addr(4);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.setGodAddress(newGod);
    }

    function test_RevertWhen_NonGodUsesGodTransfer() public {
        vm.prank(alice);
        vm.expectRevert(Token.OnlyGodCanPerformThisAction.selector);
        token.godTransfer(bob, alice, 100 * 10**18);
    }

    function test_RevertWhen_GodTransfersWithInsufficientBalance() public {
        uint256 amount = 2000 * 10**18; // Alice only has 1000 tokens
        vm.prank(god);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1000 * 10**18, amount));
        token.godTransfer(alice, bob, amount);
    }

    function test_RevertWhen_GodTransfersToZeroAddress() public {
        vm.prank(god);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.godTransfer(alice, address(0), 100 * 10**18);
    }

    function test_RevertWhen_SettingZeroAddressAsGod() public {
        vm.expectRevert(Token.GodAddressCannotBeZero.selector);
        token.setGodAddress(address(0));
    }

    function testFuzz_GodTransfer(uint256 amount) public {
        // Bound amount to be within alice's balance
        amount = bound(amount, 0, token.balanceOf(alice));
        
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        vm.prank(god);
        token.godTransfer(alice, bob, amount);

        assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(token.balanceOf(bob), bobBalanceBefore + amount);
    }
} 