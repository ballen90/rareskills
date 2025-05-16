// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

contract TokenSale is Ownable {
    IERC20 public token;
    uint256 public pricePerToken; // Initial price of the token (in wei)
    uint256 public totalTokensSold;
    uint256 public totalTokensForSale;
    uint256 public releaseTime; // The time when funds can be withdrawn or refunded
    
    mapping(address => uint256) public purchases; // Track individual purchases
    mapping(address => uint256) public payments; // Track payments made by buyers

    event TokensBought(address indexed buyer, uint256 amount, uint256 totalCost);
    event TokensSold(address indexed seller, uint256 amount, uint256 totalReceived);
    event SaleEnded(uint256 totalTokensSold);

    constructor(IERC20 _token, uint256 _initialPrice, uint256 _totalTokensForSale, uint256 _releaseTime)
        Ownable(msg.sender)
    {
        token = _token;
        pricePerToken = _initialPrice;
        totalTokensForSale = _totalTokensForSale;
        releaseTime = _releaseTime; // Set the release time at contract deployment
    }

    // Public function to buy tokens
    function buyTokens(uint256 _amount) external payable {
        require(_amount > 0, "Amount must be greater than 0");
        require(totalTokensSold + _amount <= totalTokensForSale, "Not enough tokens left for sale");

        uint256 totalCost = getTokenPrice(_amount);

        // Add this inside the TokenSale contract's buyTokens function
        console.log("Received ether: %d", msg.value);
        console.log("Total cost for %d tokens: %d", _amount, totalCost);

        require(msg.value >= totalCost, "Insufficient funds sent");

        totalTokensSold += _amount;
        purchases[msg.sender] += _amount; // Track the purchase
        payments[msg.sender] += totalCost; // Track the payment
        pricePerToken = pricePerToken + (0.01 ether); // Price increases by 0.01 ETH per transaction

        token.transfer(msg.sender, _amount);

        emit TokensBought(msg.sender, _amount, totalCost);

        // Refund excess ETH sent
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }

    // Public function to calculate token price based on the linear bonding curve
    function getTokenPrice(uint256 _amount) public view returns (uint256) {
        return _amount * pricePerToken / 1 ether;
    }

    // Function to end the sale and transfer any remaining tokens to the owner
    function endSale() external onlyOwner {
        uint256 remainingTokens = totalTokensForSale - totalTokensSold;
        require(remainingTokens > 0, "Sale has already ended");

        token.transfer(owner(), remainingTokens);
        emit SaleEnded(totalTokensSold);
    }

    // Function for the owner to withdraw the funds raised during the sale
    function withdrawFunds() external onlyOwner {
        require(block.timestamp >= releaseTime, "Release time has not passed yet");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Transfer failed");
    }

    // Function to allow the owner to adjust the price per token (optional)
    function setPricePerToken(uint256 _newPrice) external onlyOwner {
        pricePerToken = _newPrice;
    }

    // Refund function (buyer can request refund before release time)
    function refund() external {
        require(block.timestamp < releaseTime, "Release time has passed");
        uint256 amountToRefund = purchases[msg.sender];
        require(amountToRefund > 0, "No tokens to refund");
        
        uint256 paymentToReturn = payments[msg.sender];
        require(paymentToReturn > 0, "No payment to refund");
        
        purchases[msg.sender] = 0;
        payments[msg.sender] = 0;
        totalTokensSold -= amountToRefund;
        
        // Transfer tokens back to the contract
        require(token.transferFrom(msg.sender, address(this), amountToRefund), "Token transfer failed");
        
        // Return the original payment
        (bool success, ) = msg.sender.call{value: paymentToReturn}("");
        require(success, "Transfer failed");
    }

    // Fallback function to receive ETH
    receive() external payable {}
}
