# Subasta — Ethereum Auction Smart Contracts

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-363636?style=flat&logo=solidity)](https://soliditylang.org)
[![Ethereum](https://img.shields.io/badge/Ethereum-Sepolia-3C3C3D?style=flat&logo=ethereum&logoColor=white)](https://ethereum.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

Two Solidity smart contracts implementing a decentralized auction system on Ethereum, with increasing complexity. Built as part of the [ETH-KIPU](https://ethkipu.org) Blockchain Development Program.

---

## Contracts

| File | Description |
|---|---|
| `Subasta.sol` | Basic auction — core bidding logic and timed execution |
| `Subasta2.sol` | Extended auction — full production-ready implementation |

---

## Subasta2.sol — Full documentation

### Overview

A secure and transparent auction system on Ethereum. The auction duration is variable and defined by the owner at deployment (in minutes). If a valid bid is placed within the last 10 minutes, the auction is automatically extended by 10 minutes, up to a maximum equal to the original duration.

All important actions are recorded via events. Only the owner can finalize the auction and refund non-winning bidders, deducting a 2% commission.

### Main features

- **Variable auction duration** — owner sets duration in minutes at deploy time. Bids in the last 10 minutes trigger a 10-minute extension (up to the original duration maximum)
- **Bidding** — only valid bids accepted (at least 5% higher than current highest bid)
- **Partial withdrawal** — bidders can withdraw any excess deposit above their last valid bid during the auction
- **Refunds** — after auction ends, owner refunds non-winners with a 2% commission deducted
- **Auction cancellation** — owner can cancel if no bids have been placed
- **Emergency withdrawal** — owner can recover all funds only if auction was cancelled and no deposits remain
- **Full event logging** — all actions emit events for off-chain transparency and indexing

### Key variables

| Variable | Description |
|---|---|
| `owner` | Contract owner address |
| `auctionEndTime` | Timestamp when the auction ends |
| `maxExtensionTime` | Maximum allowed extension (= original duration) |
| `extendedTime` | Total time the auction has been extended |
| `highestBidder` | Address of the current highest bidder |
| `highestBid` | Amount of the current highest bid |
| `bidHistory` | Array of all bids (address and amount) |
| `deposits` | ETH deposits by address |
| `lastBid` | Last bid of each address |
| `hasBid` | Whether an address has already placed a bid |
| `lastBidTime` | Last time a user placed a bid |
| `ended` | True if the auction has ended |
| `fundsWithdrawn` | True if the owner has withdrawn the winning amount |
| `cancelled` | True if the auction was cancelled |

### Functions

#### `constructor(uint256 _duration)`
Initializes the auction with the duration defined by the owner (in minutes) and sets the deployer as owner.
```
Parameter: _duration — duration in minutes (e.g. 10080 for 7 days)
```

#### `bid()` — payable
Allows users (except the owner) to place bids. Each bid must be at least 5% higher than the current highest. Bids in the last 10 minutes extend the auction by 10 minutes (up to the original duration maximum).
```
Parameter: msg.value — ETH sent with the bid
Emits: NewBid
```

#### `partialWithdrawal()`
Allows bidders to withdraw any excess deposit above their last valid bid during the auction.
```
Emits: PartialWithdrawal
```

#### `withdrawDeposits()`
Only the owner can call this after the auction ends. Refunds non-winners, deducting a 2% commission.
```
Emits: DepositWithdrawn, FeeTransferred
```

#### `endAuction()`
Allows the owner to manually end the auction before the scheduled time.
```
Emits: AuctionEnded
```

#### `withdrawWinningBid()`
Allows the owner to withdraw the winning bid after the auction ends.

#### `cancelAuction()`
Allows the owner to cancel the auction if no bids have been placed.
```
Emits: AuctionCancelled
```

#### `withdrawDepositOnCancel()`
Allows users to withdraw their deposit if the auction was cancelled.
```
Emits: DepositWithdrawnOnCancel
```

#### `emergencyWithdrawal()`
Allows the owner to recover all ETH from the contract only if the auction was cancelled and no deposits remain.
```
Emits: EmergencyWithdrawal
```

#### `getBidCount()` — view
Returns the total number of bids placed.

#### `getBidHistory(uint256 offset, uint256 limit)` — view
Returns a paginated slice of the bid history.
```
Parameters:
  offset — start index
  limit  — number of bids to return
```

#### `getWinner()` — view
Returns the address of the highest bidder and the winning bid amount.

### Events

| Event | Emitted when |
|---|---|
| `NewBid` | A new valid bid is placed |
| `AuctionEnded` | The auction ends |
| `PartialWithdrawal` | A user withdraws excess deposit |
| `DepositWithdrawn` | A non-winner receives a refund |
| `AuctionCancelled` | The auction is cancelled |
| `FeeTransferred` | The owner receives the 2% commission |
| `DepositWithdrawnOnCancel` | A user withdraws deposit after cancellation |
| `EmergencyWithdrawal` | The owner recovers all funds |

### Security and best practices

- All critical functions use modifiers to restrict access and ensure correct auction state
- All ETH transfers use `call` and check for success
- State changes are made before external calls (checks-effects-interactions pattern)
- Solidity 0.8.x built-in overflow/underflow protection
- Array lengths stored in local variables before loops to optimize gas usage
- Full NatSpec documentation in English throughout the contract

### Limitations and security considerations

- **Gas limit** — `withdrawDeposits` could hit the gas limit with a large number of bidders. For large-scale use, individual withdrawal patterns are recommended
- **No reentrancy modifier** — the checks-effects-interactions pattern is applied throughout, which is sufficient for this context
- **Front-running** — inherent to public auctions on blockchain; not specifically mitigated here
- **Intended use** — designed for academic and small-scale use. For production, thorough testing and a professional security audit are strongly recommended

---

## Deployment

### Prerequisites

- [Remix IDE](https://remix.ethereum.org)
- MetaMask with Sepolia testnet ETH
- Solidity compiler 0.8.20

### Steps

1. Open Remix IDE and create a new file with the contract code
2. Compile using Solidity 0.8.20
3. In the Deploy tab, select **Injected Provider (MetaMask)** and connect to Sepolia
4. Enter the auction duration in minutes as the constructor parameter (e.g. `10080` for 7 days)
5. Click **Deploy** and confirm in MetaMask

### Etherscan verification

1. Go to the deployed contract on [Sepolia Etherscan](https://sepolia.etherscan.io)
2. Click **Contract → Verify and Publish**
3. Select compiler version `0.8.20` and MIT license
4. Paste the full contract source code
5. Enter the constructor parameter in ABI-encoded format (use [ABI Hashex](https://abi.hashex.org) to encode it)

---

## Author

**Eduardo Moreno** — Senior Software Developer · Blockchain & Web3

- GitHub: [@edumor](https://github.com/edumor)
- LinkedIn: [linkedin.com/in/eduardomoreno-15813b19b](https://linkedin.com/in/eduardomoreno-15813b19b)
- Email: [eduardomoreno2503@gmail.com](mailto:eduardomoreno2503@gmail.com)

Part of the [ETH-KIPU](https://ethkipu.org) Blockchain Development Program.
