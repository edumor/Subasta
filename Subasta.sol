// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Secure Auction Contract
 * @author Eduardo J. Moreno
 * @notice Implements a secure and transparent auction with fixed duration and automatic extension.
 * @dev All function calls are documented with English comments and NatSpec.
 */
contract Auction {
    // State variables
    address public owner;
    uint private auctionEndTime;
    // Maximum extension allowed: 7 days in minutes (10080 minutes)
    uint private maxExtensionTime = 10080 * 1 minutes;
    uint private extendedTime = 0;

    address public highestBidder;
    uint public highestBid;

    struct Bid {
        address bidder;
        uint amount;
    }

    Bid[] public bidHistory;

    mapping(address => uint) public deposits;
    mapping(address => uint) public lastBid;
    mapping(address => uint) private bidIndex;
    mapping(address => bool) private hasBid;
    mapping(address => uint) public lastBidTime;

    bool public ended;
    bool private fundsWithdrawn = false;
    bool public cancelled = false;

    // Events
    event NewBid(address indexed bidder, uint amount);
    event AuctionEnded(address winner, uint winningAmount);
    event PartialWithdrawal(address indexed bidder, uint amount);
    event DepositWithdrawn(address indexed bidder, uint amount, uint fee);
    event AuctionCancelled();
    event FeeTransferred(address indexed to, uint amount);
    event DepositWithdrawnOnCancel(address indexed bidder, uint amount);
    event EmergencyWithdrawal(address indexed to, uint amount);

    /// @notice Only allow actions while auction is active
    modifier onlyWhileActive() {
        require(block.timestamp < auctionEndTime, "Ended");
        require(!ended, "Ended");
        require(!cancelled, "Cancelled");
        _;
    }

    /// @notice Only allow actions when auction has ended or cancelled
    modifier onlyWhenEnded() {
        require(block.timestamp >= auctionEndTime || ended || cancelled, "Not ended");
        _;
    }

    /// @notice Only allow owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Owner only");
        _;
    }

    /// @notice Constructor: initializes auction with fixed duration of 7 days (10080 minutes)
    constructor() {
        owner = msg.sender;
        auctionEndTime = block.timestamp + (10080 * 1 minutes); // 7 days
    }

    /**
     * @notice Place a bid on the auction.
     * @dev Only non-owner, non-highestBidder, with min 5% increment, and 1 min between bids.
     * @param None. ETH must be sent with the transaction.
     */
    function bid() external payable onlyWhileActive {
        require(msg.sender != owner, "Owner can't bid");
        require(msg.sender != address(0), "Zero addr");
        require(msg.value > 0, "No ETH");
        require(!ended, "Ended");
        require(!cancelled, "Cancelled");
        require(block.timestamp > lastBidTime[msg.sender] + 1 minutes, "Wait 1m");
        lastBidTime[msg.sender] = block.timestamp;

        uint newBid = lastBid[msg.sender] + msg.value;
        require(
            highestBid == 0 || newBid >= highestBid + (highestBid * 5 / 100),
            "Min 5% inc"
        );
        require(msg.sender != highestBidder, "Already highest");

        deposits[msg.sender] += msg.value;
        lastBid[msg.sender] = newBid;
        highestBidder = msg.sender;
        highestBid = newBid;

        if (hasBid[msg.sender]) {
            bidHistory[bidIndex[msg.sender]].amount = newBid;
        } else {
            bidHistory.push(Bid(msg.sender, newBid));
            bidIndex[msg.sender] = bidHistory.length - 1;
            hasBid[msg.sender] = true;
        }

        // Extend auction if bid is close to end
        if (block.timestamp + 10 minutes > auctionEndTime && extendedTime < maxExtensionTime) {
            uint newExtension = 10 minutes;
            if (extendedTime + newExtension > maxExtensionTime) {
                newExtension = maxExtensionTime - extendedTime;
            }
            extendedTime += newExtension;
            auctionEndTime += newExtension;
        }

        emit NewBid(msg.sender, newBid);
    }

    /**
     * @notice Withdraw excess deposit above last valid bid during auction.
     * @dev Allows bidders to recover excess funds during the auction.
     */
    function partialWithdraw() external onlyWhileActive {
        require(msg.sender != address(0), "Zero addr");
        uint deposit = deposits[msg.sender];
        uint bidAmount = lastBid[msg.sender];
        require(deposit > 0, "No deposit");
        require(deposit > bidAmount, "No excess");

        uint excess = deposit - bidAmount;
        deposits[msg.sender] = bidAmount;

        (bool success, ) = payable(msg.sender).call{value: excess}("");
        require(success, "Fail send");

        emit PartialWithdrawal(msg.sender, excess);
    }

    /**
     * @notice Owner refunds all non-winning bidders after auction ends (minus 2% fee).
     * @dev Only callable by owner after auction ends or is cancelled.
     */
    function withdrawDeposits() external onlyOwner onlyWhenEnded {
        uint len = bidHistory.length;
        uint i = 0;
        for (; i < len; i++) {
            address bidder = bidHistory[i].bidder;
            if (bidder != highestBidder) {
                uint amount = deposits[bidder];
                if (amount > 0) {
                    deposits[bidder] = 0;
                    uint fee = (amount * 2) / 100;
                    uint payout = amount - fee;

                    if (payout > 0) {
                        (bool success, ) = payable(bidder).call{value: payout}("");
                        require(success, "Refund fail");
                        emit DepositWithdrawn(bidder, payout, fee);
                    }

                    if (fee > 0) {
                        (bool feeSuccess, ) = payable(owner).call{value: fee}("");
                        require(feeSuccess, "Fee fail");
                        emit FeeTransferred(owner, fee);
                    }
                }
            }
        }
    }

    /**
     * @notice Owner ends the auction manually before scheduled end.
     * @dev Only callable by owner while auction is active.
     */
    function endAuction() external onlyOwner onlyWhileActive {
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    /**
     * @notice Owner withdraws the winning bid after auction ends.
     * @dev Only callable by owner after auction ends.
     */
    function withdrawFunds() external onlyOwner onlyWhenEnded {
        require(!fundsWithdrawn, "Already withdrawn");
        require(highestBid > 0, "No funds");
        require(address(this).balance >= highestBid, "No bal");

        fundsWithdrawn = true;
        uint amount = highestBid;
        highestBid = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Owner withdraw fail");
    }

    /**
     * @notice Owner cancels the auction before any bids are placed.
     * @dev Only callable by owner while auction is active and no bids exist.
     */
    function cancelAuction() external onlyOwner onlyWhileActive {
        require(highestBid == 0, "Bids exist");
        ended = true;
        cancelled = true;
        emit AuctionCancelled();
    }

    /**
     * @notice Users withdraw deposit if auction was cancelled.
     * @dev Only callable after auction is cancelled.
     */
    function withdrawDepositOnCancel() external onlyWhenEnded {
        require(cancelled, "Not cancelled");
        uint amount = deposits[msg.sender];
        require(amount > 0, "No deposit");

        deposits[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Cancel withdraw fail");

        emit DepositWithdrawnOnCancel(msg.sender, amount);
    }

    /**
     * @notice Emergency: Owner can recover all ETH in contract, only if auction was cancelled.
     * @dev Only callable by owner after auction is cancelled.
     */
    function emergencyWithdraw() external onlyOwner onlyWhenEnded {
        require(cancelled, "Only if cancelled");
        uint balance = address(this).balance;
        require(balance > 0, "No ETH");
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Emergency fail");
        emit EmergencyWithdrawal(owner, balance);
    }

    /**
     * @notice Returns number of bids.
     * @dev View function.
     * @return Number of bids.
     */
    function getBidCount() external view returns (uint) {
        return bidHistory.length;
    }

    /**
     * @notice Returns a page of bid history (pagination).
     * @dev View function.
     * @param offset Starting index.
     * @param limit Number of bids to return.
     * @return Array of Bid structs for the requested page.
     */
    function getBidHistory(uint offset, uint limit) external view returns (Bid[] memory) {
        require(offset < bidHistory.length, "Offset OOB");
        uint end = offset + limit;
        if (end > bidHistory.length) {
            end = bidHistory.length;
        }
        Bid[] memory page = new Bid[](end - offset);
        uint i = offset;
        for (; i < end; i++) {
            page[i - offset] = bidHistory[i];
        }
        return page;
    }

    /**
     * @notice Returns winner and winning bid.
     * @dev View function.
     * @return Address of the highest bidder and the highest bid amount.
     */
    function getWinner() external view returns (address, uint) {
        return (highestBidder, highestBid);
    }
}