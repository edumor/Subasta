// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Autor: Eduardo Jose Moreno
// Este contrato implementa una subasta segura y transparente

contract Auction {
    // Variables de estado principales
    address public owner;
    uint public auctionEndTime;
    uint public maxExtensionTime = 7 days;
    uint public extendedTime = 0;

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

    // Eventos requeridos
    event NewBid(address indexed bidder, uint amount);
    event AuctionEnded(address winner, uint winningAmount);
    event PartialWithdrawal(address indexed bidder, uint amount);
    event DepositWithdrawn(address indexed bidder, uint amount, uint fee);
    event AuctionCancelled();
    event FeeTransferred(address indexed to, uint amount);
    event DepositWithdrawnOnCancel(address indexed bidder, uint amount);

    // Modificadores de acceso y estado
    modifier onlyWhileActive() {
        require(block.timestamp < auctionEndTime, "Auction: The auction has ended.");
        require(!ended, "Auction: The auction is marked as ended.");
        require(!cancelled, "Auction: The auction has been cancelled.");
        _;
    }

    modifier onlyWhenEnded() {
        require(block.timestamp >= auctionEndTime || ended || cancelled, "Auction: The auction has not ended yet.");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Auction: Only the owner can execute this function.");
        _;
    }

    // Constructor: inicializa la subasta con duración en minutos
    constructor(uint _durationMinutes) {
        require(_durationMinutes > 0, "Auction: Duration must be greater than zero.");
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_durationMinutes * 1 minutes);
    }

    // Permite ofertar, cumpliendo reglas de subasta
    function bid() external payable onlyWhileActive {
        require(msg.sender != owner, "Auction: Owner cannot bid.");
        require(msg.sender != address(0), "Auction: Invalid address.");
        require(msg.value > 0, "Auction: You must send ETH to bid.");
        require(!ended, "Auction: Auction already ended.");
        require(!cancelled, "Auction: Auction already cancelled.");

        // Tiempo mínimo entre ofertas del mismo usuario (1 minuto)
        require(
            block.timestamp > lastBidTime[msg.sender] + 1 minutes,
            "Auction: Wait at least 1 minute between bids."
        );
        lastBidTime[msg.sender] = block.timestamp;

        uint newBid = lastBid[msg.sender] + msg.value;

        // La nueva oferta debe ser al menos un 5% mayor que la oferta más alta actual
        require(
            highestBid == 0 || newBid >= highestBid + (highestBid * 5 / 100),
            "Auction: Bid must be at least 5% higher than current highest bid."
        );

        // No puedes ofertar si ya eres el mejor postor
        require(msg.sender != highestBidder, "Auction: You are already the highest bidder.");

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

        // Extiende la oferta si se realiza cerca del final en 10 minutos, sin exceder el máximo
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

    // Permite retirar el exceso de depósito sobre la última oferta válida durante la subasta
    function partialWithdraw() external onlyWhileActive {
        require(msg.sender != address(0), "Auction: Invalid address.");
        uint deposit = deposits[msg.sender];
        uint bidAmount = lastBid[msg.sender];
        require(deposit > 0, "Auction: No deposit to withdraw.");
        require(deposit > bidAmount, "Auction: No excess to withdraw.");

        uint excess = deposit - bidAmount;
        deposits[msg.sender] = bidAmount; // Efecto antes de la interacción

        (bool success, ) = payable(msg.sender).call{value: excess}("");
        require(success, "Auction: Failed to transfer excess.");

        emit PartialWithdrawal(msg.sender, excess);
    }

    // Permite a los no ganadores retirar su depósito menos una comisión del 2% después de la subasta
    function withdrawDeposit() external onlyWhenEnded {
        require(msg.sender != highestBidder, "Auction: Winner cannot withdraw deposit.");
        require(msg.sender != address(0), "Auction: Invalid address.");

        uint amount = deposits[msg.sender];
        require(amount > 0, "Auction: No deposit to withdraw or already withdrawn.");

        deposits[msg.sender] = 0; // Efecto antes de la interacción

        uint fee = (amount * 2) / 100;
        uint payout = amount - fee;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        require(success, "Auction: Failed to transfer payout.");

        emit DepositWithdrawn(msg.sender, payout, fee);

        // Transfiere la comisión al propietario
        if (fee > 0) {
            (bool feeSuccess, ) = payable(owner).call{value: fee}("");
            require(feeSuccess, "Auction: Failed to transfer fee to owner.");
            emit FeeTransferred(owner, fee);
        }
    }

    // Permite al propietario finalizar la subasta manualmente
    function endAuction() external onlyOwner onlyWhileActive {
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    // Permite al propietario retirar la oferta ganadora después de la subasta
    function withdrawFunds() external onlyOwner onlyWhenEnded {
        require(!fundsWithdrawn, "Auction: Funds already withdrawn.");
        require(highestBid > 0, "Auction: No funds to withdraw.");

        fundsWithdrawn = true;
        uint amount = highestBid;
        highestBid = 0; // Efecto antes de la interacción

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Auction: Failed to withdraw funds to owner.");
    }

    // Permite cancelar la subasta antes de que existan ofertas
    function cancelAuction() external onlyOwner onlyWhileActive {
        require(highestBid == 0, "Auction: Cannot cancel after bids have been placed.");
        ended = true;
        cancelled = true;
        emit AuctionCancelled();
    }

    // Permite a los usuarios retirar su depósito si la subasta fue cancelada
    function withdrawDepositOnCancel() external onlyWhenEnded {
        require(cancelled, "Auction: Auction was not cancelled.");
        uint amount = deposits[msg.sender];
        require(amount > 0, "Auction: No deposit to withdraw or already withdrawn.");

        deposits[msg.sender] = 0; // Efecto antes de la interacción

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Auction: Failed to transfer deposit on cancel.");

        emit DepositWithdrawnOnCancel(msg.sender, amount);
    }

    // Devuelve el número de ofertas realizadas
    function getBidCount() external view returns (uint) {
        return bidHistory.length;
    }

    // Devuelve una página del historial de ofertas (paginación)
    function getBidHistory(uint offset, uint limit) external view returns (Bid[] memory) {
        require(offset < bidHistory.length, "Auction: Offset out of bounds.");
        uint end = offset + limit;
        if (end > bidHistory.length) {
            end = bidHistory.length;
        }
        Bid[] memory page = new Bid[](end - offset);
        for (uint i = offset; i < end; i++) {
            page[i - offset] = bidHistory[i];
        }
        return page;
    }

    // Devuelve el ganador y el valor de la oferta ganadora
    function getWinner() external view returns (address, uint) {
        return (highestBidder, highestBid);
    }
}
