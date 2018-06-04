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
import "./Utils.sol";

/// @title Populous contract
contract Populous is withAccessManager {


    // EVENTS
    event EventNewCrowdsaleBlock(bytes32 blockchainActionId, bytes32 invoiceId, uint sourceLength);
    event EventNewCrowdsaleSource(bytes32 invoiceId, uint sourceLength);
    // Bank events
    event EventWithdrawPPT(bytes32 blockchainActionId, bytes32 accountId, address depositContract, address to, uint amount);
    event EventWithdrawPokens(bytes32 blockchainActionId, bytes32 accountId, address to, uint amount, bytes32 currency);
    event EventWithdrawBank(bytes32 blockchainActionId, address from, bytes32 accountId, bytes32 currency, uint balance);
    event EventNewCurrency(bytes32 blockchainActionId, bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventNewDepositContract(bytes32 blockchainActionId, bytes32 clientId, address depositContractAddress);
    event EventNewProvider(bytes32 _blockchainActionId, bytes32 _userId, bytes32 _companyName, bytes32 _companyNumber, bytes2 countryCode);
    event EventNewInvoice(bytes32 _blockchainActionId, bytes32 _providerUserId, bytes2 invoiceCountryCode, bytes32 invoiceCompanyNumber, bytes32 invoiceCompanyName, bytes32 invoiceNumber);
    event EventProviderEnabled(bytes32 _blockchainActionId, bytes32 _userId, string response);
    event EventProviderDisabled(bytes32 _blockchainActionId, bytes32 _userId, string response);
    
    // FIELDS
    mapping(bytes32 => address) currencies;
    mapping(address => bytes32) currenciesSymbols;
    // blockchainActionId => boolean 
    mapping(bytes32 => bool) actionStatus;

    struct actionData {
        bytes32 currency;
        uint amount;
        bytes32 accountId;
        address to;
    }
    // blockchainActionId => actionData
    mapping(bytes32 => actionData) blockchainActionIdData;

    // This variable will be used to keep track of client IDs and
    // their deposit addresses
    // clientId => depositAddress
    mapping(bytes32 => address) depositAddress;

    //actionId => invoiceId
    mapping(bytes32 => bytes32) actionIdToInvoiceId;
    
    struct providerCompany {
        bool isEnabled;
        bytes32 companyNumber;
        bytes32 companyName;
        bytes2 countryCode;
    }
    // providedId => providerCompany
    mapping(bytes32 => providerCompany) providerCompanyData;


    struct _invoiceDetails {
        bytes2 invoiceCountryCode;
        bytes32 invoiceCompanyNumber;
        bytes32 invoiceCompanyName;
        bytes32 invoiceNumber;
    }

    struct invoiceData {
        bytes32 providerUserId;
        bytes32 invoiceCompanyName;
    }

    // country code => company number => invoice number => invoice data
    mapping(bytes2 => mapping(bytes32 => mapping(bytes32 => invoiceData))) invoices;

    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager) public withAccessManager(_accessManager) { }
    /**
    BANK MODULE
    */


    // NON-CONSTANT METHODS
    
    /** @dev Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
      * @param clientId The bytes32 client ID
      * @return address The address of the deployed deposit contract instance.
      */
    function createAddress(bytes32 _blockchainActionId, bytes32 clientId) public
        onlyServer
    {
        require(actionStatus[_blockchainActionId] == false);
        depositAddress[clientId] = new DepositContract(clientId, AM);
        assert(depositAddress[clientId] != 0x0);
        actionStatus[_blockchainActionId] = true;
        blockchainActionIdData[_blockchainActionId].accountId = clientId;
        blockchainActionIdData[_blockchainActionId].to = depositAddress[clientId];
        EventNewDepositContract(_blockchainActionId, clientId, depositAddress[clientId]);
    }

    /** @dev Creates a new token/currency.
      * @param _tokenName  The name of the currency.
      * @param _decimalUnits The number of decimals the currency has.
      * @param _tokenSymbol The cyrrency symbol, e.g., GBP
      */
    function createCurrency(
        bytes32 _blockchainActionId, bytes32 _tokenName, uint8 _decimalUnits, 
        bytes32 _tokenSymbol)
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
        blockchainActionIdData[_blockchainActionId].currency = _tokenSymbol;
        blockchainActionIdData[_blockchainActionId].to = currencies[_tokenSymbol];

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
    function withdrawERC20(
        bytes32 _blockchainActionId, address pptAddress, bytes32 accountId, 
        address to, uint amount, uint inCollateral, uint pptFee, address adminExternalWallet) 
        public 
        onlyServer 
    {
        require(actionStatus[_blockchainActionId] == false);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0);
        DepositContract o = DepositContract(getDepositAddress(accountId));
        uint pptBalance = SafeMath.safeSub(o.balanceOf(pptAddress), inCollateral);
        require(pptBalance >= (SafeMath.safeAdd(amount, pptFee)) && (o.transfer(pptAddress, to, amount) == true) && (o.transfer(pptAddress, adminExternalWallet, pptFee) == true));        
        actionStatus[_blockchainActionId] = true;
        
        iERC20Token token = iERC20Token(pptAddress);
        setBlockchainActionData(_blockchainActionId, token.symbol(), amount, accountId, to);
        EventWithdrawPPT(_blockchainActionId, accountId, o, to, amount);
    }

    function enableProvider(bytes32 _blockchainActionId, bytes32 _userId)
        public
        onlyServer
    {
        require(actionStatus[_blockchainActionId] == false);
        require(providerCompanyData[_userId].isEnabled == false);
        providerCompanyData[_userId].isEnabled == true;
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0);
        EventProviderEnabled(_blockchainActionId, _userId, "enabled");
    }

    function disableProvider(bytes32 _blockchainActionId, bytes32 _userId)
        public
        onlyServer
    {
        require(actionStatus[_blockchainActionId] == false);
        require(providerCompanyData[_userId].isEnabled == true);  
        providerCompanyData[_userId].isEnabled == false;
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0);
        EventProviderDisabled(_blockchainActionId, _userId, "disabled");
    }

    function addProvider(
        bytes32 _blockchainActionId, bytes32 _userId, bytes32 _companyNumber, 
        bytes32 _companyName, bytes2 _countryCode) 
        public 
        onlyServer
    {   
        require(actionStatus[_blockchainActionId] == false);
        require(providerCompanyData[_userId].companyNumber == 0x0);
        providerCompanyData[_userId].countryCode = _countryCode;
        providerCompanyData[_userId].companyName = _companyName;
        providerCompanyData[_userId].companyNumber = _companyNumber;
        providerCompanyData[_userId].isEnabled = true;
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0);
        EventNewProvider(_blockchainActionId, _userId, _companyName, _companyNumber, _countryCode);
    }

    

    function addInvoice(
        bytes32 _blockchainActionId, bytes32 _providerUserId, bytes2 _invoiceCountryCode, 
        bytes32 _invoiceCompanyNumber, bytes32 _invoiceCompanyName, bytes32 _invoiceNumber)
        public
    {
        require(actionStatus[_blockchainActionId] == false);
        require(providerCompanyData[_providerUserId].isEnabled == true);
        //change all bytes32 invoice information to lower case
        string storage invoiceCountryCode = string(_invoiceCountryCode);
        _invoiceDetails memory _invoiceInfo = _invoiceDetails(
            Utils.lower(string(_invoiceCountryCode)), 
            Utils.lower(string(_invoiceCompanyNumber)), 
            Utils.lower(string(_invoiceCompanyName)), 
            Utils.lower(string(_invoiceNumber)));

        require(invoices[_invoiceInfo.invoiceCountryCode][_invoiceInfo.invoiceCompanyNumber][_invoiceInfo.invoiceNumber].providerUserId == 0x0);
        // country code => company number => invoice number => invoice data
        invoices[_invoiceInfo.invoiceCountryCode][_invoiceInfo.invoiceCompanyNumber][_invoiceInfo.invoiceNumber].providerUserId = _providerUserId;
        invoices[_invoiceInfo.invoiceCountryCode][_invoiceInfo.invoiceCompanyNumber][_invoiceInfo.invoiceNumber].invoiceCompanyName = _invoiceCompanyName;
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _providerUserId, 0x0);
        EventNewInvoice(_blockchainActionId, _providerUserId, _invoiceInfo.invoiceCountryCode, _invoiceInfo.invoiceCompanyNumber, _invoiceInfo.invoiceCompanyName, _invoiceInfo.invoiceNumber);
    }


    function withdrawBank(bytes32 _blockchainActionId, bytes32 currency, address from, bytes32 accountId) public onlyServer {
        require(actionStatus[_blockchainActionId] == false);
        CurrencyToken CT = CurrencyToken(currencies[currency]);
        //check balance.
        uint256 balance = CT.balanceOf(from);
        //balance is more than 0, and balance has been destroyed.
        require(CT.balanceOf(from) > 0 && CT.destroyTokensFrom(balance, from) == true);
        
        actionStatus[_blockchainActionId] = true;

        setBlockchainActionData(_blockchainActionId, currency, balance, accountId, from); 

        //emit event: Imported currency to system
        EventWithdrawBank(_blockchainActionId, from, accountId, currency, balance);
    }

    /** @dev Withdraw an amount of pokens to an ethereum wallet/address 
      * @param _blockchainActionId the blockchain action id
      * @param accountId the account id of the client
      * @param to the blockchain address to send pokens to
      * @param amount the amount of pokens to transfer
      * @param currency the poken currency
      */
    function withdrawPoken(
        bytes32 _blockchainActionId, address pptAddress, bytes32 accountId, address to, 
        uint amount, bytes32 currency, uint inCollateral, uint pptFee, address adminExternalWallet) 
        public 
        onlyServer 
    {
        require(actionStatus[_blockchainActionId] == false);
        require(currencies[currency] != 0x0);

        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0);
        DepositContract o = DepositContract(getDepositAddress(accountId));
        uint pptBalance = SafeMath.safeSub(o.balanceOf(pptAddress), inCollateral);
        require(pptBalance >= (SafeMath.safeAdd(amount, pptFee)) && (o.transfer(pptAddress, to, amount) == true) && (o.transfer(pptAddress, adminExternalWallet, pptFee) == true));        
        

        CurrencyToken cT = CurrencyToken(currencies[currency]);
        //credit ledger
        cT.mintTokens(amount);
        //credit account
        cT.transfer(to, amount);
        
        actionStatus[_blockchainActionId] = true;
        
        setBlockchainActionData(_blockchainActionId, currency, amount, accountId, to);
        //emit event: Imported currency to system
        EventWithdrawPokens(_blockchainActionId, accountId, to, amount, currency);
    }


    /** @dev set blockchain action data in struct 
      * @param _blockchainActionId the blockchain action id
      * @param currency the token currency symbol
      * @param accountId the clientId
      * @param to the blockchain address or smart contract address used in the transaction
      * @param amount the amount of tokens in the transaction
      */
    function setBlockchainActionData(bytes32 _blockchainActionId, bytes32 currency, uint amount, bytes32 accountId, address to) 
        private 
    {
        require(actionStatus[_blockchainActionId] == true);
        blockchainActionIdData[_blockchainActionId].currency = currency;
        blockchainActionIdData[_blockchainActionId].amount = amount;
        blockchainActionIdData[_blockchainActionId].accountId = accountId;
        blockchainActionIdData[_blockchainActionId].to = to;
    }

    // CONSTANT METHODS

    /** @dev Get the blockchain invoice Id with a blockchain Action id
      * @param _blockchainActionId the blockchain action id
      * @return bytes32 invoiceId
      */
    function getBlockInvoiceId(bytes32 _blockchainActionId) public view returns (bytes32) {
        require(actionIdToInvoiceId[_blockchainActionId] != 0x0);
        return actionIdToInvoiceId[_blockchainActionId];
    }

    /** @dev Get the blockchain action Id Data for a blockchain Action id
      * @param _blockchainActionId the blockchain action id
      * @return bytes32 currency
      * @return uint amount
      * @return bytes32 accountId
      * @return address to
      */
    function getBlockchainActionIdData(bytes32 _blockchainActionId) public view 
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
    function getActionStatus(bytes32 _blockchainActionId) public view returns (bool) {
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
    function getDepositAddress(bytes32 clientId) public view returns (address) {
        return depositAddress[clientId];
    }

}