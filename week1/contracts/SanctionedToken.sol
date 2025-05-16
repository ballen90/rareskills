// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SanctionedToken is ERC20, Ownable {
    mapping(address => bool) public isBanned;

    event AddressBanned(address indexed user);
    event AddressUnbanned(address indexed user);

    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        _mint(msg.sender, initialSupply);
    }

    function ban(address user) external onlyOwner {
        require(!isBanned[user], "User is already banned");
        isBanned[user] = true;
        emit AddressBanned(user);
    }

    function unban(address user) external onlyOwner {
        require(isBanned[user], "User is not banned");
        isBanned[user] = false;
        emit AddressUnbanned(user);
    }

    // Use the new _update hook (replaces _beforeTokenTransfer)
    function _update(address from, address to, uint256 value) internal override {
        require(!isBanned[from], "Sender is banned");
        require(!isBanned[to], "Recipient is banned");
        super._update(from, to, value);
    }
}
