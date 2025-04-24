// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Escrow is ReentrancyGuard, Ownable {
    // The token to be held in escrow
    IERC20 public token;

    // Details of the escrow
    address public buyer;
    address public seller;
    uint256 public amount;
    uint256 public depositTime;
    uint256 public constant ESCROW_PERIOD = 3 days;

    // Events
    event Deposited(address indexed buyer, uint256 amount);
    event Withdrawn(address indexed seller, uint256 amount);
    event Refund(address indexed buyer, uint256 amount);

    // Constructor to initialize the contract with the token and seller
    constructor(IERC20 _token, address _seller) Ownable(msg.sender) {
        token = _token;
        seller = _seller;
    }

    // Function for the buyer to deposit tokens into the escrow
    function deposit(uint256 _amount) external nonReentrant {
        require(buyer == address(0), "Already deposited");
        require(_amount > 0, "Amount must be greater than 0");

        // Transfer the tokens from the buyer to the contract
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

        buyer = msg.sender;
        amount = _amount;
        depositTime = block.timestamp;

        emit Deposited(msg.sender, _amount);
    }

    // Function for the seller to withdraw tokens after the escrow period
    function withdraw() external nonReentrant {
        require(msg.sender == seller, "Only seller can withdraw");
        require(block.timestamp >= depositTime + ESCROW_PERIOD, "Escrow period not over");

        // Transfer the tokens to the seller
        uint256 withdrawalAmount = amount;
        amount = 0; // Prevent reentrancy attacks by resetting the amount
        bool success = token.transfer(seller, withdrawalAmount);
        require(success, "Token transfer failed");

        emit Withdrawn(seller, withdrawalAmount);
    }

    // Function for the buyer to refund before the escrow period ends
    function refund() external nonReentrant {
        require(msg.sender == buyer, "Only buyer can refund");
        require(block.timestamp < depositTime + ESCROW_PERIOD, "Escrow period over");

        // Refund the tokens to the buyer
        uint256 refundAmount = amount;
        amount = 0; // Prevent reentrancy attacks by resetting the amount
        bool success = token.transfer(buyer, refundAmount);
        require(success, "Token transfer failed");

        emit Refund(buyer, refundAmount);
    }

    // Function for the owner to change the seller's address
    function changeSeller(address _newSeller) external onlyOwner {
        seller = _newSeller;
    }

    // View function to check if the escrow period has passed
    function isEscrowPeriodOver() external view returns (bool) {
        return block.timestamp >= depositTime + ESCROW_PERIOD;
    }
}
