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
import "./DataManager.sol";
//import "./Utils.sol";

/// @title Populous contract
contract Populous is withAccessManager {

    
    // EVENTS
    // Bank events
    event EventWithdrawPPT(bytes32 blockchainActionId, bytes32 accountId, address depositContract, address to, uint amount);
    event EventWithdrawPoken(bytes32 _blockchainActionId, bytes32 accountId, bytes32 currency, uint amount, bool toBank);
    
    event EventNewCurrency(bytes32 blockchainActionId, bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventUpgradeCurrency(bytes32 blockchainActionId, bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr, uint256 version);
    
    event EventNewDepositContract(bytes32 blockchainActionId, bytes32 clientId, address depositContractAddress);
    event EventUpgradeDepositContract(bytes32 blockchainActionId, bytes32 clientId, address depositContractAddress, uint256 version);
    
    event EventNewProvider(bytes32 _blockchainActionId, bytes32 _userId, bytes32 _companyName, bytes32 _companyNumber, bytes2 countryCode);
    event EventNewInvoice(bytes32 _blockchainActionId, bytes32 _providerUserId, bytes2 invoiceCountryCode, bytes32 invoiceCompanyNumber, bytes32 invoiceCompanyName, bytes32 invoiceNumber);
    event EventProviderEnabled(bytes32 _blockchainActionId, bytes32 _userId, bytes2 _countryCode, bytes32 _companyNumber);
    event EventProviderDisabled(bytes32 _blockchainActionId, bytes32 _userId, bytes2 _countryCode, bytes32 _companyNumber);
    
    // FIELDS
    DataManager dm;

    //in constructor
    // dm = DataManager(0xD5f9D8D94886E70b06E474c3fB14Fd43E2f23970);
    //deploy DM before populous or set DM address when deploying populous


    uint256 public version = 1;
 
    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager, address _dataManager) public withAccessManager(_accessManager) { 
        dm = DataManager(_dataManager);
    }
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
        require(dm.getActionStatus(_blockchainActionId) == false);
        require(dm.setDepositAddress(new DepositContract(clientId, AM), clientId) == true);
        assert(dm.getDepositAddress(clientId) != 0x0);
        require(dm.setActionStatus(_blockchainActionId) == true);

        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, clientId, dm.getDepositAddress(clientId), 0) == true);

        //dm.blockchainActionIdData[_blockchainActionId].accountId = clientId;
        //dm.blockchainActionIdData[_blockchainActionId].to = depositAddress[clientId];
        EventNewDepositContract(_blockchainActionId, clientId, dm.getDepositAddress(clientId));
    }

    function upgradeDepositAddress(bytes32 _blockchainActionId, bytes32 _clientId, address _depositContract) public
      onlyServer
    {
        require(dm.upgradeDepositAddress(_blockchainActionId, _clientId, _depositContract) == true);
        EventUpgradeDepositContract(_blockchainActionId, _clientId, dm.getDepositAddress(_clientId), version);
    }

    /** @dev Creates a new token/currency.
      * @param _tokenName  The name of the currency.
      * @param _decimalUnits The number of decimals the currency has.
      * @param _tokenSymbol The currency symbol, e.g., GBP
      */
    function createCurrency(
        bytes32 _blockchainActionId, bytes32 _tokenName, uint8 _decimalUnits, 
        bytes32 _tokenSymbol)
        public
        onlyServer
    {   
        require(dm.getActionStatus(_blockchainActionId) == false);
        // Check if currency already exists
        //require(currencies[_tokenSymbol] == 0x0);
        require(dm.setCurrency(new CurrencyToken(address(AM), _tokenName, _decimalUnits, _tokenSymbol), _tokenSymbol) == true);
        require(dm.setActionStatus(_blockchainActionId) == true);

        require(dm.setBlockchainActionData(_blockchainActionId, _tokenSymbol, 0, 0x0, dm.getCurrency(_tokenSymbol), 0) == true);

        //blockchainActionIdData[_blockchainActionId].currency = _tokenSymbol;
        //blockchainActionIdData[_blockchainActionId].to = currencies[_tokenSymbol];

        EventNewCurrency(_blockchainActionId, _tokenName, _decimalUnits, _tokenSymbol, dm.getCurrency(_tokenSymbol));
    }


    function upgradeCurrency(bytes32 _blockchainActionId, address _currencyAddress, bytes32 _tokenSymbol) public onlyServer
    {   
        // check if blockchain action id is already used
        require(dm.getActionStatus(_blockchainActionId) == false);
        // Check if currency exists as erc20
        require(CurrencyToken(_currencyAddress).symbol() != 0x0 && CurrencyToken(_currencyAddress).name() != 0x0 && CurrencyToken(_currencyAddress).symbol() == _tokenSymbol);
        require(dm.setCurrency(_currencyAddress, _tokenSymbol) == true);
        
        require(dm.setActionStatus(_blockchainActionId) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, _tokenSymbol, 0, 0x0, _currencyAddress, 0) == true);

        //blockchainActionIdData[_blockchainActionId].currency = _tokenSymbol;
        //blockchainActionIdData[_blockchainActionId].to = currencies[_tokenSymbol];

        EventUpgradeCurrency(_blockchainActionId, CurrencyToken(_currencyAddress).name(), CurrencyToken(_currencyAddress).decimals(), _tokenSymbol, dm.getCurrency(_tokenSymbol), version);
    }

    /** @dev Enable a previously added invoice provider with access to add an invoice to the blockchain
      * @param _blockchainActionId the blockchain action id
      * @param _userId the user id of the invoiceProvider
      */
    function enableProvider(bytes32 _blockchainActionId, bytes32 _userId)
        public
        onlyServer
    {
        require(dm.getActionStatus(_blockchainActionId) == false);
        require(dm.getProviderStatus(_userId) == false);
        require(dm.setProviderStatus(_userId, true) == true);
        require(dm.setActionStatus(_blockchainActionId) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0, 0) == true);
        //bytes2 countryCode, bytes32 companyName, bytes32 companyNumber, bool isEnabled
        bytes2 countryCode;
        bytes32 companyNumber;
        (countryCode, , companyNumber, ) = dm.getProviderByUserId(_userId);
        EventProviderEnabled(_blockchainActionId, _userId, countryCode, companyNumber);
    }

    /** @dev Disable access granted to a previously added invoice provider
      * @param _blockchainActionId the blockchain action id
      * @param _userId the user id of the invoiceProvider
      */
    function disableProvider(bytes32 _blockchainActionId, bytes32 _userId)
        public
        onlyServer
    {
        require(dm.getActionStatus(_blockchainActionId) == false);
        require(dm.getProviderStatus(_userId) == true);  
        require(dm.setProviderStatus(_userId, false) == true);
        require(dm.setActionStatus(_blockchainActionId) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0, 0) == true);
        bytes2 countryCode;
        bytes32 companyNumber;
        (countryCode, , companyNumber, ) = dm.getProviderByUserId(_userId);
        EventProviderDisabled(_blockchainActionId, _userId, countryCode, companyNumber);
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
        require(dm.setProvider(_blockchainActionId, _userId, _companyNumber, _companyName, _countryCode) == true);
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
        require(dm.getActionStatus(_blockchainActionId) == false);
        require(dm.getProviderStatus(_providerUserId) == true);
        require(dm.setInvoice(_providerUserId, _invoiceCountryCode, _invoiceCompanyNumber, _invoiceCompanyName, _invoiceNumber) == true);
        require(dm.setActionStatus(_blockchainActionId) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, _providerUserId, 0x0, 0) == true);
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
        require(dm.getActionStatus(_blockchainActionId) == false && dm.getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0 && dm.getCurrency(currency) != 0x0);
        DepositContract o = DepositContract(dm.getDepositAddress(accountId));
        // check if pptbalance minus collateral held is more than pptFee then transfer pptFee from users ppt deposit to adminWallet
        require((SafeMath.safeSub(o.balanceOf(pptAddress), inCollateral) >= pptFee) && (o.transfer(pptAddress, adminExternalWallet, pptFee) == true));
        CurrencyToken cT = CurrencyToken(dm.getCurrency(currency));
        if (toBank == true) {
            //WITHDRAW BANK
            if (amount > cT.balanceOf(from)) {
                // destroying total balance
                require(cT.destroyTokensFrom(cT.balanceOf(from), from) == true);
            } else {
                // destroy amount from balance
                require((cT.balanceOf(from) >= amount) && (cT.destroyTokensFrom(amount, from) == true));
            }
            require(dm.setActionStatus(_blockchainActionId) == true);
            require(dm.setBlockchainActionData(_blockchainActionId, currency, amount, accountId, from, pptFee) == true); 
            //emit event: Imported currency to system
            EventWithdrawPoken(_blockchainActionId, accountId, currency, amount, toBank);
        } else {
            // WITHDRAW POKEN        

            //credit ledger
            cT.mintTokens(amount);
            //credit account
            cT.transfer(to, amount);

            require(dm.setActionStatus(_blockchainActionId) == true);           
            require(dm.setBlockchainActionData(_blockchainActionId, currency, amount, accountId, to, pptFee) == true); 
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
        require(dm.getActionStatus(_blockchainActionId) == false && dm.getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0);
        DepositContract o = DepositContract(dm.getDepositAddress(accountId));
        uint pptBalance = SafeMath.safeSub(o.balanceOf(pptAddress), inCollateral);
        require(pptBalance >= (SafeMath.safeAdd(amount, pptFee)) && (o.transfer(pptAddress, to, amount) == true) && (o.transfer(pptAddress, adminExternalWallet, pptFee) == true));        
        require(dm.setActionStatus(_blockchainActionId) == true); 
        
        iERC20Token token = iERC20Token(pptAddress);
        require(dm.setBlockchainActionData(_blockchainActionId, token.symbol(), amount, accountId, to, pptFee));
        EventWithdrawPPT(_blockchainActionId, accountId, o, to, amount);
    }

    // CONSTANT METHODS

    function getVersion() public view returns (uint256 _version) {
        return version;
    }

    function getDataManager() public view returns (DataManager _dm) {
        return dm;
    }
    
}