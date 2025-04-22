// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenSale is Ownable {
    IERC20 public token;
    uint256 public pricePerToken;  // Initial price of the token (in wei)
    uint256 public totalTokensSold;
    uint256 public totalTokensForSale;
    uint256 public releaseTime; // The time when funds can be withdrawn or refunded
    
    event TokensBought(address indexed buyer, uint256 amount, uint256 totalCost);
    event TokensSold(address indexed seller, uint256 amount, uint256 totalReceived);
    event SaleEnded(uint256 totalTokensSold);

    constructor(IERC20 _token, uint256 _initialPrice, uint256 _totalTokensForSale, uint256 _releaseTime) Ownable(msg.sender) {
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
        
        require(msg.value >= totalCost, "Insufficient funds sent");

        totalTokensSold += _amount;
        pricePerToken += _amount * 0.01 ether;  // Price increases by 0.01 ETH per token bought

        token.transfer(msg.sender, _amount);

        emit TokensBought(msg.sender, _amount, totalCost);

        // Refund excess ETH sent
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }

    // Public function to calculate token price based on the linear bonding curve
    function getTokenPrice(uint256 _amount) public view returns (uint256) {
        return pricePerToken * _amount;
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
        payable(owner()).transfer(address(this).balance);
    }

    // Function to allow the owner to adjust the price per token (optional)
    function setPricePerToken(uint256 _newPrice) external onlyOwner {
        pricePerToken = _newPrice;
    }

    // Refund function (buyer can request refund before release time)
    function refund() external {
        require(block.timestamp < releaseTime, "Release time has passed");
        uint256 amountToRefund = totalTokensSold;
        totalTokensSold = 0; // Prevent re-entrancy issues
        token.transfer(msg.sender, amountToRefund);
    }
}
