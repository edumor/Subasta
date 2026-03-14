# Subasta — Smart Contract Auction System

[![Solidity](https://img.shields.io/badge/Solidity-363636?style=flat&logo=solidity)](https://soliditylang.org)
[![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=flat&logo=ethereum&logoColor=white)](https://ethereum.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

Solidity smart contracts implementing a decentralized auction system on Ethereum. Two contract versions with increasing complexity and feature sets.

---

## Contracts

### `Subasta.sol` — Basic auction
Core auction logic with timed bidding and automated refund mechanics.

- Timed auction with configurable end date
- Highest-bid tracking with automatic previous bidder refund
- Owner-controlled auction finalization
- ETH-based bidding

### `Subasta2.sol` — Extended auction
Enhanced version with additional safeguards and patterns.

- All features from `Subasta.sol`
- Withdrawal pattern for gas-safe refunds (pull over push)
- Extended event logging for frontend integration
- Improved access control

---

## Key concepts demonstrated

- **Timed execution** — `block.timestamp` for auction deadlines
- **Reentrancy prevention** — withdrawal pattern instead of direct transfers
- **Access control** — `onlyOwner` modifier for privileged functions
- **Event emission** — bid and finalization events for off-chain indexing
- **ETH handling** — `payable` functions, `msg.value`, and safe transfer patterns

---

## Usage

### Deploy with Remix IDE

1. Open [Remix IDE](https://remix.ethereum.org)
2. Create a new file and paste the contract code
3. Compile with Solidity ^0.8.0
4. Deploy to a testnet (Sepolia recommended) via MetaMask

### Interact

```solidity
// Place a bid (send ETH with the transaction)
auction.bid{value: 1 ether}()

// Check current highest bid
auction.highestBid()

// Check current highest bidder
auction.highestBidder()

// End auction (owner only, after deadline)
auction.endAuction()

// Withdraw refunded amount (Subasta2 only)
auction.withdraw()
```

---

## Documentation

Full contract documentation available in:
- [`Readme_eng.pdf`](Readme_eng.pdf) — Subasta.sol walkthrough
- [`Readme_Subasta2_eng.pdf`](Readme_Subasta2_eng.pdf) — Subasta2.sol walkthrough

---

## Author

**Eduardo Moreno** — Senior Software Developer · Blockchain & Web3

- GitHub: [@edumor](https://github.com/edumor)
- LinkedIn: [linkedin.com/in/eduardomoreno-15813b19b](https://linkedin.com/in/eduardomoreno-15813b19b)
- Email: [eduardomoreno2503@gmail.com](mailto:eduardomoreno2503@gmail.com)

Part of the [ETH-KIPU](https://ethkipu.org) Blockchain Development Program curriculum.
