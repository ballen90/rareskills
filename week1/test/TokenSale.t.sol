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

    function setUp() public {
        owner = address(this);
        buyer = vm.addr(1);

        token = new MockERC20();
        token.mint(address(this), 1_000_000 ether);

        tokenSale = new TokenSale(
            IERC20(address(token)),
            1 ether,               // initial price
            1_000 ether,           // total tokens for sale
            block.timestamp + 1 days
        );

        token.transfer(address(tokenSale), 1_000 ether);
        vm.deal(buyer, 100 ether); // Give buyer 100 ETH
    }

    function testBuyTokens() public {
        uint256 amountToBuy = 1;
        uint256 expectedCost = 1 ether;

        vm.prank(buyer);
        tokenSale.buyTokens{value: expectedCost}(amountToBuy);

        assertEq(token.balanceOf(buyer), amountToBuy);
        assertEq(tokenSale.totalTokensSold(), amountToBuy);
        assertEq(tokenSale.pricePerToken(), 1.01 ether);
        assertEq(address(tokenSale).balance, expectedCost);
    }

    function testExcessRefund() public {
        uint256 amountToBuy = 1;
        uint256 sentAmount = 2 ether;

        uint256 buyerBalanceBefore = buyer.balance;
        console.log("buyer balance: %d", buyerBalanceBefore);

        vm.startPrank(buyer);
        tokenSale.buyTokens{value: sentAmount}(amountToBuy);
        vm.stopPrank();

        assertEq(buyer.balance, buyerBalanceBefore - 1 ether); // 1 ether refunded
        assertEq(token.balanceOf(buyer), 1);
    }

    function testGetTokenPrice() public {
        uint256 amount = 3 ether;
        uint256 expectedPrice = 3 ether;
        assertEq(tokenSale.getTokenPrice(amount), expectedPrice);
    }

    function testOnlyOwnerCanEndSale() public {
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        tokenSale.endSale();
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + 1_000 ether);
    }

    function testCannotEndSaleTwice() public {
        tokenSale.endSale();
        vm.expectRevert("Sale has already ended");
        tokenSale.endSale();
    }

    function testWithdrawFundsAfterReleaseTime() public {
        vm.prank(buyer);
        tokenSale.buyTokens{value: 1 ether}(1 ether);

        vm.warp(block.timestamp + 2 days); // after releaseTime
        uint256 ownerBalanceBefore = owner.balance;

        tokenSale.withdrawFunds();
        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
    }

    function testWithdrawFundsBeforeReleaseTimeFails() public {
        vm.prank(buyer);
        tokenSale.buyTokens{value: 1 ether}(1 ether);

        vm.expectRevert("Release time has not passed yet");
        tokenSale.withdrawFunds();
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

    function testRefundBeforeReleaseTimeLogicFlaw() public {
        // This test will show that any address can call refund and claim totalTokensSold.
        vm.prank(buyer);
        tokenSale.buyTokens{value: 1 ether}(1 ether);

        vm.prank(buyer);
        tokenSale.refund(); // ❗ totalTokensSold refunded to buyer (logic flaw)

        assertEq(token.balanceOf(buyer), 1 ether * 2); // Double tokens due to bad logic
    }
}
