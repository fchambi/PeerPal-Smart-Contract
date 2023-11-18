
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Escrow {

    address public owner;
    IERC20 public _token;    
    uint256 public feeSeller;
    uint256 public feeBuyer;
    uint256 public feesAvailableNativeCoin;
    mapping(uint => Escrow) public escrows;
    mapping(address => bool) whitelistedStablesAddresses;
    mapping(IERC20 => uint) public feesAvailable;

    event EscrowDeposit(uint indexed orderId, Escrow escrow);
    event EscrowComplete(uint indexed orderId, Escrow escrow);
    event EscrowDisputeResolved(uint indexed orderId);
  

modifier onlyBuyer(uint _orderId) {
        require(
            msg.sender == escrows[_orderId].buyer,
            "Only Buyer can call this"
        );
        _;
    }
modifier onlySeller(uint _orderId) {
        require(
            msg.sender == escrows[_orderId].seller,
            "Only Seller can call this"
        );
        _;
    }    

 modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        // Underscore is a special character only used inside
        // a function modifier and it tells Solidity to
        // execute the rest of the code.
        _;
    }


enum EscrowStatus {
        Unknown,
        Funded,
        NOT_USED,
        Completed,
        Refund,
        Arbitration
    }

    struct Escrow {
        address payable buyer; //Comprador
        address payable seller; //Vendedor
        uint256 value; //Monto compra
        uint256 sellerfee; //Comision vendedor
        uint256 buyerfee; //Comision comprador
        IERC20 currency; //Moneda
        EscrowStatus status; //Estado
    }
  constructor(address ERC20Address) {
    owner = msg.sender;
    _token = IERC20(ERC20Address);
    feeSeller = 0;
    feeBuyer = 0;
  }

   // ================== Begin External functions ==================
    function setFeeSeller(uint256 _feeSeller) external onlyOwner {
        require(
            _feeSeller >= 0 && _feeSeller <= (1 * 10000),
            "The fee can be from 0% to 1%"
        );
        feeSeller = _feeSeller;
    }

    function setFeeBuyer(uint256 _feeBuyer) external onlyOwner {
        require(
            _feeBuyer >= 0 && _feeBuyer <= (1 * 10000),
            "The fee can be from 0% to 1%"
        );
        feeBuyer = _feeBuyer;
    }
    function setOrderSeller(uint _orderId) external onlySeller(_orderId) {
   /*  require(
            escrows[_orderId].status != EscrowStatus.Unknown,
            "Escrow not exists"
        );*/
        require(
            escrows[_orderId].status == EscrowStatus.Funded,
            "USDT has not been deposited"
        );
         escrows[_orderId].status = EscrowStatus.Completed ;
    }


 function createEscrowNativeCoin(
        uint _orderId,
        address payable _seller,
        uint256 _value
    ) external payable virtual {
        require(
            escrows[_orderId].status == EscrowStatus.Unknown,
            "Escrow already exists"
        );

        require(msg.sender != _seller, "seller cannot be the same as buyer");

        uint8 _decimals = 18;
        //Obtiene el monto a transferir desde el comprador al contrato
        uint256 _amountFeeBuyer = ((_value * (feeBuyer * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        feeBuyer = _amountFeeBuyer;
        require((_value + _amountFeeBuyer) <= msg.value, "Incorrect amount");

        escrows[_orderId] = Escrow(
            payable(msg.sender),
            _seller,
            _value,
            feeSeller,
            feeBuyer,
            IERC20(address(0)),
            EscrowStatus.Funded
        );

        emit EscrowDeposit(_orderId, escrows[_orderId]);

    }

    function releaseEscrowNativeCoin(
        uint _orderId
    ) external onlyBuyer(_orderId) {
        _releaseEscrowNativeCoin(_orderId);
    }

 function _releaseEscrowNativeCoin(uint _orderId) private  onlyBuyer(_orderId) {
   /*     require(
            escrows[_orderId].status == EscrowStatus.Funded,
            "USDT has not been deposited"
        );*/
        require(
            escrows[_orderId].status == EscrowStatus.Completed,
            "Escrow its not comppleted"
        );
        uint8 _decimals = 18; //Wei

        //Obtiene el monto a transferir desde el comprador al contrato        //sellerfee //buyerfee
        uint256 _amountFeeBuyer = ((escrows[_orderId].value *
            (escrows[_orderId].buyerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        uint256 _amountFeeSeller = ((escrows[_orderId].value *
            (escrows[_orderId].sellerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;

        //Registra los fees obtenidos
        feesAvailableNativeCoin += _amountFeeBuyer + _amountFeeSeller;

        // write as complete, in case transfer fails
        escrows[_orderId].status = EscrowStatus.Completed;

        //Transfer to sellet Price Asset - FeeSeller
        (bool sent, ) = escrows[_orderId].seller.call{
            value: (escrows[_orderId].value * 10 ** _decimals) - _amountFeeSeller
        }("");
        
        require(sent, "Transfer failed.");

        emit EscrowComplete(_orderId, escrows[_orderId]);
        delete escrows[_orderId];

    }


   function refundBuyerNativeCoin(
        uint _orderId
    ) external  onlyBuyer(_orderId) {
        require(escrows[_orderId].status == EscrowStatus.Completed,"Refund not approved");

        uint256 _value = escrows[_orderId].value;
        address _buyer = escrows[_orderId].buyer;

        // dont charge seller any fees - because its a refund
        delete escrows[_orderId];

        //Transfer call
        (bool sent, ) = payable(address(_buyer)).call{value: _value}("");
        require(sent, "Transfer failed.");

        emit EscrowDisputeResolved(_orderId);
    }

}