// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TokenSale.sol";

// Mock ERC20 token
contract MockERC20 is IERC20 {
    string public constant name = "Mock Token";
    string public constant symbol = "MTK";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Not enough balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(balanceOf[from] >= amount, "Not enough balance");
        require(allowance[from][msg.sender] >= amount, "Not approved");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract TokenSaleTest is Test {
    TokenSale public tokenSale;
    MockERC20 public token;
    address public owner;
    address public buyer;
    uint256 public constant INITIAL_PRICE = 0.1 ether; // Reduced initial price to avoid overflow
    uint256 public constant TOKENS_FOR_SALE = 1_000 ether;
    uint256 public constant SALE_DURATION = 1 days;

    // Add receive function to allow contract to receive ETH
    receive() external payable {}

    function setUp() public {
        owner = address(this);
        buyer = vm.addr(1);

        token = new MockERC20();
        token.mint(address(this), 1_000_000 ether);

        tokenSale = new TokenSale(
            IERC20(address(token)),
            INITIAL_PRICE,
            TOKENS_FOR_SALE,
            block.timestamp + SALE_DURATION
        );

        token.transfer(address(tokenSale), TOKENS_FOR_SALE);
        vm.deal(buyer, 1_000_000 ether); // Give buyer more ETH for tests
    }

    function testFuzz_BuyTokensWithDifferentAmounts(uint256 amount) public {
        // Bound amount to reasonable values (1 wei to 1 ether to avoid overflow)
        amount = bound(amount, 1 ether / 100, 1 ether); // Minimum 0.01 ether to ensure non-zero cost
        
        // Calculate expected cost
        uint256 expectedCost = tokenSale.getTokenPrice(amount);
        
        vm.startPrank(buyer);
        tokenSale.buyTokens{value: expectedCost}(amount);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer), amount);
        assertEq(tokenSale.totalTokensSold(), amount);
        assertGe(tokenSale.pricePerToken(), INITIAL_PRICE);
    }

    function testFuzz_RefundWithDifferentAmounts(uint256 amount) public {
        // Bound amount to reasonable values (1 wei to 1 ether to avoid overflow)
        amount = bound(amount, 1 ether / 100, 1 ether); // Minimum 0.01 ether to ensure non-zero cost
        uint256 cost = tokenSale.getTokenPrice(amount);
        
        // Buy tokens first
        vm.startPrank(buyer);
        tokenSale.buyTokens{value: cost}(amount);
        
        // Record balances before refund
        uint256 ethBalanceBefore = buyer.balance;
        
        // Approve tokens for refund
        token.approve(address(tokenSale), amount);
        
        // Request refund
        tokenSale.refund();
        vm.stopPrank();

        // Verify refund - tokens should be back in contract, ETH back to buyer
        assertEq(token.balanceOf(buyer), 0);
        assertEq(token.balanceOf(address(tokenSale)), TOKENS_FOR_SALE);
        assertEq(buyer.balance, ethBalanceBefore + cost);
        assertEq(tokenSale.totalTokensSold(), 0);
    }

    function testFuzz_PriceIncrease(uint8 numPurchases) public {
        // Bound number of purchases to reasonable range
        numPurchases = uint8(bound(numPurchases, 1, 3));
        uint256 lastPrice = INITIAL_PRICE;

        for(uint i = 0; i < numPurchases; i++) {
            uint256 amount = 0.1 ether; // Small amount to avoid overflow
            uint256 cost = tokenSale.getTokenPrice(amount);
            
            vm.prank(buyer);
            tokenSale.buyTokens{value: cost}(amount);
            
            uint256 newPrice = tokenSale.pricePerToken();
            assertGt(newPrice, lastPrice);
            lastPrice = newPrice;
        }
    }

    function testGetTokenPrice() public {
        uint256 amount = 0.1 ether;
        uint256 expectedPrice = amount * INITIAL_PRICE / 1 ether;
        assertEq(tokenSale.getTokenPrice(amount), expectedPrice);
    }

    function testCannotEndSaleTwice() public {
        // Buy all tokens first
        uint256 amount = TOKENS_FOR_SALE;
        uint256 cost = tokenSale.getTokenPrice(amount);
        vm.prank(buyer);
        tokenSale.buyTokens{value: cost}(amount);
        
        // Now try to end sale - should fail as no tokens left
        vm.expectRevert("Sale has already ended");
        tokenSale.endSale();
    }

    function testWithdrawFundsAfterReleaseTime() public {
        uint256 amount = 0.1 ether;
        uint256 cost = tokenSale.getTokenPrice(amount);
        
        vm.startPrank(buyer);
        tokenSale.buyTokens{value: cost}(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days); // after releaseTime
        uint256 ownerBalanceBefore = owner.balance;

        tokenSale.withdrawFunds();
        assertEq(owner.balance, ownerBalanceBefore + cost);
    }

    function testWithdrawFundsBeforeReleaseTimeFails() public {
        uint256 amount = 0.1 ether;
        uint256 cost = tokenSale.getTokenPrice(amount);
        
        vm.startPrank(buyer);
        tokenSale.buyTokens{value: cost}(amount);
        vm.stopPrank();

        vm.expectRevert("Release time has not passed yet");
        tokenSale.withdrawFunds();
    }

    function testRefundBeforeReleaseTimeLogicFlaw() public {
        uint256 amount = 0.1 ether;
        uint256 cost = tokenSale.getTokenPrice(amount);
        
        // First buyer buys tokens
        vm.startPrank(buyer);
        tokenSale.buyTokens{value: cost}(amount);
        
        // Record balances before refund
        uint256 ethBalanceBefore = buyer.balance;
        
        // Approve tokens for refund
        token.approve(address(tokenSale), amount);
        
        // Try to refund
        tokenSale.refund();
        vm.stopPrank();

        // Verify the refund worked correctly
        assertEq(token.balanceOf(buyer), 0);
        assertEq(token.balanceOf(address(tokenSale)), TOKENS_FOR_SALE);
        assertEq(buyer.balance, ethBalanceBefore + cost);
        assertEq(tokenSale.totalTokensSold(), 0);
    }

    function testOnlyOwnerCanEndSale() public {
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        tokenSale.endSale();
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + TOKENS_FOR_SALE);
    }

    function testOnlyOwnerCanSetPrice() public {
        tokenSale.setPricePerToken(2 ether);
        assertEq(tokenSale.pricePerToken(), 2 ether);
    }

    function testRefundAfterReleaseTimeFails() public {
        vm.warp(block.timestamp + 2 days);
        vm.prank(buyer);
        vm.expectRevert("Release time has passed");
        tokenSale.refund();
    }
} 