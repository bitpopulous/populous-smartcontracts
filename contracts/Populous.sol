pragma solidity ^0.4.17;

/**
This is the core module of the system. Currently it holds the code of
the Bank and crowdsale modules to avoid external calls and higher gas costs.
It might be a good idea in the future to split the code, separate Bank
and crowdsale modules into external files and have the core interact with them
with addresses and interfaces. 
*/

import "./iERC20Token.sol";
import "./CurrencyToken.sol";
import "./DepositContract.sol";
import "./SafeMath.sol";
//import "./Utils.sol";

/// @title Populous contract
contract Populous is withAccessManager {

    // EVENTS
    event EventNewCrowdsaleBlock(bytes32 blockchainActionId, bytes32 invoiceId, uint sourceLength);
    event EventNewCrowdsaleSource(bytes32 invoiceId, uint sourceLength);
    // Bank events
    //event EventWithdrawPoken(bytes32 _blockchainActionId, address from, address to, bytes32 accountId, bytes32 currency, uint amount, uint pptFee, bool toBank);
    event EventWithdrawPPT(bytes32 blockchainActionId, bytes32 accountId, address depositContract, address to, uint amount);
    event EventWithdrawPoken(bytes32 _blockchainActionId, bytes32 accountId, bytes32 currency, uint amount, bool toBank);
    //event EventWithdrawPokens(bytes32 blockchainActionId, bytes32 accountId, address to, uint amount, bytes32 currency);
    //event EventWithdrawBank(bytes32 blockchainActionId, address from, bytes32 accountId, bytes32 currency, uint balance);
    event EventNewCurrency(bytes32 blockchainActionId, bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventNewDepositContract(bytes32 blockchainActionId, bytes32 clientId, address depositContractAddress);
    event EventNewProvider(bytes32 _blockchainActionId, bytes32 _userId, bytes32 _companyName, bytes32 _companyNumber, bytes2 countryCode);
    event EventNewInvoice(bytes32 _blockchainActionId, bytes32 _providerUserId, bytes2 invoiceCountryCode, bytes32 invoiceCompanyNumber, bytes32 invoiceCompanyName, bytes32 invoiceNumber);
    event EventProviderEnabled(bytes32 _blockchainActionId, bytes32 _userId, bytes2 _countryCode, bytes32 _companyNumber);
    event EventProviderDisabled(bytes32 _blockchainActionId, bytes32 _userId, bytes2 _countryCode, bytes32 _companyNumber);
    
    // FIELDS
    // currency symbol => currency erc20 contract address
    mapping(bytes32 => address) currencies;
    // currency address => currency symbol
    mapping(address => bytes32) currenciesSymbols;
    // blockchainActionId => boolean 
    mapping(bytes32 => bool) actionStatus;
    // blockchainActionData
    struct actionData {
        bytes32 currency;
        uint amount;
        bytes32 accountId;
        address to;
        uint pptFee;
    }
    // blockchainActionId => actionData
    mapping(bytes32 => actionData) blockchainActionIdData;

    // This variable will be used to keep track of client IDs and
    // their deposit addresses
    // clientId => depositAddress
    mapping(bytes32 => address) depositAddress;

    //actionId => invoiceId
    mapping(bytes32 => bytes32) actionIdToInvoiceId;
    // invoice provider company data
    struct providerCompany {
        bool isEnabled;
        bytes32 companyNumber;
        bytes32 companyName;
        bytes2 countryCode;
    }
    // companyCode => companyNumber => providerId
    mapping(bytes2 => mapping(bytes32 => bytes32)) providerData;
    // providedId => providerCompany
    mapping(bytes32 => providerCompany) providerCompanyData;
    // crowdsale invoiceDetails
    struct _invoiceDetails {
        bytes2 invoiceCountryCode;
        bytes32 invoiceCompanyNumber;
        bytes32 invoiceCompanyName;
        bytes32 invoiceNumber;
    }
    // crowdsale invoiceData
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

    /** @dev Enable a previously added invoice provider with access to add an invoice to the blockchain
      * @param _blockchainActionId the blockchain action id
      * @param _userId the user id of the invoiceProvider
      */
    function enableProvider(bytes32 _blockchainActionId, bytes32 _userId)
        public
        onlyServer
    {
        require(actionStatus[_blockchainActionId] == false);
        require(providerCompanyData[_userId].isEnabled == false);
        providerCompanyData[_userId].isEnabled = true;
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0, 0);
        EventProviderEnabled(_blockchainActionId, _userId, providerCompanyData[_userId].countryCode, providerCompanyData[_userId].companyNumber);
    }

    /** @dev Disable access granted to a previously added invoice provider
      * @param _blockchainActionId the blockchain action id
      * @param _userId the user id of the invoiceProvider
      */
    function disableProvider(bytes32 _blockchainActionId, bytes32 _userId)
        public
        onlyServer
    {
        require(actionStatus[_blockchainActionId] == false);
        require(providerCompanyData[_userId].isEnabled == true);  
        providerCompanyData[_userId].isEnabled = false;
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0, 0);
        EventProviderDisabled(_blockchainActionId, _userId, providerCompanyData[_userId].countryCode, providerCompanyData[_userId].companyNumber);
    }

    /** @dev Add a new invoice provider to the platform  
      * @param _blockchainActionId the blockchain action id
      * @param _userId the user id of the provider
      * @param _companyNumber the providers company number
      * @param _companyName the providers company name
      * @param _countryCode the providers country code
      */
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

        providerData[_countryCode][_companyNumber] = _userId;
        
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0, 0);
        EventNewProvider(_blockchainActionId, _userId, _companyName, _companyNumber, _countryCode);
    }

    /** @dev Add a new crowdsale invoice from an invoice provider to the platform  
      * @param _blockchainActionId the blockchain action id
      * @param _providerUserId the user id of the provider
      * @param _invoiceCompanyNumber the providers company number
      * @param _invoiceCompanyName the providers company name
      * @param _invoiceCountryCode the providers country code
      * @param _invoiceNumber the invoice identification number
      */
    function addInvoice(
        bytes32 _blockchainActionId, bytes32 _providerUserId, bytes2 _invoiceCountryCode, 
        bytes32 _invoiceCompanyNumber, bytes32 _invoiceCompanyName, bytes32 _invoiceNumber)
        public
    {
        require(actionStatus[_blockchainActionId] == false);
        require(providerCompanyData[_providerUserId].isEnabled == true);
        
        require(invoices[_invoiceCountryCode][_invoiceCompanyNumber][_invoiceNumber].providerUserId == 0x0);
        // country code => company number => invoice number => invoice data
        invoices[_invoiceCountryCode][_invoiceCompanyNumber][_invoiceNumber].providerUserId = _providerUserId;
        invoices[_invoiceCountryCode][_invoiceCompanyNumber][_invoiceNumber].invoiceCompanyName = _invoiceCompanyName;
        actionStatus[_blockchainActionId] = true;
        setBlockchainActionData(_blockchainActionId, 0x0, 0, _providerUserId, 0x0, 0);
        EventNewInvoice(_blockchainActionId, _providerUserId, _invoiceCountryCode, _invoiceCompanyNumber, _invoiceCompanyName, _invoiceNumber);
    }

    /** @dev Import an amount of pokens of a particular currency from an ethereum wallet/address to bank
      * @param _blockchainActionId the blockchain action id
      * @param accountId the account id of the client
      * @param from the blockchain address to import pokens from
      * @param currency the poken currency
      */

    function withdrawPoken(
        bytes32 _blockchainActionId, bytes32 currency, uint amount,
        address from, address to, bytes32 accountId, uint inCollateral,
        address pptAddress, uint pptFee, address adminExternalWallet, bool toBank) 
        public 
        onlyServer 
    {
        require(actionStatus[_blockchainActionId] == false);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0 && currencies[currency] != 0x0);
        DepositContract o = DepositContract(getDepositAddress(accountId));
        // check if pptbalance minus collateral held is more than pptFee then transfer pptFee from users ppt deposit to adminWallet
        require((SafeMath.safeSub(o.balanceOf(pptAddress), inCollateral) >= pptFee) && (o.transfer(pptAddress, adminExternalWallet, pptFee) == true));
        CurrencyToken cT = CurrencyToken(currencies[currency]);
        if (toBank == true) {
            //WITHDRAW BANK

            // transfer pokens in specified amount and destroy
            require((cT.balanceOf(from) >= amount) && (cT.destroyTokensFrom(amount, from) == true));
            
            actionStatus[_blockchainActionId] = true;
            setBlockchainActionData(_blockchainActionId, currency, amount, accountId, from, pptFee); 
            //emit event: Imported currency to system
            EventWithdrawPoken(_blockchainActionId, accountId, currency, amount, toBank);
        } else {
            // WITHDRAW POKEN        
        
            //credit ledger
            cT.mintTokens(amount);
            //credit account
            cT.transfer(to, amount);

            actionStatus[_blockchainActionId] = true;            
            setBlockchainActionData(_blockchainActionId, currency, amount, accountId, to, pptFee); 
            //emit event: Exported currency to wallet
            EventWithdrawPoken(_blockchainActionId, accountId, currency, amount, toBank);
        }   
    }

    /** @dev Withdraw an amount of PPT Populous tokens to a blockchain address 
      * @param _blockchainActionId the blockchain action id
      * @param pptAddress the address of the PPT smart contract
      * @param accountId the account id of the client
      * @param pptFee the amount of fees to pay in PPT tokens
      * @param adminExternalWallet the platform admin wallet address to pay the fees to 
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
        setBlockchainActionData(_blockchainActionId, token.symbol(), amount, accountId, to, pptFee);
        EventWithdrawPPT(_blockchainActionId, accountId, o, to, amount);
    }


    /** @dev set blockchain action data in struct 
      * @param _blockchainActionId the blockchain action id
      * @param currency the token currency symbol
      * @param accountId the clientId
      * @param to the blockchain address or smart contract address used in the transaction
      * @param amount the amount of tokens in the transaction
      */
    function setBlockchainActionData(
        bytes32 _blockchainActionId, bytes32 currency, 
        uint amount, bytes32 accountId, address to, uint pptFee) 
        private 
    {
        require(actionStatus[_blockchainActionId] == true);
        blockchainActionIdData[_blockchainActionId].currency = currency;
        blockchainActionIdData[_blockchainActionId].amount = amount;
        blockchainActionIdData[_blockchainActionId].accountId = accountId;
        blockchainActionIdData[_blockchainActionId].to = to;
        blockchainActionIdData[_blockchainActionId].pptFee = pptFee;
    }

    // CONSTANT METHODS

    /** @dev Get the blockchain action Id Data for a blockchain Action id
      * @param _blockchainActionId the blockchain action id
      * @return bytes32 currency
      * @return uint amount
      * @return bytes32 accountId
      * @return address to
      */
    function getBlockchainActionIdData(bytes32 _blockchainActionId) public view 
    returns (bytes32 _currency, uint _amount, bytes32 _accountId, address _to) 
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
    function getActionStatus(bytes32 _blockchainActionId) public view returns (bool _blockchainActionStatus) {
        return actionStatus[_blockchainActionId];
    }

    /** @dev Gets the address of a currency.
      * @param currency The currency.
      * @return address The currency address.
      */
    function getCurrency(bytes32 currency) public view returns (address _currencyAddress) {
        return currencies[currency];
    }

    /** @dev Gets the currency symbol of a currency.
      * @param currency The currency.
      * @return bytes32 The currency sybmol, e.g., GBP.
      */
    function getCurrencySymbol(address currency) public view returns (bytes32 currencySymbol) {
        return currenciesSymbols[currency];
    }

    /** @dev Gets the deposit address linked to a given client ID.
      * @param clientId The client ID.
      * @return address The deposit address.
      */
    function getDepositAddress(bytes32 clientId) public view returns (address _depositAddress) {
        return depositAddress[clientId];
    }

    /** @dev Gets the details of an invoice with the country code, company number and invocie number.
      * @param _invoiceCountryCode The country code.
      * @param _invoiceCompanyNumber The company number.
      * @param _invoiceNumber The invoice number
      * @return providerUserId The invoice provider user Id
      * @return invoiceCompanyName the invoice company name
      */
    function getInvoice(bytes2 _invoiceCountryCode, bytes32 _invoiceCompanyNumber, bytes32 _invoiceNumber) 
        public 
        view 
        returns (bytes32 providerUserId, bytes32 invoiceCompanyName) 
    {   
        bytes32 _providerUserId = invoices[_invoiceCountryCode][_invoiceCompanyNumber][_invoiceNumber].providerUserId;
        bytes32 _invoiceCompanyName = invoices[_invoiceCountryCode][_invoiceCompanyNumber][_invoiceNumber].invoiceCompanyName;
        require(_providerUserId != 0x0 && _invoiceCompanyName != 0x0);

        return (_providerUserId, _invoiceCompanyName);
    }

    /** @dev Gets the details of an invoice provider with the country code and company number.
      * @param _providerCountryCode The country code.
      * @param _providerCompanyNumber The company number.
      * @return isEnabled The boolean value true/false indicating whether invoice provider is enabled or not
      * @return providerId The invoice provider user Id
      * @return companyName the invoice company name
      */
    function getProviderByCountryCodeCompanyNumber(bytes2 _providerCountryCode, bytes32 _providerCompanyNumber) 
        public 
        view 
        returns (bytes32 providerId, bytes32 companyName, bool isEnabled) 
    {
        bytes32 providerUserId = providerData[_providerCountryCode][_providerCompanyNumber];

        return (providerUserId, 
        providerCompanyData[providerUserId].companyName, 
        providerCompanyData[providerUserId].isEnabled);
    }

    /** @dev Gets the details of an invoice provider with the providers user Id.
      * @param _providerUserId The provider user Id.
      * @return isEnabled The boolean value true/false indicating whether invoice provider is enabled or not
      * @return countryCode The invoice provider country code
      * @return companyName the invoice company name
      */
    function getProviderByUserId(bytes32 _providerUserId) public view 
        returns (bytes2 countryCode, bytes32 companyName, bytes32 companyNumber, bool isEnabled) 
    {
        return (providerCompanyData[_providerUserId].countryCode,
        providerCompanyData[_providerUserId].companyName,
        providerCompanyData[_providerUserId].companyNumber,
        providerCompanyData[_providerUserId].isEnabled);
    }
    
    /** @dev Gets the enabled status of an invoice provider with the providers user Id.
      * @param _userId The provider user Id.
      * @return isEnabled The boolean value true/false indicating whether invoice provider is enabled or not
      */
    function getProviderStatus(bytes32 _userId) public view returns (bool isEnabled) {
        return providerCompanyData[_userId].isEnabled;
    }
    
}