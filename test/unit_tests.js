var
    Populous = artifacts.require("Populous"),
    CurrencyToken = artifacts.require("CurrencyToken"),
    PopulousToken = artifacts.require("PopulousToken"),
    DepositContract = artifacts.require("DepositContract");

contract('Populous/Currency Token/ Deposit > ', function (accounts) {
    var
        config = require('../include/test/config.js'),
        commonTests = require('../include/test/common.js'),
        P, CT, DC;

    var pptFee = 1;

    describe("Init currency token", function () {
        it("should init currency token American Dollar USD", function (done) {

            Populous.deployed().then(function (instance) {
                P = instance;
                console.log('Populous', P.address);
                // creating a new currency USD for which to mint and use tokens
                if (!global.currencies || !global.currencies.USD) {
                    //create new currency/token
                    return commonTests.createCurrency(P, "USD Pokens", 8, "USD");
                } else {
                    return Promise.resolve();
                }
            }).then(function () {
                done();
            });
        });

        it("should get blockchain action id information", function (done){
            var _blockchainActionId = "createCurrency1";
            P.getBlockchainActionIdData(_blockchainActionId).then(function (actionData) {
                assert.equal(web3.toUtf8(actionData[0]), 'USD', "Failed getting correct currency");
                assert.equal(actionData[1], 0, "Failed getting correct amount");
                assert.equal(web3.toUtf8(actionData[2]), '', "Failed getting correct action id");
                assert.equal(web3.toUtf8(actionData[2]).length, 0, "Failed getting correct action id length");
                console.log(actionData[3]);
                assert.equal(actionData[3], global.currencies.USD, "Failed getting correct address to/from");
                done();
            });
        }); 
    });


    describe("Init and transfer PPT", function () {

        it("should init PPT", function (done) {
            //create new populous PPT token
            PopulousToken.new().then(function (instance) {
                assert(instance);
                // creating a new instance of the populous token contract
                // PPT which is linked to ERC23Token.sol
                global.PPT = instance;
                console.log('PPT', global.PPT.address);
                done();
            });
        });

        it("should get PPT from faucet", function (done) {
            assert(global.PPT, "PPT required.");

            var faucetAmount = 200;
            // getting PPT from faucet which increases the total amount in supply
            // and adds to the balance of the message sender accounts[0]
            global.PPT.faucet(faucetAmount).then(function () {
                return global.PPT.balanceOf(accounts[0]);
            }).then(function (amount) {
                // check that accounts[0] has the amount of PPT tokens -- 200
                // gotten from the faucet
                assert.equal(amount.toNumber(), faucetAmount, "Failed getting tokens from faucet");
                done();
            });
        });

        it("should transfer PPT to investors ethereum wallet", function (done) {
            assert(global.PPT, "PPT required.");

            var transferAmount = 102;
            // transferring transferAmount of PPT tokens to accounts[1] from accounts[0]
            global.PPT.transfer(config.INVESTOR1_WALLET, transferAmount).catch(console.log).then(function (result) {
                console.log('transfer to address gas cost', result.receipt.gasUsed);
                // checking the balance of accounts[1] is 100
                return global.PPT.balanceOf(config.INVESTOR1_WALLET);
            }).then(function (amount) {
                // check that balance is = amount transferred
                assert.equal(amount.toNumber(), transferAmount, "Failed getting tokens from faucet");
                done();
            });
        });


        it("should create deposit contract for client", function (done) {
            assert(global.PPT, "PPT required.");

            var _blockchainActionId = "createAddress1";
            // create new deposit smart contract for client Id 'A'
            P.createAddress(_blockchainActionId, config.INVESTOR1_ACC).then(function (instance) {
                assert(instance);
                // get deposit address with client Id 'A'
                return P.getDepositAddress(config.INVESTOR1_ACC);
            }).then(function (deposit_contract_address) {
                // display deposit smart contract address
                console.log('deposit contract address', deposit_contract_address);
                DC = DepositContract.at(deposit_contract_address);
                // call balanceOf function of deposit smart contract to check its PPT balance
                return DC.balanceOf(global.PPT.address);
            }).then(function (result) {
                // PPT balance of newly created deposit contract address should be 0
                assert.equal(result.toNumber(), 0, "failed creating deposit contract");
                done();
            });
        });

        it("should fail create deposit contract for client config.INVESTOR2_ACC with config.INVESTOR1_ACC blockchainActionId", function (done) {
            assert(global.PPT, "PPT required.");

            var _blockchainActionId = "createAddress1";
            var isCaught = false;

            P.createAddress(_blockchainActionId, config.INVESTOR2_ACC)
                .catch(function () { isCaught = true; }
                ).then(function () {
                    if (isCaught === false) {
                        throw new Error('Not allowed deposit address creation passed !!!');
                    }
                    done();
                });
        });

        it("should transfer PPT to deposit address", function (done) {
            assert(global.PPT, "PPT required.");

            var depositAmount = 102;
            var deposit_address;
            // transferring 100 PPT tokens to depositAddress for client from accounts[0]
            // depositAddress is the address of the deposit contract for client Id 'A'
            P.getDepositAddress(config.INVESTOR1_ACC).then(function (depositAddress) {
                assert(depositAddress);
                deposit_address = depositAddress;
                // transfer PPT from accounts[1] to deposit contract address as PPT crowdsale deposit
                return global.PPT.transfer(depositAddress, depositAmount, { from: config.INVESTOR1_WALLET });
            }).then(function (result) {
                console.log('transfer to address gas cost', result.receipt.gasUsed);
                // checking the balance of depositAddress is 100
                return global.PPT.balanceOf(deposit_address);
            }).then(function (amount) {
                assert.equal(amount.toNumber(), depositAmount, "Failed getting tokens from faucet");
                done();
            });
        });

    });


    describe("Bank", function () {

        it("should withdraw USD tokens of config.INVESTOR1_ACC to an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function (done) {
            assert(global.currencies.USD, "Currency required.");

            var CT = CurrencyToken.at(global.currencies.USD);
            var externalAddress = config.INVESTOR1_WALLET;
            var withdrawalAmount = 370;
            var _blockchainActionId = "actionId1";
            var toBank = false;
            var inCollateral = 49;

            // withdraw withdrawal amount of USD tokens for client Id 'A' from platform and send to clients externalAddress
            P.withdrawPoken(_blockchainActionId, 'USD', withdrawalAmount, externalAddress, 
                externalAddress, config.INVESTOR1_ACC, inCollateral, global.PPT.address, pptFee, 
                config.ADMIN_WALLET, toBank)
            .then(function (result) {
                //console.log('withdraw pokens gas cost', result.receipt.gasUsed);
                // check balance of clients external address
                return CT.balanceOf(externalAddress);
            }).then(function (value) {
                // check withdrawal amount of USD tokens was correctly allocated externalAddress
                assert.equal(value.toNumber(), withdrawalAmount, "Failed withdrawal");
                return P.getActionStatus(_blockchainActionId);
            }).then(function (actionStatus) {
                assert.equal(true, actionStatus, "Failed withdrawal of Pokens");
                console.log("blockchain action status for " + _blockchainActionId + " is ", actionStatus);
                return P.getBlockchainActionIdData(_blockchainActionId);
            }).then(function (actionData) {
                assert.equal(web3.toUtf8(actionData[0]), 'USD', "Failed getting correct currency");
                assert.equal(actionData[1], withdrawalAmount, "Failed getting correct amount");
                assert.equal(web3.toUtf8(actionData[2]), config.INVESTOR1_ACC, "Failed getting correct action id");
                assert.equal(actionData[3], externalAddress, "Failed getting correct address to/from");
                // ppt balance of deposit contract = deposit amount - pptfee
                done();
            });
        });

        it("should withdraw USD tokens of config.INVESTOR1_WALLET to internal platform/bank and destroy", function (done) {
            assert(global.currencies.USD, "Currency required.");
            var CT = CurrencyToken.at(global.currencies.USD);
            var _blockchainActionId = "import1"
            var toBank = true;
            var inCollateral = 49;
            var withdrawalAmount = 370;
            var externalAddress = config.INVESTOR1_WALLET;

            //check balance of clients external address is 370 sent to it earlier using withdraw function
            CT.balanceOf(config.INVESTOR1_WALLET).then(function (balance) {
                assert.equal(balance.toNumber(), 370, "failed earlier withdrawal of newly minted tokens to investors wallet");
                // import and destroy withdrawal amount of USD tokens from client Id 'A' external wallet to platform
                return P.withdrawPoken(_blockchainActionId, 'USD', withdrawalAmount, externalAddress, 
                externalAddress, config.INVESTOR1_ACC, inCollateral, global.PPT.address, pptFee, 
                config.ADMIN_WALLET, toBank);
            }).then(function (result) {
                // check token balance of wallet is original balance minus withdrawn amount
                return CT.balanceOf(config.INVESTOR1_WALLET);
            }).then(function (value) {
                assert.equal(value.toNumber(), 0, "Failed importing tokens");
                done();
                // ppt balance of deposit contract = deposit amount - (pptfee * 2)

            });
        });

        it("should fail create withdraw PPT when balance minus collateral is less than amount + fee", function (done) {
            var isCaught = false;
            var depositAmount = 102;
            var balances = 50;
            var inCollateral = 49;
            var deposit_address;
            var _blockchainActionId = "withdrawppt2";            
            var toWithdraw = 50;
            var highPPTFee = 20;
            
            //withdraw 50 PPT from deposit contract to wallet
            P.withdrawERC20(_blockchainActionId, global.PPT.address, config.INVESTOR1_ACC, config.INVESTOR1_WALLET, toWithdraw, inCollateral, highPPTFee, config.ADMIN_WALLET)
            .catch(function () { isCaught = true; }
                ).then(function () {
                    if (isCaught === false) {
                        throw new Error('Not allowed invoice creation passed !!!');
                    }
                    done();
                });
        });


        it("should withdraw PPT to investor wallet", function (done) {
            assert(global.PPT, "PPT required.");

            var depositAmount = 102;
            var balances = 50;
            var inCollateral = 49;
            var deposit_address;
            var depositContractPPTBalance, investorPPTBalance;
            var _blockchainActionId = "withdrawppt1";            
            var toWithdraw = 50;

            // get address of deposit address for client Id 'A'
            P.getDepositAddress(config.INVESTOR1_ACC).then(function (depositAddress) {
                assert(depositAddress);
                deposit_address = depositAddress;
                // get PPT balance of the address is 100 PPT sent to it as deposit amount
                return global.PPT.balanceOf(depositAddress);
            }).then(function (result) {
                // checking the balance of depositAddress is amount deposited minue earlier collected pptFee for withdrawing pokens
                assert.equal(result.toNumber(), depositAmount - (pptFee * 2), "failed depositing PPT");
                //withdraw 50 PPT from deposit contract to wallet
                return P.withdrawERC20(_blockchainActionId, global.PPT.address, config.INVESTOR1_ACC, config.INVESTOR1_WALLET, toWithdraw, inCollateral, pptFee, config.ADMIN_WALLET);
            }).then(function (withdrawPPT) {
                // to do - update solidity compiler to see events
                //assert(withdrawPPT.logs.length, "Failed withdrawing PPT");
                // get PPT token balance of deposit contract address
                return global.PPT.balanceOf(deposit_address);
            }).then(function (balanceOfDepositContract) {
                // check that balance of deposit address is now amount deposited minus amount withdrawn + pptFee
                assert.equal(balanceOfDepositContract.toNumber(), 49, "failed withdrawing PPT");
                depositContractPPTBalance = balanceOfDepositContract.toNumber();
                // check balance of external address is deposit contract balance - amount withdrawn
                return global.PPT.balanceOf(config.INVESTOR1_WALLET);
            }).then(function (balanceOfInvestor) {
                investorPPTBalance = balanceOfInvestor.toNumber();
                // check balance of external wallet and deposit contract address
                assert.equal(balanceOfInvestor.toNumber(), balances, "failed withdrawing PPT");
                // check balance of external address is deposit contract balance - amount withdrawn
                return global.PPT.balanceOf(config.ADMIN_WALLET);
            }).then(function(admin_ppt_balance){
                // check balance of admin wallet to see if pptFee has been transferred
                assert.equal(admin_ppt_balance.toNumber(), pptFee * 3, "failed withdrawing PPT");
                done();
                // ppt balance of deposit contract = deposit amount - (pptfee * 3) - toWithdraw
            });
        });

    });


    describe("Invoice and Provider", function () { 

        it("should add an invoice provider", function (done) {
            // PROVIDER
            var _providerBlockchainActionId = "provider1";
            var _providerUserId = "providerA";
            var _companyNumber = "112233445";
            var _companyName = "populous test provider";
            var _countryCode = "44";
    
            P.addProvider(_providerBlockchainActionId, _providerUserId, web3.fromAscii(_companyNumber), _companyName, web3.fromAscii(_countryCode)).then(function(){
                return P.getProviderByUserId(_providerUserId);
            }).then(function(providerInfo){
                assert.equal(web3.toAscii(providerInfo[0]), _countryCode, "failed getting provider country code");
                assert.equal(web3.toUtf8(providerInfo[1]), _companyName, "failed getting provider country code");
                // ascii failing, utf8 passing
                // console.log("comp utf", web3.toUtf8(providerInfo[2]));
                assert.equal(web3.toUtf8(providerInfo[2]), _companyNumber, "failed getting provider country code");
                assert.equal(providerInfo[3], true, "failed getting provider enabled status");

                return P.getProviderByCountryCodeCompanyNumber(web3.fromAscii(_countryCode), web3.fromAscii(_companyNumber));
            }).then(function(providerInfowithCode){
                assert.equal(web3.toUtf8(providerInfowithCode[0]), _providerUserId, "failed getting provider user Id");
                assert.equal(web3.toUtf8(providerInfowithCode[1]), _companyName, "failed getting provider company name");
                assert.equal(providerInfowithCode[2], true, "failed getting provider enabled status");
                return P.getProviderStatus(_providerUserId);
            }).then(function(providerStatus){
                assert.equal(true, providerStatus, "failed disabling provider");
                done();
            });
        });

        it("should disable provider and get the enabled status of an invoice provider", function (done) {

            var _blockchainActionId = "disableProvider1";
            var _providerUserId = "providerA";
            P.disableProvider(_blockchainActionId, _providerUserId).then(function(_providerStatu){
                // disable provider event log
                //console.log("disable log", _providerStatu.logs[0]);
                return P.getProviderStatus(_providerUserId);
            }).then(function(_providerStatus){
                assert.equal(_providerStatus, false, "failed disabling provider");
                done();
            });
        });
        
        it("should fail create invoice for disabled invoice provider user Id", function (done) {
            var isCaught = false;

            // INVOICE
            var _providerUserId = "providerA";
            var _invoiceBlockchainActionId = "createInvoice1";
            var _invoiceCountryCode = "44";
            var _invoiceCompanyNumber = "112233445";
            var _invoiceCompanyName = "populous test provider";
            var _invoiceNumber = "#223";

            P.addInvoice(_invoiceBlockchainActionId, _providerUserId, web3.fromAscii(_invoiceCountryCode), web3.fromAscii(_invoiceCompanyNumber), _invoiceCompanyName, _invoiceNumber)
                .catch(function () { isCaught = true; }
                ).then(function () {
                    if (isCaught === false) {
                        throw new Error('Not allowed invoice creation passed !!!');
                    }
                    done();
                });
        });


        it("should fail create invoice with non-existing invoice provider user Id", function (done) {
            var isCaught = false;

            // INVOICE
            var _providerUserId = "xxxxA";
            var _invoiceBlockchainActionId = "createInvoice1";
            var _invoiceCountryCode = "44";
            var _invoiceCompanyNumber = "112233445";
            var _invoiceCompanyName = "populous test provider";
            var _invoiceNumber = "#223";

            P.addInvoice(_invoiceBlockchainActionId, _providerUserId, web3.fromAscii(_invoiceCountryCode), web3.fromAscii(_invoiceCompanyNumber), _invoiceCompanyName, _invoiceNumber)
                .catch(function () { isCaught = true; }
                ).then(function () {
                    if (isCaught === false) {
                        throw new Error('Not allowed invoice creation passed !!!');
                    }
                    done();
                });
        });

    
        it("should enable provider and get the enabled status of an invoice provider", function (done) {

            var _blockchainActionId = "enableProvider1";
            var _providerUserId = "providerA";

            P.enableProvider(_blockchainActionId, _providerUserId).then(function(){
                return P.getProviderStatus(_providerUserId);
            }).then(function(providerStatus){
                assert.equal(true, providerStatus, "failed enabling provider");
                done();
            });

        });            
            
        it("should add invoice for enabled provider", function (done){

            var _providerUserId = "providerA";
            var _invoiceBlockchainActionId = "createInvoice2";
            var _invoiceCountryCode = "44";
            var _invoiceCompanyNumber = "112233445";
            var _invoiceCompanyName = "populous test provider";
            var _invoiceNumber = "#223";
            //pass
            P.addInvoice(_invoiceBlockchainActionId, _providerUserId, web3.toAscii(_invoiceCountryCode), web3.toAscii(_invoiceCompanyNumber), 
                _invoiceCompanyName, _invoiceNumber).then(function(){
                return P.getInvoice(web3.toAscii(_invoiceCountryCode), web3.toAscii(_invoiceCompanyNumber), _invoiceNumber);
            }).then(function(invoiceDetails){
                assert.equal(web3.toUtf8(invoiceDetails[0]), _providerUserId, "failed getting invoice provider user id");
                assert.equal(web3.toUtf8(invoiceDetails[1]), _invoiceCompanyName, "failed getting invoice company name");
                done();
            })
        });

    });

});