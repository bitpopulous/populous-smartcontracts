/**
This is the core module of the system. Currently it holds the code of
the Bank and Auction modules to avoid external calls and higher gas costs.
It might be a good idea in the future to split the code, separate Bank
and Auction modules into external files and have the core interact with them
with addresses and interfaces. 
*/
pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract iCrowdsale {
    address public currency;
    uint public invoiceAmount;
    bytes32 public borrowerId;
    uint8 public status;
    
    uint public winnerGroupIndex;
    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;

    function isDeadlineReached() returns(bool);
    function getStatus() public constant returns (uint8);
    function getGroupsCount() public constant returns (uint);
    function getGroup(uint groupIndex) public constant returns (string name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack);
    function getGroupBidder(uint groupIndex, uint bidderIndex) public constant returns (bytes32 bidderId, bytes32 name, uint bidAmount, bool hasReceivedTokensBack);        
    function openAuction() public returns (bool);
    function bid(uint groupIndex , bytes32 bidderId, string name, uint value) returns (uint8 err, uint finalValue, uint groupGoal, bool goalReached);
    function createGroup(string _name, uint _goal) returns (uint8 err, uint groupIndex);
    function getAmountForBeneficiary() public constant returns (uint8 err, uint amount);
    function setGroupHasReceivedTokensBack(uint groupIndex);
    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex);
    function setSentToBeneficiary();
    function setSentToLosingGroups();
    function setSentToWinnerGroup();
}

contract iCrowdsaleManager {
    function createCrowdsale(
            address _currency,
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            string _borrowerName,
            string _buyerName,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal) returns (address);
}

/**
1 fees coming from the winner group before beneficiary
*/

