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
import "./withAccessManager.sol";

/// @title Populous contract
contract Populous is withAccessManager {
    // EVENTS
    // Bank events
    event EventUSDCToUSDp(bytes32 _blockchainActionId, bytes32 _clientId, uint amount);
    event EventUSDpToUSDC(bytes32 _blockchainActionId, bytes32 _clientId, uint amount);
    event EventDepositAddressUpgrade(bytes32 blockchainActionId, address oldDepositContract, address newDepositContract, bytes32 clientId, uint256 version);
    event EventWithdrawPPT(bytes32 blockchainActionId, bytes32 accountId, address depositContract, address to, uint amount);
    event EventWithdrawPoken(bytes32 _blockchainActionId, bytes32 accountId, bytes32 currency, uint amount);
    event EventNewDepositContract(bytes32 blockchainActionId, bytes32 clientId, address depositContractAddress, uint256 version);
    event EventWithdrawXAUp(bytes32 _blockchainActionId, address erc1155Token, uint amount, uint token_id, bytes32 accountId, uint pptFee);

    // FIELDS
    struct tokens {   
        address _token;
        uint256 _precision;
    }
    mapping(bytes8 => tokens) public tokenDetails;

    // NON-CONSTANT METHODS
    // Constructor method called when contract instance is 
    // deployed with 'withAccessManager' modifier.
    function Populous(address _accessManager) public withAccessManager(_accessManager) {
        /*ropsten*/
        
        //pxt
        tokenDetails[0x505854]._token = 0xD8A7C588f8DC19f49dAFd8ecf08eec58e64d4cC9;
        tokenDetails[0x505854]._precision = 8;
        //usdc
        tokenDetails[0x55534443]._token = 0xF930f2C7Bc02F89D05468112520553FFc6D24801;
        tokenDetails[0x55534443]._precision = 6;
        //tusd
        tokenDetails[0x54555344]._token = 0x78e7BEE398D66660bDF820DbDB415A33d011cD48;
        tokenDetails[0x54555344]._precision = 18;
        //ppt
        tokenDetails[0x505054]._token = 0x0ff72e24AF7c09A647865820D4477F98fcB72a2c;        
        tokenDetails[0x505054]._precision = 8;
        //xau
        tokenDetails[0x584155]._token = 0x9b935E3779098bC5E1ffc073CaF916F1E92A6145;
        tokenDetails[0x584155]._precision = 0;
        //usdp
        tokenDetails[0x55534470]._token = 0xf4b1533b6F45fAC936fA508F7e5db6d4BbC4c8bd;
        tokenDetails[0x55534470]._precision = 6;
        
        
        /*livenet

        //pxt
        tokenDetails[0x505854]._token = 0xc14830E53aA344E8c14603A91229A0b925b0B262;
        tokenDetails[0x505854]._precision = 8;
        //usdc
        tokenDetails[0x55534443]._token = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenDetails[0x55534443]._precision = 6;
        //tusd
        tokenDetails[0x54555344]._token = 0x8dd5fbCe2F6a956C3022bA3663759011Dd51e73E;
        tokenDetails[0x54555344]._precision = 18;
        //ppt
        tokenDetails[0x505054]._token = 0xd4fa1460F537bb9085d22C7bcCB5DD450Ef28e3a;        
        tokenDetails[0x505054]._precision = 8;
        //xau
        tokenDetails[0x584155]._token = 0x73a3b7DFFE9af119621f8467D8609771AB4BC33f;
        tokenDetails[0x584155]._precision = 0;
        //usdp
        tokenDetails[0x55534470]._token = 0xBaB5D0f110Be6f4a5b70a2FA22eD17324bFF6576;
        tokenDetails[0x55534470]._precision = 6;
        */
    }

    /**
    BANK MODULE
    */
    // NON-CONSTANT METHODS

    function usdcToUsdp(
        address _dataManager, bytes32 _blockchainActionId, 
        bytes32 _clientId, uint amount)
        public
        onlyServer
    {   
        // client deposit smart contract address
        address _depositAddress = DataManager(_dataManager).getDepositAddress(_clientId);
        require(_dataManager != 0x0 && _depositAddress != 0x0 && amount > 0);
        //transfer usdc from deposit contract to server/admin
        require(DepositContract(_depositAddress).transfer(tokenDetails[0x55534443]._token, msg.sender, amount) == true);
        // mint USDp into depositAddress with amount
        require(CurrencyToken(tokenDetails[0x55534470]._token).mint(amount, _depositAddress) == true);     
        //set action data
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, 0x55534470, amount, _clientId, _depositAddress, 0) == true); 
        //event
        emit EventUSDCToUSDp(_blockchainActionId, _clientId, amount);
    }

    function usdpToUsdc(
        address _dataManager, bytes32 _blockchainActionId, 
        bytes32 _clientId, uint amount) 
        public
        onlyServer
    {
        // client deposit smart contract address
        address _depositAddress = DataManager(_dataManager).getDepositAddress(_clientId);
        require(_dataManager != 0x0 && _depositAddress != 0x0 && amount > 0);
        //destroyFrom depositAddress USDp amount
        require(CurrencyToken(tokenDetails[0x55534470]._token).destroyTokensFrom(amount, _depositAddress) == true);
        //transferFrom USDC from server to depositAddress
        require(CurrencyToken(tokenDetails[0x55534443]._token).transferFrom(msg.sender, _depositAddress, amount) == true);
        //set action data
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, 0x55534470, amount, _clientId, _depositAddress, 0) == true); 
        //event
        emit EventUSDpToUSDC(_blockchainActionId, _clientId, amount);
    }

    // Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
    function createAddress(address _dataManager, bytes32 _blockchainActionId, bytes32 clientId) 
        public
        onlyServer
    {   
        require(_dataManager != 0x0);
        DepositContract newDepositContract;
        DepositContract dc;
        if (DataManager(_dataManager).getDepositAddress(clientId) != 0x0) {
            dc = DepositContract(DataManager(_dataManager).getDepositAddress(clientId));
            newDepositContract = new DepositContract(clientId, AM);
            require(!dc.call(bytes4(keccak256("getVersion()")))); 
            // only checking version 1 now to upgrade to version 2
            address PXT = tokenDetails[0x505854]._token;
            address PPT = tokenDetails[0x505054]._token;            
            if(dc.balanceOf(PXT) > 0){
                require(dc.transfer(PXT, newDepositContract, dc.balanceOf(PXT)) == true);
            }
            if(dc.balanceOf(PPT) > 0) {
                require(dc.transfer(PPT, newDepositContract, dc.balanceOf(PPT)) == true);
            }
            require(DataManager(_dataManager)._setDepositAddress(_blockchainActionId, clientId, newDepositContract) == true);
            EventDepositAddressUpgrade(_blockchainActionId, address(dc), DataManager(_dataManager).getDepositAddress(clientId), clientId, newDepositContract.getVersion());
        } else { 
            newDepositContract = new DepositContract(clientId, AM);
            require(DataManager(_dataManager).setDepositAddress(_blockchainActionId, newDepositContract, clientId) == true);
            require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, 0x0, 0, clientId, DataManager(_dataManager).getDepositAddress(clientId), 0) == true);
            EventNewDepositContract(_blockchainActionId, clientId, DataManager(_dataManager).getDepositAddress(clientId), newDepositContract.getVersion());
        }
    }

    /* /// Ether to XAUP exchange between deposit contract and Populous.sol
    function exchangeXAUP(
        address _dataManager, bytes32 _blockchainActionId, 
        address erc20_tokenAddress, uint erc20_amount, uint xaup_amount, 
        uint _tokenId, bytes32 _clientId, address adminExternalWallet) 
        public 
        onlyServer
    {    
        ERC1155 xa = ERC1155(tokenDetails[0x584155]._token);
        // client deposit smart contract address
        address _depositAddress = DataManager(_dataManager).getDepositAddress(_clientId);
        require(
            // check dataManager contract is valid
            _dataManager != 0x0 &&
            // check deposit address of client
            _depositAddress != 0x0 && 
            // check xaup token address
            // tokenDetails[0x584155]._token != 0x0 && 
            erc20_tokenAddress != 0x0 &&
            // check action id is unused
            DataManager(_dataManager).getActionStatus(_blockchainActionId) == false &&
            // deposit contract version >= 2
            DepositContract(_depositAddress).getVersion() >= 2 &&
            // populous server xaup balance
            xa.balanceOf(_tokenId, msg.sender) >= xaup_amount
        );
        // transfer erc20 token balance from clients deposit contract to server/admin
        require(DepositContract(_depositAddress).transfer(erc20_tokenAddress, adminExternalWallet, erc20_amount) == true);
        // transfer xaup tokens to clients deposit address from populous server allowance
        xa.safeTransferFrom(msg.sender, _depositAddress, _tokenId, xaup_amount, "");
        // set action status in dataManager
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, 0x0, erc20_amount, _clientId, _depositAddress, 0) == true);
        // emit event 
        EventExchangeXAUp(_blockchainActionId, erc20_tokenAddress, erc20_amount, xaup_amount, _tokenId, _clientId, _depositAddress);
    } */


    /** dev Import an amount of pokens of a particular currency from an ethereum wallet/address to bank
      * @param _blockchainActionId the blockchain action id
      * @param accountId the account id of the client
      * @param from the blockchain address to import pokens from
      * @param currency the poken currency
      */
    function withdrawPoken(
        address _dataManager, bytes32 _blockchainActionId, 
        bytes32 currency, uint256 amount, uint256 amountUSD,
        address from, address to, bytes32 accountId, 
        uint256 inCollateral,
        uint256 pptFee, address adminExternalWallet) 
        public 
        onlyServer 
    {
        require(_dataManager != 0x0);
        //DataManager dm = DataManager(_dataManager);
        require(DataManager(_dataManager).getActionStatus(_blockchainActionId) == false && DataManager(_dataManager).getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0);
        require(DataManager(_dataManager).getCurrency(currency) != 0x0);
        DepositContract o = DepositContract(DataManager(_dataManager).getDepositAddress(accountId));
        // check if pptbalance minus collateral held is more than pptFee then transfer pptFee from users ppt deposit to adminWallet
        require(SafeMath.safeSub(o.balanceOf(tokenDetails[0x505054]._token), inCollateral) >= pptFee);
        require(o.transfer(tokenDetails[0x505054]._token, adminExternalWallet, pptFee) == true);
        // WITHDRAW PART / DEBIT
        if(amount > CurrencyToken(DataManager(_dataManager).getCurrency(currency)).balanceOf(from)) {
            // destroying total balance as user has less than pokens they want to withdraw
            require(CurrencyToken(DataManager(_dataManager).getCurrency(currency)).destroyTokensFrom(CurrencyToken(DataManager(_dataManager).getCurrency(currency)).balanceOf(from), from) == true);
            //remaining ledger balance of deposit address is 0
        } else {
            // destroy amount from balance as user has more than pokens they want to withdraw
            require(CurrencyToken(DataManager(_dataManager).getCurrency(currency)).destroyTokensFrom(amount, from) == true);
            //left over balance is deposit address balance.
        }
        // TRANSFER PART / CREDIT
        // approve currency amount for populous for the next require to pass
        if(amountUSD > 0) //give the user USDC
        {
            CurrencyToken(tokenDetails[0x55534443]._token).transferFrom(msg.sender, to, amountUSD);
        }else { //give the user GBP / poken currency
            CurrencyToken(DataManager(_dataManager).getCurrency(currency)).transferFrom(msg.sender, to, amount);
        }
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, currency, amount, accountId, to, pptFee) == true); 
        EventWithdrawPoken(_blockchainActionId, accountId, currency, amount);
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
        address to, uint256 amount, uint256 inCollateral, 
        uint256 pptFee, address adminExternalWallet) 
        public 
        onlyServer 
    {   
        require(_dataManager != 0x0);
        require(DataManager(_dataManager).getActionStatus(_blockchainActionId) == false && DataManager(_dataManager).getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0 && amount > 0);
        address depositContract = DataManager(_dataManager).getDepositAddress(accountId);
        if(pptAddress == tokenDetails[0x505054]._token) {
            uint pptBalance = SafeMath.safeSub(DepositContract(depositContract).balanceOf(tokenDetails[0x505054]._token), inCollateral);
            require(pptBalance >= SafeMath.safeAdd(amount, pptFee));
        } else {
            uint erc20Balance = DepositContract(depositContract).balanceOf(pptAddress);
            require(erc20Balance >= amount);
        }
        require(DepositContract(depositContract).transfer(tokenDetails[0x505054]._token, adminExternalWallet, pptFee) == true);
        require(DepositContract(depositContract).transfer(pptAddress, to, amount) == true);
        bytes32 tokenSymbol = iERC20Token(pptAddress).symbol();    
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, tokenSymbol, amount, accountId, to, pptFee) == true);
        EventWithdrawPPT(_blockchainActionId, accountId, DataManager(_dataManager).getDepositAddress(accountId), to, amount);
    }

    // erc1155 withdraw function using transferFrom in erc1155 token contract
/*     function withdrawERC1155(
        address _dataManager, bytes32 _blockchainActionId,
        address _to, uint256 _id, uint256 _value,
        bytes32 accountId, uint256 pptFee, 
        address adminExternalWallet) 
        public
        onlyServer 
    {
        require(DataManager(_dataManager).getActionStatus(_blockchainActionId) == false && DataManager(_dataManager).getDepositAddress(accountId) != 0x0);
        require(adminExternalWallet != 0x0 && pptFee > 0 && _value > 0);
        DepositContract o = DepositContract(DataManager(_dataManager).getDepositAddress(accountId));
        require(o.transfer(tokenDetails[0x505054]._token, adminExternalWallet, pptFee) == true);
        // transfer xaup tokens to address from deposit contract
        require(o.transferERC1155(tokenDetails[0x584155]._token, _to, _id, _value) == true);
        // set action status in dataManager
        require(DataManager(_dataManager).setBlockchainActionData(_blockchainActionId, 0x584155, _value, accountId, _to, pptFee) == true);
        // emit event 
        EventWithdrawXAUp(_blockchainActionId, tokenDetails[0x584155]._token, _value, _id, accountId, pptFee);
    } */
}