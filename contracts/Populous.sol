/**
This is the core module of the system. Currently it holds the code of
the Bank and crowdsale modules to avoid external calls and higher gas costs.
It might be a good idea in the future to split the code, separate Bank
and crowdsale modules into external files and have the core interact with them
with addresses and interfaces. 
*/
pragma solidity ^0.4.17;

import "./CurrencyToken.sol";
import "./DepositContract.sol";


/// @title Populous contract
contract Populous is withAccessManager {

    // EVENTS

    // Bank events
    event EventNewCurrency(bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventDestroyTokens(bytes32 currency, uint amount);
    event EventWithdrawal(address to, bytes32 clientId, bytes32 currency, uint amount, uint fee); // PPT deposits events
    event EventNewDepositContract(bytes32 clientId, address depositContractAddress);

    // FIELDS
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;
    // This variable will be used to keep track of client IDs and
    // their deposit addresses
    // clientId => depositAddress
    mapping (bytes32 => address) depositAddress;

    struct storageSource {
        bytes32 dataHash;
        bytes32 dataSource; // upload provider: ips / aws (uploaded to our aws server) / ... who provides the storage for this information.
        bytes32 dataType; // crowdsale (creators, bids) + addresses /exchange_date/deposit_history (latest)/ -- for external auditing.
    }

    struct record {
       bytes32 invoiceId;
       storageSource[] documents; //source[0] = ["0x23222324"]
    }

    //crowdsaleId => (invoiceId, documents ["crowdsale_log","exchange_history","deposit_history"])
    mapping(bytes32 => record) Records;

    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager) public withAccessManager(_accessManager) { }
    /**
    BANK MODULE
    */


    // NON-CONSTANT METHODS
    function Record(bytes32 _crowdsaleId, bytes32 _invoiceId, bytes32[] _records) public
    onlyServer
    {
        // record the history of a crowdsale on the ledger, with internal and external logs, and interal address to so it can be easily audited using etherscan
        Records[_crowdsaleId].invoiceId = _invoiceId;
        Records[_crowdsaleId].documents.push(storageSource(
           0x1,
           0x2,
           0x3)
        );

    }
       /** @dev Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
      * @param clientId The bytes32 client ID
      * @return address The address of the deployed deposit contract instance.
      */
    function createAddress(bytes32 clientId) public
        onlyServer
    {
        depositAddress[clientId] = new DepositContract(clientId, AM);
        assert(depositAddress[clientId] != 0x0);

        EventNewDepositContract(clientId, depositAddress[clientId]);
    }

    /** @dev Creates a new token/currency.
      * @param _tokenName  The name of the currency.
      * @param _decimalUnits The number of decimals the currency has.
      * @param _tokenSymbol The cyrrency symbol, e.g., GBP
      */
    function createCurrency(bytes32 _tokenName, uint8 _decimalUnits, bytes32 _tokenSymbol)
        public
        onlyServer
    {
        // Check if currency already exists
        require(currencies[_tokenSymbol] == 0x0);

        currencies[_tokenSymbol] = new CurrencyToken(address(AM), _tokenName, _decimalUnits, _tokenSymbol);
        
        assert(currencies[_tokenSymbol] != 0x0);

        currenciesSymbols[currencies[_tokenSymbol]] = _tokenSymbol;

        EventNewCurrency(_tokenName, _decimalUnits, _tokenSymbol, currencies[_tokenSymbol]);
    }

    function withdrawPPT();
    function withdrawPokens();

    function importExternalPokens(bytes32 currency, address from, bytes32 accountId) public onlyServer {
        CurrencyToken CT = CurrencyToken(currencies[currency]);
        
        //check balance.
        uint256 balance = CT.balanceOf(from);
        //balance is more than 0, and balance has been destroyed.
        require(CT.balanceOf(from) > 0 && CT.destroyTokensFrom(balance, from) == true);
        //credit ledger
        mintTokens(currency, balance);
        //credit account
        _transfer(currency, LEDGER_SYSTEM_ACCOUNT, accountId, balance);
        //emit event: Imported currency to system
       EventImportedPokens(from, accountId,currency,balance);
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
    function getDepositAddress(bytes32 clientId) public view returns (address) {
        return depositAddress[clientId];
    }
    function getRecord(bytes32 _crowdsaleId, uint documentIndex) public view returns(bytes32, bytes32, bytes32, bytes32){
   
        return (Records[_crowdsaleId].invoiceId,
                Records[_crowdsaleId].documents[documentIndex].dataHash,
                Records[_crowdsaleId].documents[documentIndex].dataSource,
                Records[_crowdsaleId].documents[documentIndex].dataType
                );

    }
    function getRecordDocumentIndexs(bytes32 _crowdsaleId) public view
    returns(uint)
    {
        return Records[_crowdsaleId].documents.length - 1;
    }
}