// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TokenSale.sol"; // Adjust the import path as needed

// Mock ERC20 Token
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TokenSaleTest is Test {
    TokenSale public tokenSale;
    MockERC20 public token;
    address public buyer;
    address public seller;
    uint256 public initialPrice = 1 ether;  // Example initial price of 1 ether per token
    uint256 public tokensForSale = 1000;   // Example amount of tokens for sale
    uint256 public amountToBuy = 10;       // Number of tokens to buy
    uint256 public priceIncreasePerToken = 0.01 ether; // Price increase per token
    uint256 public releaseTime;

    function setUp() public {
        releaseTime = block.timestamp + 3 days; // Set release time to 3 days from now

        // Create a new ERC20 token contract
        token = new MockERC20("TestToken", "TT");

        // Mint some tokens for the token sale
        token.mint(address(this), tokensForSale * 10**18);

        // Create the TokenSale contract with the initial price, tokens available, and release time
        tokenSale = new TokenSale(token, initialPrice, tokensForSale, releaseTime);

        // Set buyer and seller addresses
        buyer = address(0x123);
        seller = address(0x456);

        // Give the buyer some ether to interact with the contract
        hoax(buyer, 100 ether);
    }

    // Test buying tokens
    function testBuyTokens() public {
        uint256 expectedPrice = initialPrice + (amountToBuy * priceIncreasePerToken);

        // Log the expected price for debugging
        console.log("Expected price for %d tokens: %d", amountToBuy, expectedPrice);

        // Approve the TokenSale contract to spend the buyer's tokens
        token.approve(address(tokenSale), amountToBuy * 10**18);

        // Simulate a purchase and send the exact amount of ether (expectedPrice)
        hoax(buyer, expectedPrice); // Ensure the correct amount of ether is sent
        tokenSale.buyTokens(amountToBuy);

        // Check that the correct amount of tokens were transferred to the buyer
        assertEq(token.balanceOf(buyer), amountToBuy * 10**18);

        // Check the amount of tokens remaining in the sale contract
        assertEq(token.balanceOf(address(tokenSale)), tokensForSale - amountToBuy);
    }

    // Test refund functionality before release time
    function testRefund() public {
        uint256 expectedPrice = initialPrice + (amountToBuy * priceIncreasePerToken);

        // Approve and simulate the purchase
        token.approve(address(tokenSale), amountToBuy * 10**18);
        hoax(buyer, expectedPrice);
        tokenSale.buyTokens(amountToBuy);

        // Simulate a refund before the release time
        uint256 buyerBalanceBeforeRefund = token.balanceOf(buyer);
        hoax(buyer);
        tokenSale.refund();
        
        // Ensure the buyer has been refunded the correct amount
        assertEq(token.balanceOf(buyer), buyerBalanceBeforeRefund + amountToBuy * 10**18);
    }

    // Test withdraw funds functionality after the release time
    function testWithdrawFunds() public {
        uint256 expectedPrice = initialPrice + (amountToBuy * priceIncreasePerToken);

        // Approve and simulate the purchase
        token.approve(address(tokenSale), amountToBuy * 10**18);
        hoax(buyer, expectedPrice);
        tokenSale.buyTokens(amountToBuy);

        // Fast-forward time by 3 days
        vm.warp(block.timestamp + 3 days);

        // Owner withdraws the funds
        uint256 balanceBefore = address(this).balance;
        hoax(address(this)); // Owner withdraws funds
        tokenSale.withdrawFunds();

        // Verify that the funds were withdrawn
        assertEq(address(this).balance, balanceBefore + expectedPrice);
    }

    // Test ending the sale and transferring remaining tokens to the owner
    function testEndSale() public {
        // Approve and simulate the purchase
        token.approve(address(tokenSale), amountToBuy * 10**18);
        hoax(buyer, initialPrice);
        tokenSale.buyTokens(amountToBuy);

        // Owner ends the sale
        hoax(address(this)); // Owner can end the sale
        tokenSale.endSale();

        // Ensure the remaining tokens were transferred to the owner
        assertEq(token.balanceOf(address(this)), tokensForSale - amountToBuy);
    }

    // Test price increase after each purchase
    function testPriceIncrease() public {
        uint256 initialPriceBefore = tokenSale.getTokenPrice(1);
        uint256 amountToBuyBefore = 1;

        // Buy tokens and verify price increase
        hoax(buyer, initialPrice);
        tokenSale.buyTokens(amountToBuyBefore);

        uint256 priceAfterPurchase = tokenSale.getTokenPrice(amountToBuyBefore);

        // The price should have increased by the price increase per token
        assertEq(priceAfterPurchase, initialPriceBefore + priceIncreasePerToken);
    }
}
