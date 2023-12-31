//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract PeerPal {
    uint256 public counter;   
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
        address payable buyer; 
        address payable seller; 
        uint256 value; 
        uint256 sellerfee; 
        uint256 buyerfee; 
        string idImage;  
        IERC20 currency; 
        EscrowStatus status; 
    }
  constructor(address ERC20Address) {
    owner = msg.sender;
    _token = IERC20(ERC20Address);
    feeSeller = 0;
    feeBuyer = 0;
    counter = 0;
  }

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
    function setOrderSeller(uint _orderId,string memory _idImage) external onlySeller(_orderId) {
        require(
            escrows[_orderId].status == EscrowStatus.Funded,
            "USDT has not been deposited"
        );
         escrows[_orderId].status = EscrowStatus.Completed ;
         escrows[_orderId].idImage = _idImage;
    }


 function createEscrowNativeCoin(
        address payable _seller,
        uint256 _value
    ) external payable virtual {
        uint256 _orderId = counter + 1;
        require(msg.sender != _seller, "seller cannot be the same as buyer");
        uint8 _decimals = 18;
        uint256 _amountFeeBuyer = ((_value * (feeBuyer * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        feeBuyer = _amountFeeBuyer;
        require((_value ) <= msg.value, "Incorrect amount");

        string memory _idImage = "NO IMAGE" ;

        escrows[_orderId] = Escrow(
            payable(msg.sender),
            _seller,
            _value,
            feeSeller,
            feeBuyer,
            _idImage,
            IERC20(address(0)),
            EscrowStatus.Funded
        );

        counter ++ ;
        emit EscrowDeposit(_orderId, escrows[_orderId]);

    }
    function releaseEscrowNativeCoin(
        uint _orderId
    ) external onlyBuyer(_orderId) {
        _releaseEscrowNativeCoin(_orderId);
    }

 function _releaseEscrowNativeCoin(uint _orderId) private  onlyBuyer(_orderId) {

        require(
            escrows[_orderId].status == EscrowStatus.Completed,
            "Escrow its not comppleted"
        );
        uint8 _decimals = 18; //Wei

        uint256 _amountFeeBuyer = ((escrows[_orderId].value *
            (escrows[_orderId].buyerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        uint256 _amountFeeSeller = ((escrows[_orderId].value *
            (escrows[_orderId].sellerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;


        feesAvailableNativeCoin += _amountFeeBuyer + _amountFeeSeller;


        escrows[_orderId].status = EscrowStatus.Completed;
        (bool sent, ) = escrows[_orderId].seller.call{
            value: (escrows[_orderId].value ) - _amountFeeSeller
        }("");
        
        require(sent, "Transfer failed.");

        emit EscrowComplete(_orderId, escrows[_orderId]);


    }
   function refundBuyerNativeCoin(
        uint _orderId
    ) external  onlyBuyer(_orderId) {
        require(escrows[_orderId].status == EscrowStatus.Funded,"Refund not approved");
        uint256 _value = escrows[_orderId].value ;
        address _buyer = escrows[_orderId].buyer;
        delete escrows[_orderId];
        (bool sent, ) = payable(address(_buyer)).call{value: _value }("");
        require(sent, "Transfer failed.");

        emit EscrowDisputeResolved(_orderId);
    }
}