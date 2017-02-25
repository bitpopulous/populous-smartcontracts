pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract Crowdsale {
    function isDeadlineReached() returns(bool);
    function getGroupsCount() public constant returns (uint)
    function getGroup(uint groupIndex) public constant returns (string name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack);
    function getGroupBidder(uint groupIndex, uint bidderIndex) public constant returns (string bidderId, string name, uint bidAmount, bool hasReceivedTokensBack);        
    function openAuction() returns (bool success);
    function bid(uint groupIndex , string bidderId, string name, uint value) returns (uint finalValue) ;
    function createGroup(string _name, uint _goal) returns (bool success);
    function getAmountForBeneficiary() returns (uint);
    function setGroupRefunded(groupIndex) returns (bool);
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

    address[] public crowdsales;

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

        crowdsales.push(crowdsaleAddr);
        EventNewCrowdsale(crowdsaleAddr);
    }

    function createGroup(address crowdsaleAddr, string _name, uint _goal) returns (bool) {
        Crowdsale CS = Crowdsale(crowdsaleAddr);

        returns CS.createGroup(_name, _goal);
    }

    function bid(address crowdsaleAddr, uint groupIndex, string bidderId, string name, uint value) {
        Crowdsale CS = Crowdsale(crowdsaleAddr);

        uint finalAmount = CS.bid(groupIndex, bidderId, name, value);

        if (ledger[CS.currencySymbol][bidderId] < finalAmount) { throw; }

        ledger[CS.currencySymbol][bidderId] = SafeMath.safeSub(ledger[CS.currencySymbol][bidderId], finalAmount);
        ledger[CS.currencySymbol][LEDGER_SYSTEM_NAME] = SafeMath.safeAdd(ledger[CS.currencySymbol][LEDGER_SYSTEM_NAME], finalAmount);
    }

    /**
        @dev This function has to be split, because it might exceed the gas limit, if the groups and bidders are too many.
    */
    function refundLosingGroup(address crowdsaleAddr) {
        Crowdsale CS = Crowdsale(crowdsaleAddr);

        uint groupsCount = CS.getGroupsCount();

        // Loop all groups
        for (uint groupIndex = 0; groupIndex < groupsCount; groupIndex++) {
            // Check if group has already been refunded
            if (groupIndex != CS.winnergroupIndex && CS.groups[groupIndex].hasReceivedTokensBack == false) {
                uint biddersCount = CS.groups[groupIndex].bidders.length;

                // Loop all bidders
                for (uint bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
                    // Check if bidder has already been refunded
                    if (CS.groups[groupIndex].bidders[bidderIndex].hasReceivedTokensBack == false) {
                        // Refund bidder
                        ledger[CS.currencySymbol][LEDGER_SYSTEM_NAME] = SafeMath.safeSub(ledger[CS.currencySymbol][LEDGER_SYSTEM_NAME], CS.groups[groupIndex].bidders[bidderIndex].bidAmount);
                        ledger[CS.currencySymbol][bidderId] = SafeMath.safeAdd(ledger[CS.currencySymbol][bidderId], CS.groups[groupIndex].bidders[bidderIndex].bidAmount);
                        
                        // Save bidder refund in Crowdsale contract
                        CS.setBidderHasReceivedTokensBack();
                    }
                }

                // Save group refund in Crowdsale contract
                CS.setGroupHasReceivedTokensBack();
            }
        }

        // Save losing groups refund in Crowdsale contract
        CS.setSentToLosingGroups();
    }
}