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


/// @title Populous contract
contract Populous is withAccessManager {

    // EVENTS
    event EventNewCrowdsaleBlock(bytes32 crowdsaleId, bytes invoiceId, uint sourceLength);
    // Bank events
    event EventWithdrawPPT(bytes32 accountId, address depositContract, address to, uint amount);
    event EventWithdrawPokens(bytes32 accountId, address to, uint amount, uint ledgerBalance, bytes32 currency);
    event EventNewCurrency(bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventNewDepositContract(bytes32 clientId, address depositContractAddress);

    // FIELDS
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;
    // This variable will be used to keep track of client IDs and
    // their deposit addresses
    // clientId => depositAddress
    mapping (bytes32 => address) depositAddress;

    struct storageSource {
        bytes32 dataHash1;
        bytes32 dataHash2;
        bytes32 dataSource; // upload provider: ipfs / aws (uploaded to our aws server) / ... who provides the storage for this information.
        bytes32 dataType; // crowdsale (creators, bids) + addresses /exchange_date/deposit_history (latest)/ -- for external auditing.
    }

    struct record {
       bytes32 invoiceId;
       bool isSet;
       storageSource[] documents; //source[0] = ["0x23222324"]
    }

    //crowdsaleId => (invoiceId, documents ["crowdsale_log","exchange_history","deposit_history"])
    mapping(bytes32 => record) Blocks;


    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager) public withAccessManager(_accessManager) { }
    /**
    BANK MODULE
    */


    // NON-CONSTANT METHODS
    function insertBlock(bytes32 _crowdsaleId, bytes32 _invoiceId, 
        bytes32 _ipfsHash1,
        bytes32 _ipfsHash2,
        bytes32 _awsHash1,
        bytes32 _awsHash2,
        bytes32 _dataType) 
    public
    onlyServer
    {
        require(Blocks[_crowdsaleId].isSet == false);
        Blocks[_crowdsaleId].documents.push(storageSource(
           _ipfsHash1,
           _ipfsHash2,
           "ipfs",
           _dataType)
        );

        // record the history of a crowdsale on the ledger, with internal and external logs, and interal address to so it can be easily audited using etherscan
        Blocks[_crowdsaleId].invoiceId = _invoiceId;
        Blocks[_crowdsaleId].documents.push(storageSource(
           _awsHash1,
           _awsHash2,
           "aws",
           _dataType)
        );

    }

    function insertSource(bytes32 _crowdsaleId, bytes32 _dataHash1, bytes32 _dataHash2, bytes32 _dataSource, bytes32 _dataType) public {
        require(Blocks[_crowdsaleId].isSet == true);

        Blocks[_crowdsaleId].documents.push(storageSource(
           _dataHash1,
           _dataHash2,
           _dataSource,
           _dataType)
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

    
    function withdrawPPT(address pptAddress, bytes32 accountId, address depositContract, address to, uint amount) public onlyServer {
        DepositContract o = DepositContract(depositContract);
        require(o.transfer(pptAddress, to, amount) == true);
        EventWithdrawPPT(accountId, depositContract, to, amount);
    }
    

    function withdrawPoken(bytes32 accountId, address to, uint amount, uint ledgerBalance, bytes32 currency) public onlyServer {
        CurrencyToken cT = CurrencyToken(currencies[currency]);
        
        require(ledgerBalance >= amount && currencies[currency] != 0x0);
        //credit ledger
        cT.mintTokens(amount);
        //credit account
        cT.transfer(to, amount);
        //emit event: Imported currency to system
        EventWithdrawPokens(accountId, to, amount, ledgerBalance, currency);
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
    function getRecord(bytes32 _crowdsaleId, uint documentIndex) public view 
    returns(bytes32, bytes32, bytes32, bytes32, bytes32) 
    {
        return (Blocks[_crowdsaleId].invoiceId,
                Blocks[_crowdsaleId].documents[documentIndex].dataHash1,
                Blocks[_crowdsaleId].documents[documentIndex].dataHash2,
                Blocks[_crowdsaleId].documents[documentIndex].dataSource,
                Blocks[_crowdsaleId].documents[documentIndex].dataType
                );

    }

    function getRecordDocumentIndexes(bytes32 _crowdsaleId) public view
    returns(uint)
    {
        return Blocks[_crowdsaleId].documents.length - 1;
    }
}