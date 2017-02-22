pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract Crowdsale {
    function isDeadlineReached() returns(bool);
    function openAuction() returns (bool success);
    function bid(uint groupId , string bidderId, string name, uint value) returns (uint finalValue) ;
    function createGroup(string _name, uint _goal) returns (bool success);
    function getAmountForBeneficiary() returns (uint);
    function setGroupRefunded(groupId) returns (bool);
    function setSentToBeneficiary();
    function setSentToLosingGroups();
    function setSentToWinnerGroup();
}

contract CrowdsaleManager {
    function createCrowdsale(
            address _currency,
            string _borrowerId,
            string _borrowerName,
            string _buyerName,
            string _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal) returns (address);
}

contract Populous is Owned {

    uint constant TX_EXECUTE_GAS_STOP_AMOUNT = 100000;
    string constant LEDGER_SYSTEM_NAME = "Populous";

    event EventPendingTransaction(uint index, string currency, string from, string to, int amount);
    event EventCanceledTransaction(uint index, string currency, string from, string to, int amount);
    event EventExecutedTransaction(uint index, string currency, string from, string to, int amount);

    event EventNewCrowdsale(address crowdsale);
    
    CrowdsaleManager public CM;
    // currency => (accountName => amount)
    mapping(string => mapping(string => int)) ledger;
    mapping(string => mapping(string => int)) pendingAmounts;
    mapping(string => address) currencies;

    enum txStates { Unset, Pending, Canceled, Executed }

    struct Transaction {
        string currency;
        string from;
        string to;
        int amount;
        txStates status;
    }
    
    mapping(uint => Transaction) public pendingTx;
    uint public queueFrontIndex = 0;
    uint public queueBackIndex = 0;

    // @TODO change msg.sender to address _guardian
    function Populous() Owned(msg.sender, msg.sender) { }

    function setCM(address _crowdsaleManager) {
        CM = CrowdsaleManager(_crowdsaleManager);
    }

    function getLedgerEntry(string currency, string client) constant returns (int) {
        return ledger[currency][client];
    }
    
    function getPendingLedgerEntry(string currency, string client) constant returns (int) {
        return pendingAmounts[currency][client];
    }

    function getCurrency(string currency) constant returns (address) {
        return currencies[currency];
    }

    function createCurrency(string _tokenName, uint8 _decimalUnits, string _tokenSymbol)
        onlyGuardian
    {
        currencies[_tokenSymbol] = new CurrencyToken(_tokenName, _decimalUnits, _tokenSymbol);
        
        if (currencies[_tokenSymbol] == 0x0) {
            throw;
        }
    }

    function mintTokens(string currency, int amount)
        onlyGuardian
        returns (bool success)
    {
        if (currencies[currency] != 0x0) {
            CurrencyToken(currencies[currency]).mintTokens(amount);
            ledger[currency][LEDGER_SYSTEM_NAME] = SafeMath.safeAdd(ledger[currency][LEDGER_SYSTEM_NAME], amount);

            return true;
        } else {
            return false;
        }
    }
    
    function destroyTokens(string currency, int amount)
        onlyGuardian
        returns (bool success)
    {
        if (currencies[currency] != 0x0) {
            success = CurrencyToken(currencies[currency]).destroyTokens(amount);
        
            if (success == true) {
                ledger[currency][LEDGER_SYSTEM_NAME] = SafeMath.safeSub(ledger[currency][LEDGER_SYSTEM_NAME], amount);
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    function addTransaction(string currency, string from, string to, int amount)
        onlyOwner
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
    
    function executeTx(uint index)
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

    function cancelTransaction(uint index)
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
            string _borrowerId,
            string _borrowerName,
            string _buyerName,
            string _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal)
        onlyGuardian
    {
        address crowdsaleAddr = CM.createCrowdsale(
            owner,
            this,
            _currency,
            _borrowerId,
            _borrowerName,
            _buyerName,
            _invoiceId,
            _invoiceAmount,
            _fundingGoal            
        );

        EventNewCrowdsale(crowdsaleAddr);
    }

    function refundLosingGroup() {
        uint groupsCount = groups.length;

        for (uint groupId = 0; i < groupsCount; groupId++) {
            if (groupId != winnerGroupId && groups[groupId].isRefunded == false) {

            }
        }

        losingGroupsRefunded = true;        
    }
}