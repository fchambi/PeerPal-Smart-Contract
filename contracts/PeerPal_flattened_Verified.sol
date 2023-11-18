
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: contracts/PeerPal.sol

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
        require((_value * 10 ** _decimals) <= msg.value, "Incorrect amount");

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
            value: (escrows[_orderId].value * 10 ** _decimals) - _amountFeeSeller
        }("");
        
        require(sent, "Transfer failed.");

        emit EscrowComplete(_orderId, escrows[_orderId]);


    }


   function refundBuyerNativeCoin(
        uint _orderId
    ) external  onlyBuyer(_orderId) {
        require(escrows[_orderId].status == EscrowStatus.Funded,"Refund not approved");
             uint8 _decimals = 18; //Wei
        uint256 _value = escrows[_orderId].value * 10 ** _decimals ;
        address _buyer = escrows[_orderId].buyer;
        delete escrows[_orderId];
        (bool sent, ) = payable(address(_buyer)).call{value: _value }("");
        require(sent, "Transfer failed.");

        emit EscrowDisputeResolved(_orderId);
    }

}