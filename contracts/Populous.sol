pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract Populous is Owned, SafeMath {
    uint constant TX_EXECUTE_GAS_STOP_AMOUNT = 10000;
    string constant LEDGER_SYSTEM_NAME = "Populous";

    event EventPendingTransaction(uint index, string currency, string from, string to, int amount);
    event EventCanceledTransaction(uint index, string currency, string from, string to, int amount);
    event EventExecutedTransaction(uint index, string currency, string from, string to, int amount);

    mapping(string => int) ledger;
    mapping(string => int) pendingAmounts;
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

    function Populous() Owned() {
    }

    function mintTokens(string symbol, int amount) onlyOwner returns (bool success) {
        if (currencies[symbol] != 0x0) {
            CurrencyToken(currencies[symbol]).mintTokens(amount);
            ledger[LEDGER_SYSTEM_NAME] = safeAdd(ledger[LEDGER_SYSTEM_NAME], amount);

            return true;
        } else {
            return false;
        }
    }
    
    function destroyTokens(string symbol, int amount) onlyOwner returns (bool success) {
        if (currencies[symbol] != 0x0) {
            success = CurrencyToken(currencies[symbol]).destroyTokens(amount);
        
            if (success == true) {
                ledger[LEDGER_SYSTEM_NAME] = safeSub(ledger[LEDGER_SYSTEM_NAME], amount);
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    function createCurrency(string _tokenName, uint8 _decimalUnits, string _tokenSymbol) onlyOwner {
        currencies[_tokenSymbol] = new CurrencyToken(_tokenName, _decimalUnits, _tokenSymbol);
        
        if (currencies[_tokenSymbol] == 0x0) {
            throw;
        }
    }
    
    function getLedgerEntry(string client) constant returns (int) {
        return ledger[client];
    }
    
    function getPendingLedgerEntry(string client) constant returns (int) {
        return pendingAmounts[client];
    }

    function getCurrency(string currency) constant returns (address) {
        return currencies[currency];
    }
    
    function addTransaction(string currency, string from, string to, int amount)
        onlyOwner
        returns (bool success)
    {
        if (currencies[currency] == 0x0) { throw; }
        
        if (ledger[from] + pendingAmounts[from] < amount) {
            return false;
        } else {
            pendingAmounts[from] = safeSub(pendingAmounts[from], amount);
            pendingAmounts[to] = safeAdd(pendingAmounts[to], amount);

            pendingTx[queueBackIndex] = Transaction(currency, from, to, amount, txStates.Pending);
            EventPendingTransaction(queueBackIndex, currency, from, to, amount);
            queueBackIndex++;

            return true;
        }
    }

    function txExecuteLoop()
        onlyOwner
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
        onlyOwner
        returns (bool success)
    {
        Transaction tx = pendingTx[index];

        if (tx.amount == 0 || ledger[tx.from] + pendingAmounts[tx.from] < 0) {
            return false;
        } else {
            ledger[tx.from] = safeSub(ledger[tx.from], tx.amount);
            pendingAmounts[tx.from] = safeAdd(pendingAmounts[tx.from], tx.amount);
            ledger[tx.to] = safeAdd(ledger[tx.to], tx.amount);
            pendingAmounts[tx.to] = safeSub(pendingAmounts[tx.to], tx.amount);

            tx.status = txStates.Executed;
            EventExecutedTransaction(index, tx.currency, tx.from, tx.to, tx.amount);

            return true;
        }
    }

    function cancelTransaction(uint index)
        onlyOwner
        returns (bool success)    
    {
        Transaction tx = pendingTx[index];
        
        if (tx.status != txStates.Pending) {
            return false;
        }

        pendingAmounts[tx.from] = safeAdd(pendingAmounts[tx.from], tx.amount);
        pendingAmounts[tx.to] = safeSub(pendingAmounts[tx.to], tx.amount);
        
        tx.status = txStates.Canceled;
        EventCanceledTransaction(index, tx.currency, tx.from, tx.to, tx.amount);

        return true;
    }
}