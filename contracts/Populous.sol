pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract iCrowdsale {
    address public currency;
    bytes32 public borrowerId;
    uint8 public status;
    
    uint public winnerGroupIndex;
    bool public sentToBeneficiary;

    function isDeadlineReached() returns(bool);
    function getGroupsCount() public constant returns (uint);
    function getGroup(uint groupIndex) public constant returns (bytes32 name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack);
    function getGroupBidder(uint groupIndex, uint bidderIndex) public constant returns (bytes32 bidderId, bytes32 name, uint bidAmount, bool hasReceivedTokensBack);        
    function openAuction() public returns (bool);
    function bid(uint groupIndex , bytes32 bidderId, bytes32 name, uint value) returns (uint finalValue, uint groupGoal, bool goalReached);
    function createGroup(bytes32 _name, uint _goal) returns (uint8 err, uint groupIndex);
    function getAmountForBeneficiary() public constant returns (uint8 err, uint amount);
    function setGroupRefunded(uint groupIndex) returns (bool);
    function setSentToBeneficiary();
    function setSentToLosingGroups();
    function setSentToWinnerGroup();
}

contract iCrowdsaleManager {
    function createCrowdsale(
            address _currency,
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _borrowerName,
            bytes32 _buyerName,
            bytes32 _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal) returns (address);
}

