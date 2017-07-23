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
    bytes32 public currencySymbol;
    uint public invoiceAmount;
    bytes32 public borrowerId;
    uint8 public status;
    uint public platformTaxPercent;
    
    uint public winnerGroupIndex;
    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;
    uint public paidAmount;

    function isDeadlineReached() returns(bool);
    function getStatus() public constant returns (uint8);
    
    function createGroup(string _name, uint _goal) returns (uint8 err, uint groupIndex);
    function bid(uint groupIndex , bytes32 bidderId, string name, uint value) returns (uint8 err, uint finalValue, uint groupGoal, bool goalReached);
    function getGroupsCount() public constant returns (uint);
    function getGroup(uint groupIndex) public constant returns (string name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack);
    function getGroupBidder(uint groupIndex, uint bidderIndex) public constant returns (bytes32 bidderId, bytes32 name, uint bidAmount, bool hasReceivedTokensBack);        

    function getAmountForBeneficiary() public constant returns (uint8 err, uint amount);
    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex);
    function setSentToBeneficiary();
    function setPaidAmount(uint _paidAmount);
}

contract iCrowdsaleManager {
    function createCrowdsale(
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal,
            uint _platformTaxPercent,
            string _signedDocumentIPFSHash)
            returns (address);
}

contract iDepositContractsManager {
    function create(bytes32 clientId) returns (address);
}

