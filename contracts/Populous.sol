/**
This is the core module of the system. Currently it holds the code of
the Bank and crowdsale modules to avoid external calls and higher gas costs.
It might be a good idea in the future to split the code, separate Bank
and crowdsale modules into external files and have the core interact with them
with addresses and interfaces. 
*/
pragma solidity ^0.4.17;

import "./iERC20Token.sol";
import "./CurrencyToken.sol";
import "./DepositContract.sol";
import "./SafeMath.sol";

/// @title Populous contract
contract Populous is withAccessManager {

    // EVENTS
    event EventNewCrowdsaleBlock(bytes blockchainActionId, bytes invoiceId, uint sourceLength);
    event EventNewCrowdsaleSource(bytes invoiceId, uint sourceLength);
    // Bank events
    event EventWithdrawPPT(bytes blockchainActionId, bytes32 accountId, address depositContract, address to, uint amount);
    event EventWithdrawPokens(bytes blockchainActionId, bytes32 accountId, address to, uint amount, bytes32 currency);
    event EventImportPokens(bytes blockchainActionId, address from, bytes32 accountId, bytes32 currency, uint balance);
    event EventNewCurrency(bytes blockchainActionId, bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventNewDepositContract(bytes blockchainActionId, bytes clientId, address depositContractAddress);


    // FIELDS
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;
    mapping(bytes => bool) actionStatus;

    struct actionData {
        bytes32 currency;
        uint amount;
        bytes32 accountId;
        address to;
    }

    mapping(bytes => actionData) blockchainActionIdData;

    // This variable will be used to keep track of client IDs and
    // their deposit addresses
    // clientId => depositAddress
    mapping(bytes => address) depositAddress;

    struct storageSource {
        bytes dataHash;
        bytes32 dataType; // crowdsale (creators, bids) + addresses /exchange_date/deposit_history (latest)/ -- for external auditing.
    }

    //actionId => invoiceId
    mapping(bytes => bytes) actionIdToInvoiceId;

    struct record {
       bool isSet;
       storageSource[] documents; //source[0] = ["0x23222324"]
    }

    //invoiceId => (isSet, documents ["crowdsale_log","exchange_history","deposit_history"])
    mapping(bytes => record) Blocks;


    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager) public withAccessManager(_accessManager) { }
    /**
    BANK MODULE
    */


    // NON-CONSTANT METHODS

    /** @dev Insert a crowdsale record for a specific invoice crowdsale id. 
      * Limited to only the server address or platform admin
      * @param _blockchainActionId the blockchain action id
      * @param _invoiceId the invoice id      
      * @param _ipfsHash the ipfs hash of the invoice file
      */ 
    function insertBlock(bytes _blockchainActionId, bytes _invoiceId, bytes _ipfsHash) 
    public
    onlyServer
    {
        require(Blocks[_invoiceId].isSet == false);
        require(actionStatus[_blockchainActionId] == false);

        Blocks[_invoiceId].documents.push(storageSource(
           _ipfsHash,
           "ipfs_hash")
        );

        // record the history of a crowdsale on the ledger, with internal and external logs, and interal address too so it can be easily audited using etherscan
        Blocks[_invoiceId].isSet = true;
        actionIdToInvoiceId[_blockchainActionId] = _invoiceId;
        actionStatus[_blockchainActionId] = true;
        EventNewCrowdsaleBlock(_blockchainActionId, _invoiceId, getRecordDocumentIndexes(_invoiceId));

    }

    /** @dev Insert a crowdsale record for a specific invoice crowdsale id 
      * @param _dataHash the hash of the data/record
      */ 
    function insertSource(bytes _invoiceId, bytes _dataHash, bytes32 _dataType) public {
        require(Blocks[_invoiceId].isSet == true);
        Blocks[_invoiceId].documents.push(storageSource(
           _dataHash,
           _dataType)        
        );
        EventNewCrowdsaleSource(_invoiceId, getRecordDocumentIndexes(_invoiceId));
    }
    /** @dev Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
      * @param clientId The bytes client ID
      * @return address The address of the deployed deposit contract instance.
      */
    function createAddress(bytes _blockchainActionId, bytes clientId) public
        onlyServer
    {
        require(actionStatus[_blockchainActionId] == false);
        depositAddress[clientId] = new DepositContract(clientId, AM);
        assert(depositAddress[clientId] != 0x0);
        actionStatus[_blockchainActionId] = true;
        EventNewDepositContract(_blockchainActionId, clientId, depositAddress[clientId]);
    }

    /** @dev Creates a new token/currency.
      * @param _tokenName  The name of the currency.
      * @param _decimalUnits The number of decimals the currency has.
      * @param _tokenSymbol The cyrrency symbol, e.g., GBP
      */
    function createCurrency(bytes _blockchainActionId, bytes32 _tokenName, uint8 _decimalUnits, bytes32 _tokenSymbol)
        public
        onlyServer
    {   
        require(actionStatus[_blockchainActionId] == false);
        // Check if currency already exists
        require(currencies[_tokenSymbol] == 0x0);
        currencies[_tokenSymbol] = new CurrencyToken(address(AM), _tokenName, _decimalUnits, _tokenSymbol);
        assert(currencies[_tokenSymbol] != 0x0);
        currenciesSymbols[currencies[_tokenSymbol]] = _tokenSymbol;
        actionStatus[_blockchainActionId] = true;
        EventNewCurrency(_blockchainActionId, _tokenName, _decimalUnits, _tokenSymbol, currencies[_tokenSymbol]);
    }


    /** @dev Withdraw an amount of PPT Populous tokens to a blockchain address 
      * @param _blockchainActionId the blockchain action id
      * @param pptAddress the address of the PPT smart contract
      * @param accountId the account id of the client
      * @param depositContract the address of the deposit smart contract
      * @param to the blockchain address to withdraw and transfer the pokens to
      * @param inCollateral the amount of pokens withheld by the platform
      */    
    function withdrawPPT(bytes _blockchainActionId, address pptAddress, bytes32 accountId, address depositContract, address to, uint amount, uint inCollateral) public onlyServer {
        require(actionStatus[_blockchainActionId] == false);
        DepositContract o = DepositContract(depositContract);
        uint PPT_balance = SafeMath.safeSub(o.balanceOf(pptAddress), inCollateral);
        require((PPT_balance >= amount) && (o.transfer(pptAddress, to, amount) == true));
        blockchainActionIdData[_blockchainActionId].currency = "PPT";
        blockchainActionIdData[_blockchainActionId].amount = amount;
        blockchainActionIdData[_blockchainActionId].accountId = accountId;
        blockchainActionIdData[_blockchainActionId].to = to;
        actionStatus[_blockchainActionId] = true;
        EventWithdrawPPT(_blockchainActionId, accountId, depositContract, to, amount);
    }

    /** @dev Import all pokens of a particular currency from an ethereum wallet/address 
      * @param _blockchainActionId the blockchain action id
      * @param accountId the account id of the client
      * @param from the blockchain address to import pokens from
      * @param currency the poken currency
      */
    function importPokens(bytes _blockchainActionId, bytes32 currency, address from, bytes32 accountId) public onlyServer {
        require(actionStatus[_blockchainActionId] == false);
        CurrencyToken CT = CurrencyToken(currencies[currency]);
        //check balance.
        uint256 balance = CT.balanceOf(from);
        //balance is more than 0, and balance has been destroyed.
        require(CT.balanceOf(from) > 0 && CT.destroyTokensFrom(balance, from) == true);
        
        blockchainActionIdData[_blockchainActionId].currency = currency;
        blockchainActionIdData[_blockchainActionId].amount = balance;
        blockchainActionIdData[_blockchainActionId].accountId = accountId;
        blockchainActionIdData[_blockchainActionId].to = from;
        actionStatus[_blockchainActionId] = true;
        //emit event: Imported currency to system
        EventImportPokens(_blockchainActionId, from, accountId,currency,balance);
    }

    /** @dev Withdraw an amount of pokens to an ethereum wallet/address 
      * @param _blockchainActionId the blockchain action id
      * @param accountId the account id of the client
      * @param to the blockchain address to send pokens to
      * @param amount the amount of pokens to transfer
      * @param currency the poken currency
      */
    function withdrawPoken(bytes _blockchainActionId, bytes32 accountId, address to, uint amount, bytes32 currency) public onlyServer {
        require(actionStatus[_blockchainActionId] == false);
        require(currencies[currency] != 0x0);

        CurrencyToken cT = CurrencyToken(currencies[currency]);

        //credit ledger
        cT.mintTokens(amount);
        //credit account
        cT.transfer(to, amount);
        
        blockchainActionIdData[_blockchainActionId].currency = currency;
        blockchainActionIdData[_blockchainActionId].amount = amount;
        blockchainActionIdData[_blockchainActionId].accountId = accountId;
        blockchainActionIdData[_blockchainActionId].to = to;
        actionStatus[_blockchainActionId] = true;
        //emit event: Imported currency to system
        EventWithdrawPokens(_blockchainActionId, accountId, to, amount, currency);
    }

    // CONSTANT METHODS

    /** @dev Get the blockchain invoice Id with a blockchain Action id
      * @param _blockchainActionId the blockchain action id
      * @return bytes invoiceId
      */
    function getBlockInvoiceId(bytes _blockchainActionId) public view returns (bytes) {
        require(actionIdToInvoiceId[_blockchainActionId].length != 0);
        return actionIdToInvoiceId[_blockchainActionId];
    }

    /** @dev Get the blockchain action Id Data for a blockchain Action id
      * @param _blockchainActionId the blockchain action id
      * @return bytes32 currency
      * @return uint amount
      * @return bytes32 accountId
      * @return address to
      */
    function getBlockchainActionIdData(bytes _blockchainActionId) public view 
    returns (bytes32, uint, bytes32, address) 
    {
        require(actionStatus[_blockchainActionId] == true);

        return (blockchainActionIdData[_blockchainActionId].currency, 
                blockchainActionIdData[_blockchainActionId].amount,
                blockchainActionIdData[_blockchainActionId].accountId,
                blockchainActionIdData[_blockchainActionId].to);
    }

    /** @dev Get the bool status of a blockchain Action id
      * @param _blockchainActionId the blockchain action id
      * @return bool actionStatus
      */
    function getActionStatus(bytes _blockchainActionId) public view returns (bool) {
        return actionStatus[_blockchainActionId];
    }

    /** @dev Gets the address of a currency.
      * @param currency The currency.
      * @return address The currency address.
      */
    function getCurrency(bytes32 currency) public view returns (address) {
        return currencies[currency];
    }

    /** @dev Gets the currency symbol of a currency.
      * @param currency The currency.
      * @return bytes32 The currency sybmol, e.g., GBP.
      */
    function getCurrencySymbol(address currency) public view returns (bytes32) {
        return currenciesSymbols[currency];
    }

    /** @dev Gets the deposit address linked to a given client ID.
      * @param clientId The client ID.
      * @return address The deposit address.
      */
    function getDepositAddress(bytes clientId) public view returns (address) {
        return depositAddress[clientId];
    }

    /** @dev Gets the details of an inserted crowdsale record
      * @param _invoiceId The invoice ID.
      * @param documentIndex The crowdsale document index.
      * @return dataHash
      * @return dataType
      */
    function getRecord(bytes _invoiceId, uint documentIndex) public view 
    returns(bytes, bytes32) 
    {
        return (Blocks[_invoiceId].documents[documentIndex].dataHash,
                Blocks[_invoiceId].documents[documentIndex].dataType
                );
    }

    /** @dev Gets the total numnber of document indexes of a crowdsale record
      * @param _invoiceId The invoice ID.
      * @return total number of documents per crowdsale Id
      */
    function getRecordDocumentIndexes(bytes _invoiceId) public view
    returns(uint)
    {
        return Blocks[_invoiceId].documents.length;
    }
}