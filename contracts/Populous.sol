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

/// @title Populous contract
contract Populous is withAccessManager {

    
    // EVENTS
    // Bank events
    event exchangeXAUpEvent (bytes32 _blockchainActionId, address _xaup, uint eth_amount, uint xaup_amount, uint _tokenId, bytes32 _clientId, address _from);


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
    
    event DepositAddressUpgrade(address _depositAddress, bytes32 clientId, uint256 version);

    // FIELDS   

    struct tokenExchangeDetails {
        address _xaup;
        uint xaup_amount;
        uint eth_amount;
        bytes32 _clientId;
        uint expires;
        uint tokenId;
        bool completed;
    } 
    mapping (address => tokenExchangeDetails) public tokenExchange;

    //address public PXT = 0xc14830e53aa344e8c14603a91229a0b925b0b262;
    //address public PPT = 0xd4fa1460f537bb9085d22c7bccb5dd450ef28e3a;
    address public PXT = 0xd8a7c588f8dc19f49dafd8ecf08eec58e64d4cc9;
    address public PPT = 0x0ff72e24af7c09a647865820d4477f98fcb72a2c;

    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager) public withAccessManager(_accessManager) {}
    /**
    BANK MODULE
    */


    // NON-CONSTANT METHODS
    
    /** @dev Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
      * @param clientId The bytes32 client ID
      * @return address The address of the deployed deposit contract instance.
      */
    function createAddress(address _dataManager, bytes32 _blockchainActionId, bytes32 clientId) public
        onlyServer
    {   
        require(_dataManager != 0x0);
        DataManager dm = DataManager(_dataManager);
        require(dm.setDepositAddress(_blockchainActionId, new DepositContract(clientId, AM), clientId) == true);
        assert(dm.getDepositAddress(clientId) != 0x0);
        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, clientId, dm.getDepositAddress(clientId), 0) == true);

        //dm.blockchainActionIdData[_blockchainActionId].accountId = clientId;
        //dm.blockchainActionIdData[_blockchainActionId].to = depositAddress[clientId];
        EventNewDepositContract(_blockchainActionId, clientId, dm.getDepositAddress(clientId));
    }

    /** @dev Adds a deposit address for a client id from older version of populous
      * @param _blockchainActionId the blockchain action id
      * @param _clientId the client id
      * @param _depositContract The address of the deposit smartt contract
      */
    function upgradeDepositAddress(address _dataManager, bytes32 _blockchainActionId, bytes32 _clientId, address _depositContract) public
      onlyServer
    {
        require(_dataManager != 0x0);
        DataManager dm = DataManager(_dataManager);
        require(dm.setDepositAddress(_blockchainActionId, _depositContract, _clientId) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, _clientId, _depositContract, 0) == true);
        EventUpgradeDepositContract(_blockchainActionId, _clientId, dm.getDepositAddress(_clientId), dm.version());
    }

    /** @dev Creates a new token/currency.
      * @param _tokenName  The name of the currency.
      * @param _decimalUnits The number of decimals the currency has.
      * @param _tokenSymbol The currency symbol, e.g., GBP
      */
    function createCurrency(
        address _dataManager, bytes32 _blockchainActionId, 
        bytes32 _tokenName, uint8 _decimalUnits, bytes32 _tokenSymbol)
        public
        onlyServer
    {   
        require(_dataManager != 0x0);
        DataManager dm = DataManager(_dataManager);
        // Check if currency already exists
        //require(currencies[_tokenSymbol] == 0x0);
        require(dm.setCurrency(_blockchainActionId, new CurrencyToken(address(AM), _tokenName, _decimalUnits, _tokenSymbol), _tokenSymbol) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, _tokenSymbol, 0, 0x0, dm.getCurrency(_tokenSymbol), 0) == true);
        EventNewCurrency(_blockchainActionId, _tokenName, _decimalUnits, _tokenSymbol, dm.getCurrency(_tokenSymbol));
    }

    /** @dev Adds a currency from older version of populous
      * @param _blockchainActionId the blockchain action id
      * @param _currencyAddress the currency smart contract address
      * @param _tokenSymbol The token symbol of the currency
      */
    function upgradeCurrency(address _dataManager, bytes32 _blockchainActionId, address _currencyAddress, bytes32 _tokenSymbol) public onlyServer
    {   
        require(_dataManager != 0x0);
        DataManager dm = DataManager(_dataManager);
        // check if blockchain action id is already used
        // Check if currency exists as erc20
        require(CurrencyToken(_currencyAddress).symbol() != 0x0 && CurrencyToken(_currencyAddress).name() != 0x0 && CurrencyToken(_currencyAddress).symbol() == _tokenSymbol);
        require(dm.setCurrency(_blockchainActionId, _currencyAddress, _tokenSymbol) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, _tokenSymbol, 0, 0x0, _currencyAddress, 0) == true);
        EventUpgradeCurrency(_blockchainActionId, CurrencyToken(_currencyAddress).name(), CurrencyToken(_currencyAddress).decimals(), _tokenSymbol, dm.getCurrency(_tokenSymbol), dm.version());
    }

    /** @dev Add a new invoice provider to the platform  
      * @param _blockchainActionId the blockchain action id
      * @param _userId the user id of the provider
      * @param _companyNumber the providers company number
      * @param _companyName the providers company name
      * @param _countryCode the providers country code
      */
    function addProvider(
        address _dataManager, bytes32 _blockchainActionId, 
        bytes32 _userId, bytes32 _companyNumber, 
        bytes32 _companyName, bytes2 _countryCode) 
        public 
        onlyServer
    {   
        require(_dataManager != 0x0);
        DataManager dm = DataManager(_dataManager);
        require(dm.setProvider(_blockchainActionId, _userId, _companyNumber, _companyName, _countryCode) == true);
        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, _userId, 0x0, 0) == true);
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
        address _dataManager, bytes32 _blockchainActionId, 
        bytes32 _providerUserId, bytes2 _invoiceCountryCode, 
        bytes32 _invoiceCompanyNumber, bytes32 _invoiceCompanyName, bytes32 _invoiceNumber)
        public
        onlyServer
    {
        require(_dataManager != 0x0);
        DataManager dm = DataManager(_dataManager);
        bytes2 countryCode; 
        bytes32 companyName; 
        bytes32 companyNumber;
        (countryCode, companyName, companyNumber) = dm.getProviderByUserId(_providerUserId);
        //require(dm.getProviderStatus(_providerUserId) == true);
        require(countryCode != 0x0 && companyName != 0x0 && companyNumber != 0x0);
        require(dm.setInvoice(_blockchainActionId, _providerUserId, _invoiceCountryCode, _invoiceCompanyNumber, _invoiceCompanyName, _invoiceNumber) == true);
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
        address _dataManager, bytes32 _blockchainActionId, 
        bytes32 currency, uint amount,
        address from, address to, bytes32 accountId, uint inCollateral,
        address pptAddress, uint pptFee, address adminExternalWallet, bool toBank) 
        public 
        onlyServer 
    {
        require(_dataManager != 0x0);
        //DataManager dm = DataManager(_dataManager);
        require(DataManager(_dataManager).getActionStatus(_blockchainActionId) == false && DataManager(_dataManager).getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0);
        require(amount > 0 && DataManager(_dataManager).getCurrency(currency) != 0x0);
        DepositContract o = DepositContract(DataManager(_dataManager).getDepositAddress(accountId));
        // check if pptbalance minus collateral held is more than pptFee then transfer pptFee from users ppt deposit to adminWallet
        require(SafeMath.safeSub(o.balanceOf(pptAddress), inCollateral) >= pptFee);
        require(o.transfer(pptAddress, adminExternalWallet, pptFee) == true);
        //stach deep with too many local variables, using cT directly
        //CurrencyToken cT = CurrencyToken(dm.getCurrency(currency));
       
        // WITHDRAW PART / DEBIT
        if(amount > CurrencyToken(DataManager(_dataManager).getCurrency(currency)).balanceOf(from)) {
                // destroying total balance
            require(CurrencyToken(DataManager(_dataManager).getCurrency(currency)).destroyTokensFrom(CurrencyToken(DataManager(_dataManager).getCurrency(currency)).balanceOf(from), from) == true);
            //remaining ledger balance. deposit address is 0
        } else {
                // destroy amount from balance
            require(CurrencyToken(DataManager(_dataManager).getCurrency(currency)).destroyTokensFrom(amount, from) == true);
            //left over deposit address balance.
        }

        // TRANSFER PART / CREDIT
        if(toBank == true) {
            require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, currency, amount, accountId, from, pptFee) == true); 
            //emit event: Imported currency to system
            EventWithdrawPoken(_blockchainActionId, accountId, currency, amount, toBank);
        } else {
            CurrencyToken(DataManager(_dataManager).getCurrency(currency)).mintTokens(amount);
            //credit account
            CurrencyToken(DataManager(_dataManager).getCurrency(currency)).transfer(to, amount);
            require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, currency, amount, accountId, to, pptFee) == true); 
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
        address _dataManager, bytes32 _blockchainActionId, 
        address pptAddress, bytes32 accountId, 
        address to, uint amount, uint inCollateral, uint pptFee, address adminExternalWallet) 
        public 
        onlyServer 
    {   
        require(_dataManager != 0x0);
        //DataManager dm = DataManager(_dataManager);
        require(DataManager(_dataManager).getActionStatus(_blockchainActionId) == false && DataManager(_dataManager).getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0);
        address depositContract = DataManager(_dataManager).getDepositAddress(accountId);
        //DepositContract dep = DepositContract(depositContract);
        uint pptBalance = SafeMath.safeSub(DepositContract(depositContract).balanceOf(pptAddress), inCollateral);
        require(pptBalance >= SafeMath.safeAdd(amount, pptFee));
        require(DepositContract(depositContract).transfer(pptAddress, to, amount) == true);
        require(DepositContract(depositContract).transfer(pptAddress, adminExternalWallet, pptFee) == true); 
        
        bytes32 tokenSymbol = iERC20Token(pptAddress).symbol();    
        
        
        // deposit address upgrade if version != 2
        if (getVersion(DepositContract(depositContract)) == 2) {
            // create new deposit contract
            // transfer pxt and ppt to new contract
            // store new contract in data manager
            require(DataManager(_dataManager).setDepositAddress(_blockchainActionId, new DepositContract(accountId, AM), accountId) == true);
            address newDepositAddress = DataManager(_dataManager).getDepositAddress(accountId);
            require(newDepositAddress != 0x0);
            if(DepositContract(depositContract).balanceOf(PXT) > 0){
                require(DepositContract(depositContract).transfer(PXT, newDepositAddress, DepositContract(depositContract).balanceOf(PXT)) == true);
            }
            if(DepositContract(depositContract).balanceOf(PPT) > 0) {
                require(DepositContract(depositContract).transfer(PPT, newDepositAddress, DepositContract(depositContract).balanceOf(PPT)) == true);
            }
            // event DepositAddressUpgrade with deposit address, user id, version number
            DepositAddressUpgrade(newDepositAddress, accountId, getVersion(newDepositAddress));
        }
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, tokenSymbol, amount, accountId, to, pptFee) == true);
        EventWithdrawPPT(_blockchainActionId, accountId, DataManager(_dataManager).getDepositAddress(accountId), to, amount);
    }

    // CONSTANT METHODS

    /** @dev Gets the version of this deposit contract
      * @param _depositContract The deposit contract address
      * @return uint256 version
      */
    function getVersion(address _depositContract) public view returns (uint256) {
        return DepositContract(_depositContract).getVersion();
    }
    
}