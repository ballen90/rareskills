# 🔐 Why Does `SafeERC20` Exist and When Should It Be Used?

## 📘 Overview

The `SafeERC20` library in Solidity, provided by OpenZeppelin, exists to address common **safety issues and inconsistencies** in ERC-20 token implementations. It acts as a **wrapper around standard ERC-20 functions**, ensuring that token operations such as `transfer`, `transferFrom`, and `approve` behave predictably — especially when interacting with **non-standard or poorly implemented tokens**.

---

## 🚨 The Problem with ERC-20 Tokens

While the ERC-20 standard defines interfaces for token behavior, **many tokens in the wild do not strictly follow the standard**. Here are some common issues:

- Some tokens **do not return a boolean** from `transfer` or `transferFrom`, despite the standard requiring it.
- Others **revert silently** or return false without throwing an error.
- Some tokens have broken or unusual `approve` logic that can lead to race conditions or unexpected behavior.

These inconsistencies can lead to:
- **Silent transaction failures**
- **Unexpected behavior in production**
- **Hard-to-debug bugs in DeFi protocols**

---

## ✅ Enter: `SafeERC20`

`SafeERC20` addresses these issues by **wrapping ERC-20 calls in additional safety checks**.

### 🔧 What It Does:
- Ensures that `transfer`, `transferFrom`, and `approve` return **true** or **revert**.
- Provides safe versions like:
  - `safeTransfer`
  - `safeTransferFrom`
  - `safeApprove`
  - `safeIncreaseAllowance`
  - `safeDecreaseAllowance`

### 📦 Example Usage

```solidity
using SafeERC20 for IERC20;

IERC20 token = IERC20(tokenAddress);
token.safeTransfer(to, amount);
