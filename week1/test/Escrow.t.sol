// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/Escrow.sol";

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
    uint256 public amountToDeposit = 1000 * 10 ** 18; // Example token amount to deposit
    uint256 public escrowPeriod = 3 days;

    function setUp() public {
        // Set up addresses
        buyer = makeAddr("buyer");
        seller = makeAddr("seller");
        
        // Deploy mock ERC20 token
        token = new MockERC20("TestToken", "TT");
        
        // Mint tokens for the buyer
        token.mint(buyer, amountToDeposit);
        
        // Deploy the Escrow contract - msg.sender (this contract) will be the owner
        escrow = new Escrow(token, seller);
        
        // Switch to buyer's context and approve tokens
        vm.startPrank(buyer);
        token.approve(address(escrow), amountToDeposit);
        vm.stopPrank();
    }

    function testDeposit() public {
        // Switch to buyer's context
        vm.startPrank(buyer);
        
        // Deposit tokens from the buyer into the escrow contract
        escrow.deposit(amountToDeposit);
        
        vm.stopPrank();

        // Ensure the buyer's balance has decreased
        assertEq(token.balanceOf(buyer), 0);

        // Ensure the escrow contract now holds the tokens
        assertEq(token.balanceOf(address(escrow)), amountToDeposit);

        // Ensure the buyer is recorded in the escrow contract
        assertEq(escrow.buyer(), buyer);
    }

    function testWithdraw() public {
        // First deposit tokens as buyer
        vm.startPrank(buyer);
        escrow.deposit(amountToDeposit);
        vm.stopPrank();

        // Fast-forward time by 3 days
        vm.warp(block.timestamp + escrowPeriod);

        // Switch to seller's context and withdraw
        vm.startPrank(seller);
        escrow.withdraw();
        vm.stopPrank();

        // Ensure the seller received the tokens
        assertEq(token.balanceOf(seller), amountToDeposit);

        // Ensure the escrow contract balance is 0
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function testRefund() public {
        // First deposit tokens as buyer
        vm.startPrank(buyer);
        escrow.deposit(amountToDeposit);
        
        // Request refund as buyer (still in buyer's context)
        escrow.refund();
        vm.stopPrank();

        // Ensure the buyer received the tokens back
        assertEq(token.balanceOf(buyer), amountToDeposit);

        // Ensure the escrow contract balance is 0
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function testEscrowPeriodOver() public {
        // First deposit tokens as buyer
        vm.startPrank(buyer);
        escrow.deposit(amountToDeposit);
        vm.stopPrank();

        // Check if the escrow period is over (it shouldn't be yet)
        assertFalse(escrow.isEscrowPeriodOver());

        // Fast-forward time by 3 days
        vm.warp(block.timestamp + escrowPeriod);

        // Now check if the escrow period is over
        assertTrue(escrow.isEscrowPeriodOver());
    }

    function testChangeSeller() public {
        address newSeller = makeAddr("newSeller");
        
        // Call changeSeller as the owner (test contract)
        escrow.changeSeller(newSeller);

        // Ensure the seller address is updated
        assertEq(escrow.seller(), newSeller);
    }

    function testReentrancyGuard() public {
        // ReentrancyGuard should prevent reentrancy attacks, so let's test this.

        // Deploy a malicious contract that tries to reenter the escrow contract
        address malicious = address(new MaliciousEscrowAttack(address(escrow)));

        // Ensure the malicious contract can't call withdraw() recursively
        vm.expectRevert("ReentrancyGuard: reentrant call");
        hoax(seller);
        (bool success,) = malicious.call(abi.encodeWithSignature("attack()"));
        assertFalse(success);
    }

    function testFuzz_DepositDifferentAmounts(uint256 amount) public {
        // Bound the amount to be between 1 and the total supply
        amount = bound(amount, 1, type(uint128).max);
        console.log("Bound result", amount);
        
        // Clear any existing balance
        vm.startPrank(buyer);
        uint256 existingBalance = token.balanceOf(buyer);
        if (existingBalance > 0) {
            token.transfer(address(0x1), existingBalance);
        }
        vm.stopPrank();
        
        // Mint tokens for the buyer
        token.mint(buyer, amount);
        
        // Approve tokens
        vm.startPrank(buyer);
        token.approve(address(escrow), amount);
        
        // Deposit tokens
        escrow.deposit(amount);
        vm.stopPrank();

        // Verify the deposit
        assertEq(token.balanceOf(buyer), 0);
        assertEq(token.balanceOf(address(escrow)), amount);
        assertEq(escrow.buyer(), buyer);
    }

    function testFuzz_EscrowPeriodWithDifferentTimes(uint256 timeElapsed) public {
        // Bound the time to reasonable values (1 second to 1 year)
        timeElapsed = bound(timeElapsed, 1, 365 days);
        
        // First deposit tokens as buyer
        vm.startPrank(buyer);
        escrow.deposit(amountToDeposit);
        vm.stopPrank();

        // Fast-forward time by the fuzzed amount
        vm.warp(block.timestamp + timeElapsed);

        // Check if escrow period is over based on the time elapsed
        bool shouldBeOver = timeElapsed >= escrowPeriod;
        assertEq(escrow.isEscrowPeriodOver(), shouldBeOver);

        // Try withdrawal based on time elapsed
        vm.startPrank(seller);
        if (shouldBeOver) {
            // Should succeed if period is over
            escrow.withdraw();
            assertEq(token.balanceOf(seller), amountToDeposit);
        } else {
            // Should fail if period is not over
            vm.expectRevert("Escrow period not over");
            escrow.withdraw();
        }
        vm.stopPrank();
    }

    function testFuzz_MultipleDepositsAndWithdrawals(uint256[] calldata amounts) public {
        uint256 totalAmount = 0;
        vm.assume(amounts.length > 0 && amounts.length <= 10); // Reasonable number of iterations
        
        // Process each amount
        for(uint i = 0; i < amounts.length; i++) {
            // Bound each amount to reasonable values
            uint256 amount = bound(amounts[i], 1, type(uint128).max / amounts.length);
            totalAmount += amount;
            
            // Create a new escrow for each amount
            MockERC20 newToken = new MockERC20("Test", "TST");
            Escrow newEscrow = new Escrow(newToken, seller);
            
            // Mint and approve tokens
            newToken.mint(buyer, amount);
            vm.startPrank(buyer);
            newToken.approve(address(newEscrow), amount);
            
            // Deposit
            newEscrow.deposit(amount);
            vm.stopPrank();
            
            // Verify deposit
            assertEq(newToken.balanceOf(address(newEscrow)), amount);
            
            // Fast forward time and withdraw
            vm.warp(block.timestamp + escrowPeriod);
            vm.prank(seller);
            newEscrow.withdraw();
            
            // Verify withdrawal
            assertEq(newToken.balanceOf(seller), amount);
        }
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