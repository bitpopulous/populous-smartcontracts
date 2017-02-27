pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract iCrowdsale {
    address public currency;
    function isDeadlineReached() returns(bool);
    function getGroupsCount() public constant returns (int);
    function getGroup(int groupIndex) public constant returns (bytes32 name, int goal, int biddersCount, int amountRaised, bool hasReceivedTokensBack);
    function getGroupBidder(int groupIndex, int bidderIndex) public constant returns (bytes32 bidderId, bytes32 name, int bidAmount, bool hasReceivedTokensBack);        
    function openAuction() returns (bool success);
    function bid(int groupIndex , bytes32 bidderId, bytes32 name, int value) returns (int finalValue, int groupGoal, bool goalReached);
    function createGroup(bytes32 _name, int _goal) returns (int8 err, int groupIndex);
    function getAmountForBeneficiary() returns (int);
    function setGroupRefunded(int groupIndex) returns (bool);
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
            int _invoiceAmount,
            int _fundingGoal) returns (address);
}

contract Populous is withAccessManager {

    bytes32 constant LEDGER_SYSTEM_ACCOUNT = "Populous";

    uint constant TX_EXECUTE_GAS_STOP_AMOUNT = 100000;

    event EventPendingTransaction(int index, bytes32 currency, bytes32 from, bytes32 to, int amount);
    event EventCanceledTransaction(int index, bytes32 currency, bytes32 from, bytes32 to, int amount);
    event EventExecutedTransaction(int index, bytes32 currency, bytes32 from, bytes32 to, int amount);

    event EventNewCrowdsale(address crowdsale);
    event EventGroupCreated(int256 groupIndex, bytes32 name, int256 goal);
    event EventGroupGoalReached(int256 groupIndex, bytes32 _name, int256 goal);
    event EventNewBid(int256 groupIndex, bytes32 bidderId, bytes32 name, int256 value);    
    
    iCrowdsaleManager public CM;
    // currency => (accountName => amount)
    mapping(bytes32 => mapping(bytes32 => int)) ledger;
    mapping(bytes32 => mapping(bytes32 => int)) pendingAmounts;
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;

    enum txStates { Unset, Pending, Canceled, Executed }

    struct Transaction {
        bytes32 currency;
        bytes32 from;
        bytes32 to;
        int amount;
        txStates status;
    }
    
    mapping(int => Transaction) public pendingTx;
    int public queueFrontIndex = 0;
    int public queueBackIndex = 0;

    address[] public crowdsales;

    function Populous(address _accessManager) withAccessManager(_accessManager) { }

    function setCM(address _crowdsaleManager) {
        CM = iCrowdsaleManager(_crowdsaleManager);
    }

    function getLedgerEntry(bytes32 currency, bytes32 client) constant returns (int) {
        return ledger[currency][client];
    }
    
    function getPendingLedgerEntry(bytes32 currency, bytes32 client) constant returns (int) {
        return pendingAmounts[currency][client];
    }

    function getCurrency(bytes32 currency) constant returns (address) {
        return currencies[currency];
    }

    function createCurrency(bytes32 _tokenName, uint8 _decimalUnits, bytes32 _tokenSymbol)
        onlyGuardian
    {
        currencies[_tokenSymbol] = new CurrencyToken(address(AM), _tokenName, _decimalUnits, _tokenSymbol);
        
        if (currencies[_tokenSymbol] == 0x0) {
            throw;
        }
    }

    function mintTokens(bytes32 currency, int amount)
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
    
    function destroyTokens(bytes32 currency, int amount)
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

    function addTransaction(bytes32 currency, bytes32 from, bytes32 to, int amount)
        onlyServer
        returns (bool success)
    {
        if (currencies[currency] == 0x0) { throw; }
        
        if (ledger[currency][from] + pendingAmounts[currency][from] < amount) {
            return false;
        } else {
            pendingAmounts[currency][from] = SafeMath.safeSub(pendingAmounts[currency][from], amount);
            pendingAmounts[currency][to] = SafeMath.safeAdd(pendingAmounts[currency][to], amount);

            pendingTx[queueBackIndex] = Transaction(currency, from, to, amount, txStates.Pending);
            EventPendingTransaction(queueBackIndex, currency, from, to, amount);
            queueBackIndex++;

            return true;
        }
    }

    function txExecuteLoop()
        onlyGuardian
    {
        while(queueFrontIndex <= queueBackIndex) {
            if (pendingTx[queueFrontIndex].status == txStates.Pending) {
                executeTx(queueFrontIndex);
            }
            if (msg.gas < TX_EXECUTE_GAS_STOP_AMOUNT) {
                return;
            }
            queueFrontIndex++;
        }
        queueFrontIndex = 0;
        queueBackIndex = 0;        
    }
    
    function executeTx(int index)
        onlyGuardian
        returns (bool success)
    {
        Transaction tx = pendingTx[index];

        if (tx.amount == 0 || ledger[tx.currency][tx.from] + pendingAmounts[tx.currency][tx.from] < 0) {
            return false;
        } else {
            ledger[tx.currency][tx.from] = SafeMath.safeSub(ledger[tx.currency][tx.from], tx.amount);
            pendingAmounts[tx.currency][tx.from] = SafeMath.safeAdd(pendingAmounts[tx.currency][tx.from], tx.amount);
            ledger[tx.currency][tx.to] = SafeMath.safeAdd(ledger[tx.currency][tx.to], tx.amount);
            pendingAmounts[tx.currency][tx.to] = SafeMath.safeSub(pendingAmounts[tx.currency][tx.to], tx.amount);

            tx.status = txStates.Executed;
            EventExecutedTransaction(index, tx.currency, tx.from, tx.to, tx.amount);

            return true;
        }
    }

    function cancelTransaction(int index)
        onlyGuardian
        returns (bool success)    
    {
        Transaction tx = pendingTx[index];
        
        if (tx.status != txStates.Pending) {
            return false;
        }

        pendingAmounts[tx.currency][tx.from] = SafeMath.safeAdd(pendingAmounts[tx.currency][tx.from], tx.amount);
        pendingAmounts[tx.currency][tx.to] = SafeMath.safeSub(pendingAmounts[tx.currency][tx.to], tx.amount);
        
        tx.status = txStates.Canceled;
        EventCanceledTransaction(index, tx.currency, tx.from, tx.to, tx.amount);

        return true;
    }

    function createCrowdsale(
            address _currency,
            bytes32 _borrowerId,
            bytes32 _borrowerName,
            bytes32 _buyerName,
            bytes32 _invoiceId,
            int _invoiceAmount,
            int _fundingGoal)
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
    
    function createGroup(address crowdsaleAddr, bytes32 _name, int _goal) returns (int8 err, int groupIndex) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        (err, groupIndex) = CS.createGroup(_name, _goal);

        if (err == 0) {
            EventGroupCreated(groupIndex, _name, _goal);
        }
    }

    function bid(address crowdsaleAddr, int groupIndex, bytes32 bidderId, bytes32 name, int value) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);
        bytes32 currency = currenciesSymbols[CS.currency()];

        int finalValue;
        int groupGoal;
        bool goalReached;
        (finalValue, groupGoal, goalReached) = CS.bid(groupIndex, bidderId, name, value);

        if (ledger[currency][bidderId] < finalValue) { throw; }

        EventNewBid(groupIndex, bidderId, name, finalValue);
    
        if (goalReached == true) {
            EventGroupGoalReached(groupIndex, name, groupGoal);
        }

        ledger[currency][bidderId] = SafeMath.safeSub(ledger[currency][bidderId], finalValue);
        ledger[currency][LEDGER_SYSTEM_ACCOUNT] = SafeMath.safeAdd(ledger[currency][LEDGER_SYSTEM_ACCOUNT], finalValue);
    }

    /**
        @dev This function has to be split, because it might exceed the gas limit, if the groups and bidders are too many.
    */
    // function refundLosingGroup(address crowdsaleAddr) {
    //     iCrowdsale CS = iCrowdsale(crowdsaleAddr);

    //     int groupsCount = CS.getGroupsCount();

    //     // Loop all groups
    //     for (int groupIndex = 0; groupIndex < groupsCount; groupIndex++) {
            
    //         // Check if group has already been refunded
    //         if (groupIndex != CS.winnerGroupIndex() && CS.groups[groupIndex].hasReceivedTokensBack == false) {
    //             int biddersCount = CS.groups[groupIndex].bidders.length;

    //             // Loop all bidders
    //             for (int bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
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