contract Populous is withAccessManager {

    // Bank events
    event EventNewCurrency(bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventMintTokens(bytes32 currency, uint amount);
    event EventDestroyTokens(bytes32 currency, uint amount);
    event EventInternalTransfer(bytes32 currency, bytes32 fromId, bytes32 toId, uint amount);
    event EventWithdrawal(address to, bytes32 clientId, bytes32 currency, uint amount);
    event EventDeposit(address from, bytes32 clientId, bytes32 currency, uint amount);

    // Auction events
    event EventNewCrowdsale(address crowdsale);
    event EventBeneficiaryFunded(address crowdsaleAddr, bytes32 borrowerId, bytes32 currency, uint amount);
    event EventLosingGroupBidderRefunded(address crowdsaleAddr, uint groupIndex, bytes32 bidderId, bytes32 currency, uint amount);
    event EventPaymentReceived(address crowdsaleAddr, bytes32 currency, uint amount);
    event EventWinnerGroupBidderFunded(address crowdsaleAddr, uint groupIndex, bytes32 bidderId, bytes32 currency, uint bidAmount, uint benefitsAmount);

    // PPT deposits events
    event EventNewPPTDepositContract(bytes32 clientId, address depositContractAddress);

    bytes32 constant LEDGER_SYSTEM_ACCOUNT = "Populous";
    // This has to be the same one as in Crowdsale
    enum States { Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed }

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
        // Check if currency already exists
        if (currencies[_tokenSymbol] != 0x0) { throw; }

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

    function withdraw(address clientExternal, bytes32 clientId, bytes32 currency, uint amount) onlyGuardian {
        if (currencies[currency] == 0x0 || ledger[currency][clientId] < amount) { throw; }

        ledger[currency][clientId] = SafeMath.safeSub(ledger[currency][clientId], amount);

        CurrencyToken(currencies[currency]).mintTokens(amount);
        if (CurrencyToken(currencies[currency]).transfer(clientExternal, amount) == false) { throw; }

        EventWithdrawal(clientExternal, clientId, currency, amount);
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
            EventMintTokens(currency, amount);
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
            EventDestroyTokens(currency, amount);
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

        EventInternalTransfer(currency, from, to, amount);
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
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal,
            uint _platformTaxPercent,
            string _signedDocumentIPFSHash)
        onlyServer
    {
        if (currencies[_currencySymbol] == 0x0) { throw; }

        address crowdsaleAddr = CM.createCrowdsale(
            _currencySymbol,
            _borrowerId,
            _invoiceId,
            _invoiceNumber,
            _invoiceAmount,
            _fundingGoal,
            _platformTaxPercent,
            _signedDocumentIPFSHash
        );

        EventNewCrowdsale(crowdsaleAddr);
    }

    function bid(address crowdsaleAddr, uint groupIndex, bytes32 bidderId, string name, uint value)
        onlyServer
        returns (bool success)
    {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        uint8 err;
        uint finalValue;
        uint groupGoal;
        bool goalReached;
        (err, finalValue, groupGoal, goalReached) = CS.bid(groupIndex, bidderId, name, value);

        if (err == 0) {
            _transfer(CS.currencySymbol(), bidderId, LEDGER_SYSTEM_ACCOUNT, finalValue);
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
        if (err != 0) { return; }

        bytes32 borrowerId = CS.borrowerId();
        bytes32 currency = CS.currencySymbol();
        _transfer(currency, LEDGER_SYSTEM_ACCOUNT, borrowerId, amount);

        CS.setSentToBeneficiary();

        EventBeneficiaryFunded(crowdsaleAddr, borrowerId, currency, amount);
    }

    /**
        @dev This function has to be split, because it might exceed the gas limit, if the groups and bidders are too many.
    */
    function refundLosingGroups(address crowdsaleAddr) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.Closed) { return; }

        bytes32 currency = CS.currencySymbol();
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

                        EventLosingGroupBidderRefunded(crowdsaleAddr, groupIndex, bidderId, currency, bidAmount);
                    }
                }
            }
        }
    }

    function refundLosingGroupBidder(address crowdsaleAddr, uint groupIndex, uint bidderIndex) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.Closed) { return; }

        uint winnerGroupIndex = CS.winnerGroupIndex();
        if (winnerGroupIndex == groupIndex) {
            return;
        }

        bytes32 bidderId;
        uint bidAmount;
        bool bidderHasReceivedTokensBack;
        (bidderId, , bidAmount, bidderHasReceivedTokensBack) = CS.getGroupBidder(groupIndex, bidderIndex);

        if (bidderHasReceivedTokensBack == false && bidderId.length != 0) {
            bytes32 currency = CS.currencySymbol();
            _transfer(currency, LEDGER_SYSTEM_ACCOUNT, bidderId, bidAmount);
            
            // Save bidder refund in Crowdsale contract
            CS.setBidderHasReceivedTokensBack(groupIndex, bidderIndex);

            EventLosingGroupBidderRefunded(crowdsaleAddr, groupIndex, bidderId, currency, bidAmount);
        }
    }

    function invoicePaymentReceived(address crowdsaleAddr, uint paidAmount) onlyServer {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.WaitingForInvoicePayment || CS.sentToWinnerGroup() == true) { return; }   

        bytes32 currency = CS.currencySymbol();
        _mintTokens(currency, paidAmount);

        CS.setPaidAmount(paidAmount);
        
        EventPaymentReceived(crowdsaleAddr, currency, paidAmount);
    }
    
    function fundWinnerGroup(address crowdsaleAddr) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.PaymentReceived) { return; }

        uint winnerGroupIndex = CS.winnerGroupIndex();
        uint biddersCount;
        uint amountRaised;
        bool hasReceivedTokensBack;

        (, , biddersCount, amountRaised, hasReceivedTokensBack) = CS.getGroup(winnerGroupIndex);

        if (hasReceivedTokensBack == true) { return; }

        bytes32 currency = CS.currencySymbol();
        uint paidAmount = CS.paidAmount();

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

            EventWinnerGroupBidderFunded(crowdsaleAddr, winnerGroupIndex, bidderId, currency, bidAmount, benefitsAmount);
        }
    }

    function fundWinnerGroupBidder(address crowdsaleAddr, uint bidderIndex) {
        iCrowdsale CS = iCrowdsale(crowdsaleAddr);

        if (States(CS.getStatus()) != States.PaymentReceived) { return; }

        uint winnerGroupIndex = CS.winnerGroupIndex();
        
        bytes32 bidderId;
        uint bidAmount;
        bool bidderHasReceivedTokensBack;
        (bidderId, , bidAmount, bidderHasReceivedTokensBack) = CS.getGroupBidder(winnerGroupIndex, bidderIndex);

        if (bidderHasReceivedTokensBack == false && bidderId.length != 0) {
            uint amountRaised;
            (, , , amountRaised, ) = CS.getGroup(winnerGroupIndex);

            bytes32 currency = CS.currencySymbol();
            uint paidAmount = CS.paidAmount();
            // Fund winning bidder based on his contribution
            uint benefitsAmount = bidAmount * paidAmount / amountRaised;

            _transfer(currency, LEDGER_SYSTEM_ACCOUNT, bidderId, benefitsAmount);
            
            // Save bidder refund in Crowdsale contract
            CS.setBidderHasReceivedTokensBack(winnerGroupIndex, bidderIndex);

            EventWinnerGroupBidderFunded(crowdsaleAddr, winnerGroupIndex, bidderId, currency, bidAmount, benefitsAmount);
        }
    }    
    /**
    END OF AUCTION MODULE
    */

    /**
    START OF PPT DEPOSIT MODULE
    */

    function createDepositContact(bytes32 clientId) {
        address depositContractAddress = iDepositContractsManager.create(clientId);

        EventNewPPTDepositContract(clientId, depositContractAddress);
    }

    function deposit(bytes32 clientId, uint depositAmount, bytes32 receiveCurrency, uint receiveAmount) returns (bool) {
        if (iDepositContractsManager.deposit(clientId, depositAmount)) {
            _transfer(receiveCurrency, LEDGER_SYSTEM_ACCOUNT, clientId, receiveAmount);

            return true;
        }

        return false;
    }

    function releaseDeposit(bytes32 clientId, address receiver, bytes32 releaseCurrency, uint releaseAmount) return (bool) {
        if (iDepositContractsManager.releaseDeposit(clientId, receiver)) {
            _transfer(releaseCurrency, clientId, LEDGER_SYSTEM_ACCOUNT, releaseAmount);

            return true;
        }

        return false;
    }

    /**
    END OF PPT DEPOSIT MODULE
    */
}