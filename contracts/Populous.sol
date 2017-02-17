pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract Populous {
    uint constant TX_EXECUTE_GAS_STOP_AMOUNT = 10000;
    string constant LEDGER_SYSTEM_NAME = "Populous";

    event EventPendingTransaction(uint index, string currency, string from, string to, int amount);
    event EventCanceledTransaction(uint index, string currency, string from, string to, int amount);
    event EventExecutedTransaction(uint index, string currency, string from, string to, int amount);

    address owner;
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
    uint public front = 0;
    uint public back = 0;

    function Populous() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) { throw; }
        _;
    }

    function changeOwner(address _owner) onlyOwner {
        owner = _owner;
    }

    function mintTokens(string symbol, int amount) onlyOwner {
        CurrencyToken(currencies[symbol]).mintTokens(amount);
        ledger[LEDGER_SYSTEM_NAME] += amount;
    }
    
    function destroyTokens(string symbol, int amount) onlyOwner returns (bool success) {
        success = CurrencyToken(currencies[symbol]).destroyTokens(amount);
        
        if (success == true) {
            ledger[LEDGER_SYSTEM_NAME] -= amount;
        }
    }

    function createCurrency(string _tokenName, uint8 _decimalUnits, string _tokenSymbol) onlyOwner {
        currencies[_tokenSymbol] = new CurrencyToken(_tokenName, _decimalUnits, _tokenSymbol);
        
        if (currencies[_tokenSymbol] == 0x0) {
            throw;
        }
    }
    
    function getLedger(string client) returns (int) {
        return ledger[client];
    }
    
    function getPending(string client) returns (int) {
        return pendingAmounts[client];
    }

    function getCurrency(string currency) returns (address) {
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
            pendingAmounts[from] -= amount;
            pendingAmounts[to] += amount;

            pendingTx[back] = Transaction(currency, from, to, amount, txStates.Pending);
            EventPendingTransaction(back, currency, from, to, amount);
            back++;

            return true;
        }
    }

    function txExecuteLoop()
        onlyOwner
    {
        while(front <= back) {
            if (pendingTx[front].status == txStates.Pending) {
                executeTx(front);
            }
            if (msg.gas < TX_EXECUTE_GAS_STOP_AMOUNT) {
                return;
            }
            front++;
        }
        front = 0;
        back = 0;        
    }
    
    function executeTx(uint index)
        onlyOwner
        returns (bool success)
    {
        Transaction tx = pendingTx[index];

        if (tx.amount == 0 || ledger[tx.from] + pendingAmounts[tx.from] < 0) {
            return false;
        } else {
            ledger[tx.from] -= tx.amount;
            pendingAmounts[tx.from] += tx.amount;
            ledger[tx.to] += tx.amount;
            pendingAmounts[tx.to] -= tx.amount;

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

        pendingAmounts[tx.from] += tx.amount;
        pendingAmounts[tx.to] -= tx.amount;
        
        tx.status = txStates.Canceled;
        EventCanceledTransaction(index, tx.currency, tx.from, tx.to, tx.amount);

        return true;
    }
}