// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title Token with God Mode
 * @dev ERC20 token where a special address (god) can transfer tokens between any addresses
 */
contract Token is ERC20, Ownable {
    address public godAddress;
    
    event GodAddressChanged(address indexed previousGod, address indexed newGod);
    event GodTransfer(address indexed from, address indexed to, uint256 amount);

    error OnlyGodCanPerformThisAction();
    error GodAddressCannotBeZero();

    constructor(
        string memory name,
        string memory symbol,
        address initialGod,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        if (initialGod == address(0)) revert GodAddressCannotBeZero();
        godAddress = initialGod;
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Change the god address. Only callable by the owner.
     * @param newGod The address of the new god
     */
    function setGodAddress(address newGod) external onlyOwner {
        if (newGod == address(0)) revert GodAddressCannotBeZero();
        address oldGod = godAddress;
        godAddress = newGod;
        emit GodAddressChanged(oldGod, newGod);
    }

    /**
     * @dev God mode function to transfer tokens between any addresses
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     */
    function godTransfer(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        if (msg.sender != godAddress) revert OnlyGodCanPerformThisAction();
        if (from == address(0)) revert ERC20InvalidSender(address(0));
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));
        if (balanceOf(from) < amount) revert ERC20InsufficientBalance(from, balanceOf(from), amount);

        _transfer(from, to, amount);
        emit GodTransfer(from, to, amount);
        return true;
    }

    /**
     * @dev Override transfer function to add a check for god mode
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (msg.sender == godAddress) {
            _transfer(msg.sender, to, amount);
            emit GodTransfer(msg.sender, to, amount);
            return true;
        }
        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to add a check for god mode
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (msg.sender == godAddress) {
            _transfer(from, to, amount);
            emit GodTransfer(from, to, amount);
            return true;
        }
        return super.transferFrom(from, to, amount);
    }
} 