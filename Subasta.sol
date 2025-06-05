// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction {
    address public owner;
    uint public auctionEndTime;
    uint public maxExtensionTime = 7 days;  // extension del contrato por 7 dias
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
    mapping(address => uint) public lastBidTime; // para controlar el tiempo entre ofertas

    bool public ended;
    bool private fundsWithdrawn = false;

    event NewBid(address indexed bidder, uint amount);
    event AuctionEnded(address winner, uint winningAmount);
    event PartialWithdrawal(address indexed bidder, uint amount);
    event DepositWithdrawn(address indexed bidder, uint amount, uint fee);
    event AuctionCancelled();
    event FeeTransferred(address indexed to, uint amount);

    modifier onlyWhileActive() {
        require(block.timestamp < auctionEndTime && !ended, "Auction has ended");
        _;
    }

    modifier onlyWhenEnded() {
        require(block.timestamp >= auctionEndTime || ended, "Auction has not ended yet");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this function");
        _;
    }

    /** punto1: Seguidamente defino el constructor que parametriza los componentes 
        necesarios para el funcionamiento del contrato */

    constructor(uint _durationMinutes) {
        require(_durationMinutes > 0, "Duration must be greater than zero");
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_durationMinutes * 1 minutes);
    }

    /**
     *  Permite a los usuarios realizar una oferta. La oferta debe ser al menos un 5% mayor que la oferta más alta actual.
     *      Extiende automáticamente el tiempo de la subasta si la oferta se realiza cerca del final.
     *      Ahora requiere suficiente ETH para cubrir la nueva oferta y limita la frecuencia de ofertas por usuario.
     */
    function bid() external payable onlyWhileActive {
        require(msg.sender != owner, "Owner cannot bid");
        require(msg.sender != address(0), "Invalid address");
        require(msg.value > 0, "You must send ETH to bid");
        require(!ended, "Auction already ended");

        // tiempo mínimo entre ofertas del mismo usuario (1 minuto)
        
        require(block.timestamp > lastBidTime[msg.sender] + 1 minutes, "Wait at least 1 minute between bids");
        lastBidTime[msg.sender] = block.timestamp;

        uint newBid = lastBid[msg.sender] + msg.value;

        // La nueva oferta debe ser al menos un 5% mayor que la oferta más alta actual

        require(
            highestBid == 0 || newBid >= highestBid + (highestBid * 5 / 100),
            "Bid must be at least 5% higher than current"
        );

        // asegurar suficiente ETH para la nueva oferta

        require(msg.value >= newBid - lastBid[msg.sender], "Insufficient ETH sent for new bid");

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

        // Extensión automática si la oferta se realiza cerca del final

        if (block.timestamp + 10 minutes > auctionEndTime && extendedTime < maxExtensionTime) {
            uint newExtension = 10 minutes;
            extendedTime += newExtension;
            if (extendedTime <= maxExtensionTime) {
                auctionEndTime += newExtension;
            }
        }

        emit NewBid(msg.sender, newBid);
    }

    // Permite a los ofertantes retirar cualquier exceso de depósito que no esté incluido en su última oferta mientras la subasta está activa.
   
    function partialWithdraw() external onlyWhileActive {
        require(msg.sender != address(0), "Invalid address");
        uint deposit = deposits[msg.sender];
        uint bidAmount = lastBid[msg.sender];
        require(deposit > bidAmount, "No excess to withdraw");
        require(deposit > 0, "No deposit to withdraw");

        uint excess = deposit - bidAmount;
        deposits[msg.sender] = bidAmount;

        (bool success, ) = payable(msg.sender).call{value: excess}("");
        require(success, "Failed to transfer excess");

        emit PartialWithdrawal(msg.sender, excess);
    }

    // Permite a los ofertantes (excepto el ganador) retirar su depósito menos una comisión del 2% después de que la subasta finaliza.

    function withdrawDeposit() external onlyWhenEnded {
        require(msg.sender != highestBidder, "Winner cannot withdraw");
        require(msg.sender != address(0), "Invalid address");

        uint amount = deposits[msg.sender];
        require(amount > 0, "No deposit to withdraw");

        uint fee = (amount * 2) / 100;
        uint payout = amount - fee;
        deposits[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        require(success, "Failed to transfer payout");

        emit DepositWithdrawn(msg.sender, payout, fee);

        // Opcionalmente, transfiere la comisión al propietario

        if (fee > 0) {
            (bool feeSuccess, ) = payable(owner).call{value: fee}("");
            require(feeSuccess, "Failed to transfer fee");
            emit FeeTransferred(owner, fee);
        }
    }

    // Permite al propietario finalizar la subasta manualmente.
  
    function endAuction() external onlyOwner onlyWhileActive {
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    // Permite al propietario retirar la oferta más alta después de que la subasta finaliza.
    
    function withdrawFunds() external onlyOwner onlyWhenEnded {
        require(!fundsWithdrawn, "Funds already withdrawn");
        require(highestBid > 0, "No funds to withdraw");

        fundsWithdrawn = true;
        (bool success, ) = payable(owner).call{value: highestBid}("");
        require(success, "Failed to withdraw funds");
    }

    // Permite al propietario cancelar la subasta antes de que se realicen ofertas.
   
    function cancelAuction() external onlyOwner onlyWhileActive {
        require(highestBid == 0, "Cannot cancel after bids have been placed");
        ended = true;
        emit AuctionCancelled();
    }

    // Devuelve el número de ofertas realizadas.
    
    function getBidCount() external view returns (uint) {
        return bidHistory.length;
    }

    // Devuelve el historial de ofertas.
    
    function getBidHistory() external view returns (Bid[] memory) {
        return bidHistory;
    }

    // Devuelve el ganador y el valor de la oferta ganadora.
     
    function getWinner() external view returns (address, uint) {
        return (highestBidder, highestBid);
    }
}
