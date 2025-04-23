// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/Escrow.sol"; // Adjust path based on your project structure

// Mock ERC20 Token
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract EscrowTest is Test {
    Escrow public escrow;
    MockERC20 public token;
    address public buyer;
    address public seller;
    address public owner;
    uint256 public amountToDeposit = 1000 * 10**18;  // Example token amount to deposit
    uint256 public escrowPeriod = 3 days;

    function setUp() public {
        // Deploy mock ERC20 token
        token = new MockERC20("TestToken", "TT");

        // Mint tokens for the buyer and seller
        buyer = address(0x123);
        seller = address(0x456);
        owner = address(this); // Owner is the contract deployer

        token.mint(buyer, amountToDeposit); // Mint tokens for buyer
        token.mint(owner, amountToDeposit); // Mint tokens for owner (contract deployer)

        // Deploy the Escrow contract
        escrow = new Escrow(token, seller);

        // Approve escrow contract to spend the buyer's tokens
        token.approve(address(escrow), amountToDeposit);

        // Simulate buyer funding the escrow
        hoax(buyer, amountToDeposit);
    }

    function testDeposit() public {
        // Deposit tokens from the buyer into the escrow contract
        escrow.deposit(amountToDeposit);

        // Ensure the buyer's balance has decreased
        assertEq(token.balanceOf(buyer), 0);

        // Ensure the escrow contract now holds the tokens
        assertEq(token.balanceOf(address(escrow)), amountToDeposit);

        // Ensure the buyer is recorded in the escrow contract
        assertEq(escrow.buyer(), buyer);
    }

    function testWithdraw() public {
        // Deposit tokens first
        escrow.deposit(amountToDeposit);

        // Fast-forward time by 3 days
        vm.warp(block.timestamp + escrowPeriod);

        // Simulate seller withdrawing the tokens
        hoax(seller);
        escrow.withdraw();

        // Ensure the seller received the tokens
        assertEq(token.balanceOf(seller), amountToDeposit);

        // Ensure the escrow contract balance is 0
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function testRefund() public {
        // Deposit tokens first
        escrow.deposit(amountToDeposit);

        // Simulate the buyer requesting a refund before the escrow period ends
        hoax(buyer);
        escrow.refund();

        // Ensure the buyer received the tokens back
        assertEq(token.balanceOf(buyer), amountToDeposit);

        // Ensure the escrow contract balance is 0
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function testEscrowPeriodOver() public {
        // Deposit tokens first
        escrow.deposit(amountToDeposit);

        // Check if the escrow period is over (it shouldn't be yet)
        assertFalse(escrow.isEscrowPeriodOver());

        // Fast-forward time by 3 days
        vm.warp(block.timestamp + escrowPeriod);

        // Now check if the escrow period is over
        assertTrue(escrow.isEscrowPeriodOver());
    }

    function testChangeSeller() public {
        // The owner can change the seller
        escrow.changeSeller(address(0x789));

        // Ensure the seller address is updated
        assertEq(escrow.seller(), address(0x789));
    }

    function testReentrancyGuard() public {
        // ReentrancyGuard should prevent reentrancy attacks, so let's test this.

        // Deploy a malicious contract that tries to reenter the escrow contract
        address malicious = address(new MaliciousEscrowAttack(address(escrow)));

        // Ensure the malicious contract can't call withdraw() recursively
        vm.expectRevert("ReentrancyGuard: reentrant call");
        hoax(seller);
        malicious.call(abi.encodeWithSignature("attack()"));
    }
}

// Malicious contract to test reentrancy guard
contract MaliciousEscrowAttack {
    Escrow public escrow;

    constructor(address _escrow) {
        escrow = Escrow(_escrow);
    }

    function attack() public {
        escrow.withdraw(); // Try to reenter withdraw() function
    }
}
