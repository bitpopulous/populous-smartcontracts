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
import "./ERC1155.sol";

/// @title Populous contract
contract Populous is withAccessManager {

    
    // EVENTS
    // Bank events
    event exchangeXAUpEvent (bytes32 _blockchainActionId, address _xaup, uint256 eth_amount, uint256 xaup_amount, uint256 _tokenId, bytes32 _clientId, address _from);
    event DepositAddressUpgrade(address oldDepositContract, address newDepositContract, bytes32 clientId, uint256 version);

    event EventWithdrawPPT(bytes32 blockchainActionId, bytes32 accountId, address depositContract, address to, uint amount);
    event EventWithdrawPoken(bytes32 _blockchainActionId, bytes32 accountId, bytes32 currency, uint amount, bool toBank);
    
    event EventNewCurrency(bytes32 blockchainActionId, bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr);
    event EventUpgradeCurrency(bytes32 blockchainActionId, bytes32 tokenName, uint8 decimalUnits, bytes32 tokenSymbol, address addr, uint256 version);
    
    event EventNewDepositContract(bytes32 blockchainActionId, bytes32 clientId, address depositContractAddress, uint256 version);
    event EventUpgradeDepositContract(bytes32 blockchainActionId, bytes32 clientId, address depositContractAddress, uint256 version);
    
    event EventNewProvider(bytes32 _blockchainActionId, bytes32 _userId, bytes32 _companyName, bytes32 _companyNumber, bytes2 countryCode);
    event EventNewInvoice(bytes32 _blockchainActionId, bytes32 _providerUserId, bytes2 invoiceCountryCode, bytes32 invoiceCompanyNumber, bytes32 invoiceCompanyName, bytes32 invoiceNumber);
    event EventProviderEnabled(bytes32 _blockchainActionId, bytes32 _userId, bytes2 _countryCode, bytes32 _companyNumber);
    event EventProviderDisabled(bytes32 _blockchainActionId, bytes32 _userId, bytes2 _countryCode, bytes32 _companyNumber);
    
    // FIELDS

    // livenet
    //address public PXT = 0xc14830E53aA344E8c14603A91229A0b925b0B262;
    //address public PPT = 0xd4fa1460F537bb9085d22C7bcCB5DD450Ef28e3a;
    // ropsten
    address public PXT = 0xD8A7C588f8DC19f49dAFd8ecf08eec58e64d4cC9;
    address public PPT = 0x0ff72e24AF7c09A647865820D4477F98fcB72a2c;

    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager) public withAccessManager(_accessManager) {}
    /**
    BANK MODULE
    */


    // NON-CONSTANT METHODS
     
    /// Ether to XAUP exchange between deposit contract and Populous.sol
    function exchangeXAUP(
        address _dataManager, bytes32 _blockchainActionId, 
        address _xaup, uint eth_amount, uint xaup_amount, 
        uint _tokenId, bytes32 _clientId, address adminExternalWallet) 
        public 
        onlyServer
    {    
        DataManager dm = DataManager(_dataManager);
        // client deposit smart contract address
        address _from = dm.getDepositAddress(_clientId);
        require(_dataManager != 0x0 && _from != 0x0 && _xaup != 0x0);
        // check action id, deposit address is valid and deposit contract address version is >= version 2
        require(dm.getActionStatus(_blockchainActionId) == false && dm.getDepositAddress(_clientId) != 0x0);
        require(DepositContract(dm.getDepositAddress(_clientId)).getVersion() >= 2);
        // check populous erc1155 balance
        ERC1155 xa = ERC1155(_xaup);
        require(xa.balanceOf(_tokenId, this) >= xaup_amount);
        // transfer ether balance from clients deposit contract to server
        require(DepositContract(_from).transferEther(adminExternalWallet, eth_amount) == true);
        // transfer xaup tokens to clients deposit address
        xa.safeTransferFrom(this, _from, _tokenId, xaup_amount, "");
        require(dm.setBlockchainActionData(_blockchainActionId, 0x0, eth_amount, _clientId, _from, 0) == true);
         // emit event 
        exchangeXAUpEvent (_blockchainActionId, _xaup, eth_amount, xaup_amount, _tokenId, _clientId, _from);
    }

    /// @notice Handle the receipt of an ERC1155 type
    /// @dev The smart contract calls this function on the recipient
    ///  after a `safeTransfer`. This function MAY throw to revert and reject the
    ///  transfer. Return of other than the magic value MUST result in the
    ///  transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _id The identifier of the item being transferred
    /// @param _value The amount of the item being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
    ///  unless throwing
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes _data) public returns(bytes4) {
        return 0xf23a6e61;
    }

    /**
    * @notice Handle the receipt of an NFT
    * @dev The ERC721 smart contract calls this function on the recipient
    * after a `safetransfer` if the recipient is a smart contract. This function MAY throw to revert and reject the
    * transfer. Return of other than the magic value (0x150b7a02) MUST result in the
    * transaction being reverted.
    * Note: the contract address is always the message sender.
    * @param _operator The address which called `safeTransferFrom` function
    * @param _from The address which previously owned the token
    * @param _tokenId The NFT identifier which is being transferred
    * @param _data Additional data with no specified format
    * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) public returns(bytes4) {
        return 0x150b7a02; 
    }

    /** @dev Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
      * @param clientId The bytes32 client ID
      * @return address The address of the deployed deposit contract instance.
      */
    function createAddress(address _dataManager, bytes32 _blockchainActionId, bytes32 clientId) public
        onlyServer
    {   
        require(_dataManager != 0x0);
        DataManager dm = DataManager(_dataManager);
        DepositContract dc = DepositContract(dm.getDepositAddress(clientId));
        DepositContract newDepositContract = new DepositContract(clientId, AM);

        if (dc.getVersion() != 2) {
            if(DepositContract(dc).balanceOf(PXT) > 0){
                require(DepositContract(dc).transfer(PXT, newDepositContract, DepositContract(dc).balanceOf(PXT)) == true);
            }
            if(DepositContract(newDepositContract).balanceOf(PPT) > 0) {
                require(DepositContract(dc).transfer(PPT, newDepositContract, DepositContract(dc).balanceOf(PPT)) == true);
            }
            require(dm.setDepositAddress(_blockchainActionId, newDepositContract, clientId) == true);
            assert(dm.getDepositAddress(clientId) != 0x0);
            require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, clientId, dm.getDepositAddress(clientId), 0) == true);
            // old deposit contract, new deposit contract, client id, deposit contract/wallet version
            DepositAddressUpgrade(dc, newDepositContract, clientId, dc.getVersion());
        } else {
            require(dm.setDepositAddress(_blockchainActionId, newDepositContract, clientId) == true);
            assert(dm.getDepositAddress(clientId) != 0x0);
            require(dm.setBlockchainActionData(_blockchainActionId, 0x0, 0, clientId, dm.getDepositAddress(clientId), 0) == true);
            EventNewDepositContract(_blockchainActionId, clientId, dm.getDepositAddress(clientId), dc.getVersion());
        }
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
        bytes32 currency, uint256 amount,
        address from, address to, bytes32 accountId, uint256 inCollateral,
        address pptAddress, uint256 pptFee, address adminExternalWallet, bool toBank) 
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
        address to, uint256 amount, uint256 inCollateral, uint256 pptFee, address adminExternalWallet) 
        public 
        onlyServer 
    {   
        require(_dataManager != 0x0);
        //DataManager dm = DataManager(_dataManager);
        require(DataManager(_dataManager).getActionStatus(_blockchainActionId) == false && DataManager(_dataManager).getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0);
        address depositContract = DataManager(_dataManager).getDepositAddress(accountId);
        uint pptBalance = SafeMath.safeSub(DepositContract(depositContract).balanceOf(pptAddress), inCollateral);
        require(pptBalance >= SafeMath.safeAdd(amount, pptFee));
        require(DepositContract(depositContract).transfer(pptAddress, to, amount) == true);
        require(DepositContract(depositContract).transfer(pptAddress, adminExternalWallet, pptFee) == true); 
        bytes32 tokenSymbol = iERC20Token(pptAddress).symbol();    
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, tokenSymbol, amount, accountId, to, pptFee) == true);
        EventWithdrawPPT(_blockchainActionId, accountId, DataManager(_dataManager).getDepositAddress(accountId), to, amount);
    }

    // CONSTANT METHODS

    
    
}