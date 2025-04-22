// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../TokenSale.sol"; // Adjust the import path as needed
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenSaleTest is Test {
    TokenSale public tokenSale;
    ERC20 public token;
    address public buyer;
    address public seller;
    uint256 public initialPrice = 1 ether;  // Example initial price of 1 ether per token
    uint256 public tokensForSale = 1000;   // Example amount of tokens for sale
    uint256 public amountToBuy = 10;       // Number of tokens to buy
    uint256 public priceIncreasePerToken = 0.01 ether; // Price increase per token
    
    function setUp() public {
        // Create a new ERC20 token contract
        token = new ERC20("TestToken", "TT");

        // Mint some tokens for the token sale
        token._mint(address(this), tokensForSale * 10**18);

        // Create the TokenSale contract with the initial price and tokens available for sale
        tokenSale = new TokenSale(address(token), initialPrice, tokensForSale);

        // Set buyer and seller addresses
        buyer = address(0x123);
        seller = address(0x456);

        // Give the buyer some ether to interact with the contract
        hoax(buyer, 100 ether);
    }

    function testBuyTokens() public {
        // Approve the TokenSale contract to spend the buyer's tokens
        token.approve(address(tokenSale), amountToBuy * 10**18);

        // Calculate the expected price for the tokens based on the bonding curve
        uint256 expectedPrice = initialPrice + (amountToBuy * priceIncreasePerToken);

        // Simulate a purchase
        hoax(buyer, expectedPrice);
        tokenSale.buyTokens(amountToBuy);

        // Check that the correct amount of tokens were transferred to the buyer
        assertEq(token.balanceOf(buyer), amountToBuy * 10**18);

        // Check the amount of tokens remaining in the sale contract
        assertEq(token.balanceOf(address(tokenSale)), tokensForSale - amountToBuy);
    }

    function testPriceIncreaseOnPurchase() public {
        // Approve the TokenSale contract to spend the buyer's tokens
        token.approve(address(tokenSale), amountToBuy * 10**18);

        // Simulate the first purchase
        hoax(buyer, initialPrice);
        tokenSale.buyTokens(amountToBuy);

        // Calculate the expected price for the second purchase
        uint256 newPrice = initialPrice + (amountToBuy * priceIncreasePerToken);

        // Approve for the second purchase
        hoax(buyer, newPrice);
        tokenSale.buyTokens(amountToBuy);

        // Assert that the token price increased for the second purchase
        uint256 expectedPriceAfterSecondPurchase = initialPrice + (2 * amountToBuy * priceIncreasePerToken);
        assertEq(tokenSale.getTokenPrice(amountToBuy), expectedPriceAfterSecondPurchase);

        // Check that the remaining tokens in the sale have decreased accordingly
        assertEq(token.balanceOf(address(tokenSale)), tokensForSale - 2 * amountToBuy);
    }

    function testRefundBeforeReleaseTime() public {
        // Approve the TokenSale contract to spend the buyer's tokens
        token.approve(address(tokenSale), amountToBuy * 10**18);

        // Deposit tokens into the sale
        hoax(buyer, initialPrice);
        tokenSale.buyTokens(amountToBuy);

        // Try to refund before the release time (should fail)
        vm.expectRevert("Release time has not passed yet");
        tokenSale.refund();
    }

    function testWithdrawAfterReleaseTime() public {
        // Approve the TokenSale contract to spend the buyer's tokens
        token.approve(address(tokenSale), amountToBuy * 10**18);

        // Deposit tokens into the sale
        hoax(buyer, initialPrice);
        tokenSale.buyTokens(amountToBuy);

        // Fast-forward time by 3 days
        vm.warp(block.timestamp + 3 days);

        // Seller tries to withdraw after the release time (should succeed)
        hoax(seller);
        tokenSale.withdraw();

        // Ensure that the tokens were withdrawn by the seller
        assertEq(token.balanceOf(seller), amountToBuy * 10**18);
        assertEq(token.balanceOf(address(tokenSale)), 0);
    }

    function testCancelSaleByOwner() public {
        // Approve the TokenSale contract to spend the buyer's tokens
        token.approve(address(tokenSale), amountToBuy * 10**18);

        // Deposit tokens into the sale
        hoax(buyer, initialPrice);
        tokenSale.buyTokens(amountToBuy);

        // Owner cancels the sale
        hoax(address(this)); // Owner can cancel
        tokenSale.endSale();

        // Check that the remaining tokens were returned to the owner
        assertEq(token.balanceOf(address(this)), tokensForSale - amountToBuy);
    }

    function testOwnerWithdrawFunds() public {
        // Approve the TokenSale contract to spend the buyer's tokens
        token.approve(address(tokenSale), amountToBuy * 10**18);

        // Deposit tokens into the sale
        hoax(buyer, initialPrice);
        tokenSale.buyTokens(amountToBuy);

        // Owner withdraws the collected funds
        hoax(address(this)); // Owner withdraws funds
        tokenSale.withdrawFunds();

        // Verify that the funds were withdrawn (you could check the balance of the owner here)
    }
}
