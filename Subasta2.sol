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

    address public highestBidder; // Mejor postor actual
    uint public highestBid; // Valor de la mejor oferta

    struct Bid {
        address bidder;
        uint amount;
    }

    Bid[] public bidHistory; // Historial de ofertas

    mapping(address => uint) public deposits; // Mapping de depósitos de cada usuario
    mapping(address => uint) public lastBid; // Mapping ultima oferta de cada usuario
    mapping(address => uint) private bidIndex; // ahora privado
    mapping(address => bool) private hasBid;   // ahora privado
    mapping(address => uint) public lastBidTime; // Control de tiempo entre ofertas de un mismo usuario

    // Variables de estado adicionales
    bool public ended; // Booleano con el estado de la subasta
    bool private fundsWithdrawn = false; // variale control de retiro de fondos
    bool public cancelled = false; // indica si la subasta fue cancelada

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
        require(block.timestamp < auctionEndTime && !ended && !cancelled, "Auction has ended or cancelled");
        _;
    }

    modifier onlyWhenEnded() {
        require((block.timestamp >= auctionEndTime || ended || cancelled), "Auction has not ended yet");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this function");
        _;
    }

    // Constructor: inicializa la subasta con duración en minutos
    constructor(uint _durationMinutes) {
        require(_durationMinutes > 0, "Duration must be greater than zero");
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_durationMinutes * 1 minutes);
    }

    // Permite ofertar, cumpliendo reglas de subasta
    function bid() external payable onlyWhileActive {
        require(msg.sender != owner, "Owner cannot bid");
        require(msg.sender != address(0), "Invalid address");
        require(msg.value > 0, "You must send ETH to bid");
        require(!ended && !cancelled, "Auction already ended or cancelled");

        // Tiempo mínimo entre ofertas del mismo usuario (1 minuto)
        require(block.timestamp > lastBidTime[msg.sender] + 1 minutes, "Wait at least 1 minute between bids");
        lastBidTime[msg.sender] = block.timestamp;

        uint newBid = lastBid[msg.sender] + msg.value;

        // La nueva oferta debe ser al menos un 5% mayor que la oferta más alta actual
        require(
            highestBid == 0 || newBid >= highestBid + (highestBid * 5 / 100),
            "Bid must be at least 5% higher than current"
        );

        // No puedes ofertar si ya eres el mejor postor
        require(msg.sender != highestBidder, "You are already the highest bidder");

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

        // Extiende la oferta se realiza cerca del final en 10 minutos
        if (block.timestamp + 10 minutes > auctionEndTime && extendedTime < maxExtensionTime) {
            uint newExtension = 10 minutes;
            extendedTime += newExtension;
            if (extendedTime <= maxExtensionTime) {
                auctionEndTime += newExtension;
            }
        }

        emit NewBid(msg.sender, newBid);
    }

    // Permite retirar el exceso de depósito sobre la última oferta válida durante la subasta
    function partialWithdraw() external onlyWhileActive {
        require(msg.sender != address(0), "Invalid address");
        uint deposit = deposits[msg.sender];
        uint bidAmount = lastBid[msg.sender];
        require(deposit > bidAmount, "No excess to withdraw");
        require(deposit > 0, "No deposit to withdraw");

        uint excess = deposit - bidAmount;
        deposits[msg.sender] = bidAmount; // Efecto antes de la interacción

        (bool success, ) = payable(msg.sender).call{value: excess}("");
        require(success, "Failed to transfer excess");

        emit PartialWithdrawal(msg.sender, excess);
    }

    // Permite a los no ganadores retirar su depósito menos una comisión del 2% después de la subasta
    function withdrawDeposit() external onlyWhenEnded {
        require(msg.sender != highestBidder, "Winner cannot withdraw");
        require(msg.sender != address(0), "Invalid address");

        uint amount = deposits[msg.sender];
        require(amount > 0, "No deposit to withdraw");

        deposits[msg.sender] = 0; // Efecto antes de la interacción

        uint fee = (amount * 2) / 100;
        uint payout = amount - fee;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        require(success, "Failed to transfer payout");

        emit DepositWithdrawn(msg.sender, payout, fee);

        // Transfiere la comisión al propietario
        if (fee > 0) {
            (bool feeSuccess, ) = payable(owner).call{value: fee}("");
            require(feeSuccess, "Failed to transfer fee");
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
        require(!fundsWithdrawn, "Funds already withdrawn");
        require(highestBid > 0, "No funds to withdraw");

        fundsWithdrawn = true;
        uint amount = highestBid;
        highestBid = 0; // Efecto antes de la interacción

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Failed to withdraw funds");
    }

    // Permite cancelar la subasta antes de que existan ofertas
    function cancelAuction() external onlyOwner onlyWhileActive {
        require(highestBid == 0, "Cannot cancel after bids have been placed");
        ended = true;
        cancelled = true;
        emit AuctionCancelled();
    }

    // Permite a los usuarios retirar su depósito si la subasta fue cancelada
    function withdrawDepositOnCancel() external onlyWhenEnded {
        require(cancelled, "Auction was not cancelled");
        require(deposits[msg.sender] > 0, "No deposit to withdraw");

        uint amount = deposits[msg.sender];
        deposits[msg.sender] = 0; // Efecto antes de la interacción

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to transfer deposit");

        emit DepositWithdrawnOnCancel(msg.sender, amount);
    }

    // Devuelve el número de ofertas realizadas
    function getBidCount() external view returns (uint) {
        return bidHistory.length;
    }

    // Devuelve una página del historial de ofertas (paginación)
    function getBidHistory(uint offset, uint limit) external view returns (Bid[] memory) {
        require(offset < bidHistory.length, "Offset out of bounds");
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