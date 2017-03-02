pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract iCrowdsale {
    address public currency;
    uint public invoiceAmount;
    bytes32 public borrowerId;
    uint8 public status;
    uint public latePaymentInterest = 0;
    
    uint public winnerGroupIndex;
    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;

    function isDeadlineReached() returns(bool);
    function getStatus() public constant returns (uint8);
    function getGroupsCount() public constant returns (uint);
    function getGroup(uint groupIndex) public constant returns (bytes32 name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack);
    function getGroupBidder(uint groupIndex, uint bidderIndex) public constant returns (bytes32 bidderId, bytes32 name, uint bidAmount, bool hasReceivedTokensBack);        
    function openAuction() public returns (bool);
    function bid(uint groupIndex , bytes32 bidderId, bytes32 name, uint value) returns (uint finalValue, uint groupGoal, bool goalReached);
    function createGroup(bytes32 _name, uint _goal) returns (uint8 err, uint groupIndex);
    function getAmountForBeneficiary() public constant returns (uint8 err, uint amount);
    function setGroupHasReceivedTokensBack(uint groupIndex);
    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex);
    function setSentToBeneficiary();
    function setSentToLosingGroups();
    function setSentToWinnerGroup();
    function invoicePaymentReceived();
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

    event EventNewCrowdsale(address crowdsale);
    
    iCrowdsaleManager public CM;
    // currency => (accountName => amount)
    mapping(bytes32 => mapping(bytes32 => uint)) ledger;
    mapping(bytes32 => mapping(bytes32 => uint)) pendingAmounts;
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;

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

        if (States(CS.getStatus()) != States.Closed) { return; }

        uint8 err;
        uint amount;

        (err, amount) = CS.getAmountForBeneficiary();
        if (err != 0) { throw; }

        _transfer(currenciesSymbols[CS.currency()], LEDGER_SYSTEM_ACCOUNT, CS.borrowerId(), amount);

        CS.setSentToBeneficiary();
    }

    /**
        @dev This function has to be split, because it might exceed the gas limit, if the groups and bidders are too many.
    */
    function refundLosingGroup(address crowdsaleAddr) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.Closed) { return; }

        bytes32 currency = currenciesSymbols[CS.currency()];
        uint groupsCount = CS.getGroupsCount();
        uint winnerGroupIndex = CS.winnerGroupIndex();

        // Loop all groups
        for (uint groupIndex = 0; groupIndex < groupsCount; groupIndex++) {
            uint biddersCount;
            bool hasReceivedTokensBack;
            ( , , biddersCount, , hasReceivedTokensBack) = CS.getGroup(groupIndex);

            // Check if group is not winner group and has not already been refunded
            if (groupIndex != winnerGroupIndex && hasReceivedTokensBack == false) {
                // Loop all bidders
                for (uint bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
                    bytes32 bidderId;
                    uint bidAmount;
                    bool bidderHasReceivedTokensBack;
                    (bidderId, , bidAmount, bidderHasReceivedTokensBack) = CS.getGroupBidder(groupIndex, bidderIndex);

                    // Check if bidder has already been refunded
                    if (bidderHasReceivedTokensBack == false) {
                        // Refund bidder
                        _transfer(currency, LEDGER_SYSTEM_ACCOUNT, bidderId, bidAmount);
                        
                        // Save bidder refund in Crowdsale contract
                        CS.setBidderHasReceivedTokensBack(groupIndex, bidderIndex);
                    }
                }

                // Save group refund in Crowdsale contract
                CS.setGroupHasReceivedTokensBack(groupIndex);
            }
        }

        // Save losing groups refund in Crowdsale contract
        CS.setSentToLosingGroups();
    }

    /**
        @dev This function has to be split, because it might exceed the gas limit, if the bidders are too many.
    */
    function fundWinnerGroup(address crowdsaleAddr) onlyServer {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.WaitingForInvoicePayment || CS.sentToWinnerGroup() == true) { return; }

        uint winnerGroupIndex = CS.winnerGroupIndex();
        uint biddersCount;
        uint amountRaised;
        bool hasReceivedTokensBack;

        (, , biddersCount, amountRaised, hasReceivedTokensBack) = CS.getGroup(winnerGroupIndex);

        if (hasReceivedTokensBack == true) { return; }

        bytes32 currency = currenciesSymbols[CS.currency()];
        uint invoiceAmount = CS.invoiceAmount();
        uint latePaymentInterest = CS.latePaymentInterest();

        for (uint bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
            bytes32 bidderId;
            uint bidAmount;
            bool bidderHasReceivedTokensBack;
            (bidderId, , bidAmount, bidderHasReceivedTokensBack) = CS.getGroupBidder(winnerGroupIndex, bidderIndex);

            // Check if bidder has already been funded
            if (bidderHasReceivedTokensBack == true) { continue; }

            // Fund winning bidder based on his contribution
            uint benefitsAmount = bidAmount * invoiceAmount / amountRaised;
            if (latePaymentInterest != 0) {
                benefitsAmount += latePaymentInterest * invoiceAmount / 100;
            }

            _transfer(currency, LEDGER_SYSTEM_ACCOUNT, bidderId, benefitsAmount);
            
            // Save bidder refund in Crowdsale contract
            CS.setBidderHasReceivedTokensBack(winnerGroupIndex, bidderIndex);
        }
        
        CS.setSentToWinnerGroup();
    }
}