contract Populous is withAccessManager {

    bytes32 constant LEDGER_SYSTEM_ACCOUNT = "Populous";

    event EventNewCurrency(bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventNewCrowdsale(address crowdsale);
    event EventDeposit(address from, bytes32 clientId, bytes32 currency, uint amount);
    
    // This has to be the same one as in Crowdsale
    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    iCrowdsaleManager public CM;

    // currencySymbol => (accountId => amount)
    mapping(bytes32 => mapping(bytes32 => uint)) ledger;
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;

    function Populous(address _accessManager) withAccessManager(_accessManager) { }

    function setCM(address _crowdsaleManager) {
        CM = iCrowdsaleManager(_crowdsaleManager);
    }

    /**
    BANK MODULE
    */
    function createCurrency(bytes32 _tokenName, uint8 _decimalUnits, bytes32 _tokenSymbol)
        onlyGuardian
    {
        currencies[_tokenSymbol] = new CurrencyToken(address(AM), _tokenName, _decimalUnits, _tokenSymbol);
        
        if (currencies[_tokenSymbol] == 0x0) { throw; }

        currenciesSymbols[currencies[_tokenSymbol]] = _tokenSymbol;

        EventNewCurrency(_tokenName, _decimalUnits, _tokenSymbol, currencies[_tokenSymbol]);
    }

    function getCurrency(bytes32 currency) constant returns (address) {
        return currencies[currency];
    }

    function getCurrencySymbol(address currency) constant returns (bytes32) {
        return currenciesSymbols[currency];
    }

    // Deposit function called by our external ERC23 tokens upon transfer to the contract
    function tokenFallback(address from, uint amount, bytes data) {
        bytes32 currencySymbol = currenciesSymbols[msg.sender];
        if (currencySymbol.length == 0) { throw; }

        bytes32 clientId;
        assembly {
            clientId := mload(add(data, 32))
        }
        if (CurrencyToken(msg.sender).destroyTokens(amount) == false) { throw; }
        
        ledger[currencySymbol][clientId] = SafeMath.safeAdd(ledger[currencySymbol][clientId], amount);
        EventDeposit(from, clientId, currencySymbol, amount);
    }

    function withdraw(address clientExternal, bytes32 client, bytes32 currency, uint amount) onlyGuardian {
        if (currencies[currency] == 0x0 || ledger[currency][client] < amount) { throw; }

        ledger[currency][client] = SafeMath.safeSub(ledger[currency][client], amount);

        CurrencyToken(currencies[currency]).mintTokens(amount);
        if (CurrencyToken(currencies[currency]).transfer(clientExternal, amount) == false) { throw; }
    }
    
    function mintTokens(bytes32 currency, uint amount)
        onlyGuardian
        returns (bool success)
    {
        return _mintTokens(currency, amount);
    }

    function _mintTokens(bytes32 currency, uint amount)
        private
        returns (bool success)
    {
        if (currencies[currency] != 0x0) {
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
        return _destroyTokens(currency, amount);
    }
    
    function _destroyTokens(bytes32 currency, uint amount)
        private
        returns (bool success)
    {
        if (currencies[currency] != 0x0) {
            ledger[currency][LEDGER_SYSTEM_ACCOUNT] = SafeMath.safeSub(ledger[currency][LEDGER_SYSTEM_ACCOUNT], amount);
            return true;
        } else {
            return false;
        }
    }

    function getLedgerEntry(bytes32 currency, bytes32 accountId) constant returns (uint) {
        return ledger[currency][accountId];
    }    

    function transfer(bytes32 currency, bytes32 from, bytes32 to, uint amount) onlyServer {
        _transfer(currency, from, to, amount);
    }

    function _transfer(bytes32 currency, bytes32 from, bytes32 to, uint amount) private {
        if (ledger[currency][from] < amount) { throw; }
    
        ledger[currency][from] = SafeMath.safeSub(ledger[currency][from], amount);
        ledger[currency][to] = SafeMath.safeAdd(ledger[currency][to], amount);
    }
    /**
    END OF BANK MODULE
    */

    /**
    AUCTION MODULE
    */
    function createCrowdsale(
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            string _borrowerName,
            string _buyerName,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal)
        onlyServer
    {
        if (currencies[_currencySymbol] == 0x0) { throw; }

        address crowdsaleAddr = CM.createCrowdsale(
            currencies[_currencySymbol],
            _currencySymbol,
            _borrowerId,
            _borrowerName,
            _buyerName,
            _invoiceId,
            _invoiceNumber,
            _invoiceAmount,
            _fundingGoal            
        );

        EventNewCrowdsale(crowdsaleAddr);
    }

    function bid(address crowdsaleAddr, uint groupIndex, bytes32 bidderId, string name, uint value) returns (bool success) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        uint8 err;
        uint finalValue;
        uint groupGoal;
        bool goalReached;
        (err, finalValue, groupGoal, goalReached) = CS.bid(groupIndex, bidderId, name, value);

        if (err == 0) {
            _transfer(currenciesSymbols[CS.currency()], bidderId, LEDGER_SYSTEM_ACCOUNT, finalValue);
            return true;
        } else {
            return false;
        }
    }

    function fundBeneficiary(address crowdsaleAddr) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

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

    function invoicePaymentReceived(address crowdsaleAddr, uint paidAmount) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.WaitingForInvoicePayment || CS.sentToWinnerGroup() == true) { return; }   

        _mintTokens(currenciesSymbols[CS.currency()], paidAmount);

        fundWinnerGroup(crowdsaleAddr, paidAmount);
    }

    /**
        @dev This function has to be split, because it might exceed the gas limit, if the bidders are too many.
        Platform profit has to be subtracted from total amount.
    */
    function fundWinnerGroup(address crowdsaleAddr, uint paidAmount) private {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        uint winnerGroupIndex = CS.winnerGroupIndex();
        uint biddersCount;
        uint amountRaised;
        bool hasReceivedTokensBack;

        (, , biddersCount, amountRaised, hasReceivedTokensBack) = CS.getGroup(winnerGroupIndex);

        if (hasReceivedTokensBack == true) { throw; }

        bytes32 currency = currenciesSymbols[CS.currency()];

        for (uint bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
            bytes32 bidderId;
            uint bidAmount;
            bool bidderHasReceivedTokensBack;
            (bidderId, , bidAmount, bidderHasReceivedTokensBack) = CS.getGroupBidder(winnerGroupIndex, bidderIndex);

            // Check if bidder has already been funded
            if (bidderHasReceivedTokensBack == true) { continue; }

            // Fund winning bidder based on his contribution
            uint benefitsAmount = bidAmount * paidAmount / amountRaised;

            _transfer(currency, LEDGER_SYSTEM_ACCOUNT, bidderId, benefitsAmount);
            
            // Save bidder refund in Crowdsale contract
            CS.setBidderHasReceivedTokensBack(winnerGroupIndex, bidderIndex);
        }
        
        CS.setSentToWinnerGroup();
    }
    /**
    END OF AUCTION MODULE
    */
}