contract Populous is withAccessManager {
    // This has to be the same one as in Crowdsale
    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    bytes32 constant LEDGER_SYSTEM_ACCOUNT = "Populous";

    uint constant TX_EXECUTE_GAS_STOP_AMOUNT = 100000;

    event EventPendingTransaction(uint index, bytes32 currency, bytes32 from, bytes32 to, uint amount);
    event EventCanceledTransaction(uint index, bytes32 currency, bytes32 from, bytes32 to, uint amount);
    event EventExecutedTransaction(uint index, bytes32 currency, bytes32 from, bytes32 to, uint amount);

    event EventNewCrowdsale(address crowdsale);
    
    iCrowdsaleManager public CM;
    // currency => (accountName => amount)
    mapping(bytes32 => mapping(bytes32 => uint)) ledger;
    mapping(bytes32 => mapping(bytes32 => uint)) pendingAmounts;
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;

    enum txStates { Unset, Pending, Canceled, Executed }

    struct Transaction {
        bytes32 currency;
        bytes32 from;
        bytes32 to;
        uint amount;
        txStates status;
    }
    
    mapping(uint => Transaction) public pendingTx;
    uint public queueFrontIndex = 0;
    uint public queueBackIndex = 0;

    address[] public crowdsales;

    function Populous(address _accessManager) withAccessManager(_accessManager) { }

    function setCM(address _crowdsaleManager) {
        CM = iCrowdsaleManager(_crowdsaleManager);
    }

    function getLedgerEntry(bytes32 currency, bytes32 client) constant returns (uint) {
        return ledger[currency][client];
    }
    
    function getPendingLedgerEntry(bytes32 currency, bytes32 client) constant returns (uint) {
        return pendingAmounts[currency][client];
    }

    function getCurrency(bytes32 currency) constant returns (address) {
        return currencies[currency];
    }

    function getCurrencySymbol(address currency) constant returns (bytes32) {
        return currenciesSymbols[currency];
    }

    function createCurrency(bytes32 _tokenName, uint8 _decimalUnits, bytes32 _tokenSymbol)
        onlyGuardian
    {
        currencies[_tokenSymbol] = new CurrencyToken(address(AM), _tokenName, _decimalUnits, _tokenSymbol);
        
        if (currencies[_tokenSymbol] == 0x0) { throw; }
        
        currenciesSymbols[currencies[_tokenSymbol]] = _tokenSymbol;
    }

    function mintTokens(bytes32 currency, uint amount)
        onlyGuardian
        returns (bool success)
    {
        if (currencies[currency] != 0x0) {
            CurrencyToken(currencies[currency]).mintTokens(amount);
            ledger[currency][LEDGER_SYSTEM_ACCOUNT] = SafeMath.safeAdd(ledger[currency][LEDGER_SYSTEM_ACCOUNT], amount);

            return true;
        } else {
            return false;
        }
    }
    
    function destroyTokens(bytes32 currency, uint amount)
        onlyGuardian
        returns (bool success)
    {
        if (currencies[currency] != 0x0) {
            success = CurrencyToken(currencies[currency]).destroyTokens(amount);
        
            if (success == true) {
                ledger[currency][LEDGER_SYSTEM_ACCOUNT] = SafeMath.safeSub(ledger[currency][LEDGER_SYSTEM_ACCOUNT], amount);
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    function transfer(bytes32 currency, bytes32 from, bytes32 to, uint amount) onlyServer {
        _transfer(currency, from, to, amount);
    }

    function _transfer(bytes32 currency, bytes32 from, bytes32 to, uint amount) private {
        if (ledger[currency][from] < amount) { throw; }
    
        ledger[currency][from] = SafeMath.safeSub(ledger[currency][from], amount);
        ledger[currency][to] = SafeMath.safeAdd(ledger[currency][to], amount);
    }

    function createCrowdsale(
            address _currency,
            bytes32 _borrowerId,
            bytes32 _borrowerName,
            bytes32 _buyerName,
            bytes32 _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal)
        onlyServer
    {
        if (currenciesSymbols[_currency].length == 0) { throw; }

        address crowdsaleAddr = CM.createCrowdsale(
            _currency,
            currenciesSymbols[_currency],
            _borrowerId,
            _borrowerName,
            _buyerName,
            _invoiceId,
            _invoiceAmount,
            _fundingGoal            
        );

        crowdsales.push(crowdsaleAddr);

        EventNewCrowdsale(crowdsaleAddr);
    }

    function bid(address crowdsaleAddr, uint groupIndex, bytes32 bidderId, bytes32 name, uint value) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        uint finalValue;
        uint groupGoal;
        bool goalReached;
        (finalValue, groupGoal, goalReached) = CS.bid(groupIndex, bidderId, name, value);

        _transfer(currenciesSymbols[CS.currency()], bidderId, LEDGER_SYSTEM_ACCOUNT, finalValue);
    }

    function fundBeneficiary(address crowdsaleAddr) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        uint8 err;
        uint amount;

        (err, amount) = CS.getAmountForBeneficiary();
        if (err != 0) { throw; }

        _transfer(currenciesSymbols[CS.currency()], LEDGER_SYSTEM_ACCOUNT, CS.borrowerId(), goal);

        CS.setSentToBeneficiary();
    }

    /**
        @dev This function has to be split, because it might exceed the gas limit, if the groups and bidders are too many.
    */
    // function refundLosingGroup(address crowdsaleAddr) {
    //     iCrowdsale CS = iCrowdsale(crowdsaleAddr);

    //     uint groupsCount = CS.getGroupsCount();

    //     // Loop all groups
    //     for (uint groupIndex = 0; groupIndex < groupsCount; groupIndex++) {
            
    //         // Check if group has already been refunded
    //         if (groupIndex != CS.winnerGroupIndex() && CS.groups[groupIndex].hasReceivedTokensBack == false) {
    //             uint biddersCount = CS.groups[groupIndex].bidders.length;

    //             // Loop all bidders
    //             for (uint bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
    //                 // Check if bidder has already been refunded
    //                 if (CS.groups[groupIndex].bidders[bidderIndex].hasReceivedTokensBack == false) {
    //                     // Refund bidder
    //                     ledger[CS.currencySymbol][LEDGER_SYSTEM_ACCOUNT] = SafeMath.safeSub(ledger[CS.currencySymbol][LEDGER_SYSTEM_ACCOUNT], CS.groups[groupIndex].bidders[bidderIndex].bidAmount);
    //                     ledger[CS.currencySymbol][CS.groups[groupIndex].bidders[bidderIndex].bidderId] = SafeMath.safeAdd(ledger[CS.currencySymbol][CS.groups[groupIndex].bidders[bidderIndex].bidderId], CS.groups[groupIndex].bidders[bidderIndex].bidAmount);
                        
    //                     // Save bidder refund in Crowdsale contract
    //                     CS.setBidderHasReceivedTokensBack();
    //                 }
    //             }

    //             // Save group refund in Crowdsale contract
    //             CS.setGroupHasReceivedTokensBack();
    //         }
    //     }

    //     // Save losing groups refund in Crowdsale contract
    //     CS.setSentToLosingGroups();
    // }
}