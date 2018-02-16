var
Populous = artifacts.require("Populous"),
CurrencyToken = artifacts.require("CurrencyToken"),
PopulousToken = artifacts.require("PopulousToken")
DepositContract = artifacts.require("DepositContract");
/**
* @TODO
* Write tests for the restrictions: deadline checks, status checks, sent tokens checks, balances checks
*/

contract('Populous / CurrencyToken > ', function(accounts) {
var
    config = require('../include/test/config.js'),
    commonTests = require('../include/test/common.js'),
    P, CT, DC;

describe("Init currency token", function() {
    it("should init currency token American Dollar USD", function(done) {
        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);
            // creating a new currency USD for which to mint and use tokens
            if (!global.currencies || !global.currencies.USD) {
                return commonTests.createCurrency(P, "USD Pokens", 8, "USD");
            } else {
                return Promise.resolve();
            }
        }).then(function() {
            done();
        });
    });
});


describe("Init and transfer PPT", function() {

    it("should init PPT", function(done) {
        PopulousToken.new().then(function(instance) {
            assert(instance);
            // creating a new instance of the populous token contract
            // PPT which is linked to ERC23Token.sol
            global.PPT = instance;
            console.log('PPT', global.PPT.address);
            done();
        });
    });

    it("should get PPT from faucet", function(done) {
        assert(global.PPT, "PPT required.");

        var faucetAmount = 200;
        // getting PPT from faucet which increases the total amount in supply
        // and adds to the balance of the message sender accounts[0]
        global.PPT.faucet(faucetAmount).then(function() {
            return global.PPT.balanceOf(accounts[0]);
        }).then(function(amount) {
            // check that accounts[0] has the amount of PPT tokens -- 200
            // gotten from the faucet
            assert.equal(amount.toNumber(), faucetAmount, "Failed getting tokens from faucet");
            done();
        });
    });

    it("should transfer PPT to investors ethereum wallet", function(done) {
        assert(global.PPT, "PPT required.");

        var transferAmount = 100;
        // transferring 100 PPT tokens to accounts[1] from accounts[0]
        global.PPT.transfer(config.INVESTOR1_WALLET, transferAmount).catch(console.log).then(function(result) {
            console.log('transfer to address gas cost', result.receipt.gasUsed);
            // checking the balance of accounts[1] is 100
            return global.PPT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), transferAmount, "Failed getting tokens from faucet");
            done();
        });
    });


    it("should create deposit contract for client", function(done) {
        assert(global.PPT, "PPT required.");

        P.createAddress(config.INVESTOR1_ACC).then(function(instance) {
            assert(instance);
            return P.getDepositAddress(config.INVESTOR1_ACC);
        }).then(function(deposit_contract_address) {
            console.log('deposit contract address', deposit_contract_address);
            DC = DepositContract.at(deposit_contract_address);
            return DC.balanceOf(global.PPT.address);
        }).then(function(result) {
            assert.equal(result.toNumber(), 0, "failed creating deposit contract");
            done();
        });
    });


    it("should transfer PPT to deposit address", function(done) {
        assert(global.PPT, "PPT required.");

        var depositAmount = 100;
        var deposit_address;
        // transferring 100 PPT tokens to depositAddress for client from accounts[0]
        // depositAddress is the address of the deposit contract for accountID 'A'
        P.getDepositAddress(config.INVESTOR1_ACC).then(function(depositAddress){
            assert(depositAddress);
            deposit_address = depositAddress;
            return global.PPT.transfer(depositAddress, depositAmount, {from: config.INVESTOR1_WALLET});
        }).then(function(result) {
            console.log('transfer to address gas cost', result.receipt.gasUsed);
            // checking the balance of depositAddress is 100
            return global.PPT.balanceOf(deposit_address);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), depositAmount, "Failed getting tokens from faucet");
            done();
        });
    });

});


describe("Bank", function() {

    it("should withdraw USD tokens of config.INVESTOR1_ACC to an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.USD, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.USD);
        var externalAddress = config.INVESTOR1_WALLET;
        var withdrawalAmount = 370;

        // withdraw withdrawal amount of USD tokens from 'A' and send to externalAddress
        P.withdrawPoken(config.INVESTOR1_ACC, externalAddress, withdrawalAmount, 'USD').then(function(result) {
            //console.log('withdraw pokens gas cost', result.receipt.gasUsed);
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            // check withdrawal amount of USD tokens was allocated externalAddress
            assert.equal(value.toNumber(), withdrawalAmount, "Failed withdrawal");
            done();
        });
    });


    it("should import USD tokens of config.INVESTOR1_WALLET to an internal account Id, e.g., A", function(done) {
        assert(global.currencies.USD, "Currency required.");
        var CT = CurrencyToken.at(global.currencies.USD);

        CT.balanceOf(config.INVESTOR1_WALLET).then(function(balance){
            assert.equal(balance.toNumber(), 370, "failed earlier withdrawal of tokens");
        
            return P.importPokens('USD', config.INVESTOR1_WALLET, config.INVESTOR1_ACC);
        }).then(function(result) {
            return CT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed importing tokens");
            done();
        });
    });


    it("should withdraw PPT to investor wallet", function(done) {
        assert(global.PPT, "PPT required.");

        var depositAmount = 100;
        var balances = 50;
        var deposit_address;
        var depositContractPPTBalance, investorPPTBalance;

        P.getDepositAddress(config.INVESTOR1_ACC).then(function(depositAddress){
            assert(depositAddress);
            deposit_address = depositAddress;
            return global.PPT.balanceOf(depositAddress);
        }).then(function(result) {
            assert.equal(result.toNumber(), 100, "failed depositing PPT");
            // checking the balance of depositAddress is 100
            return P.withdrawPPT(global.PPT.address, config.INVESTOR1_ACC, deposit_address, config.INVESTOR1_WALLET, 50);
        }).then(function(withdrawPPT) {
            assert(withdrawPPT.logs.length, "Failed withdrawing PPT");
            return global.PPT.balanceOf(deposit_address); 
        }).then(function(balanceOfDepositContract){
            assert.equal(balanceOfDepositContract.toNumber(), balances, "failed withdrawing PPT");
            depositContractPPTBalance = balanceOfDepositContract.toNumber();
            return global.PPT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(balanceOfInvestor){
            investorPPTBalance = balanceOfInvestor.toNumber();
            assert.equal(balanceOfInvestor.toNumber(), balances, "failed withdrawing PPT");
            assert.equal(investorPPTBalance, depositContractPPTBalance, "failed withdrawing PPT");
            done();
        });
    });


});


describe("Crowdsale data", function() {

    var crowdsaleId = "#AA001";
    it("should get number of crowdsale document blocks", function(done) {
        P.getRecordDocumentIndexes(crowdsaleId).then(function(numberofBlocks) {
            assert.equal(numberofBlocks.toNumber(), 0, "failed getting correct number of crowdsale blocks");
            done();
        });
    });

    it("should insert crowdsale block", function(done) {
        done();
    });

    it("should insert crowdsale source", function(done) {
        done();
    });
});



/* describe("Bank", function() {

    it("should mint USD tokens: " + (config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE), function(done) {
        assert(global.currencies.USD, "Currency required.");
        // amount of USD tokens to mint = balance of accountIDs 'A' + 'B' + 'C'
        // amount of USD tokens to mint = 470 + 450 + 600 = 1,520
        var mintAmount = config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE;
        // mint mintAmount of USD tokens and allocate to LEDGER_ACC/"Populous"
        P.getCurrency("USD").then(function(tokenAddress){
            CT = CurrencyToken.at(tokenAddress);
            console.log('Currency token address: ', tokenAddress);
            return CT.mintTokens(mintAmount);
        }).then(function(result) {
            //console.log('mint tokens gas cost', result.receipt.gasUsed);
            return CT.balanceOf(web3.eth.accounts[0]);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
            done();
        });
    });

    it("should transfer USD tokens to config.INVESTOR1_ACC, config.INVESTOR2_ACC, config.INVESTOR3_ACC_BALANCE", function(done) {
        assert(global.currencies.USD, "Currency required.");
        var CT = CurrencyToken.at(global.currencies.USD);
        // transfer 470 USD tokens from 'Populous' to 'A'
        CT.transfer(config.INVESTOR1_WALLET, config.INVESTOR1_ACC_BALANCE).then(function(result) {
            //console.log('transfer pokens gas cost', result.receipt.gasUsed);
            // transfer 450 USD tokens from 'Populous' to 'B'
            return CT.transfer(config.INVESTOR2_WALLET, config.INVESTOR2_ACC_BALANCE);
        }).then(function() {
            // transfer 600 USD tokens from 'Populous' to 'C'
            return CT.transfer(config.INVESTOR3_WALLET, config.INVESTOR3_ACC_BALANCE);
        }).then(function() {
            // check USD token balance of 'A' is 470
            return CT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE, "Failed transfer 1");
            // check USD token balance of 'B' is 450
            return CT.balanceOf(config.INVESTOR2_WALLET);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE, "Failed transfer 2");
            // check USD token balance of 'C' is 600
            return CT.balanceOf(config.INVESTOR3_WALLET);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR3_ACC_BALANCE, "Failed transfer 3");
            done();
        });
    });


    it("should import USD tokens of config.INVESTOR1_WALLET to an internal account Id, e.g., A", function(done) {
        assert(global.currencies.USD, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.USD);

        P.importExternalPokens('USD', config.INVESTOR1_WALLET, config.INVESTOR1_ACC).then(function(result) {
            return CT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed importing tokens");
            return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE, "Failed importing tokens");
            done();
        });
    });


    it("should withdraw USD tokens of config.INVESTOR1_ACC to an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.USD, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.USD);
        var externalAddress = config.INVESTOR1_WALLET;
        var withdrawalAmount = 370;

        // withdraw withdrawal amount of USD tokens from 'A' and send to externalAddress
        P.withdrawPoken(config.INVESTOR1_ACC, externalAddress, withdrawalAmount, 'USD').then(function(result) {
            //console.log('withdraw pokens gas cost', result.receipt.gasUsed);
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            // check withdrawal amount of USD tokens was allocated externalAddress
            assert.equal(value.toNumber(), withdrawalAmount, "Failed withdrawal");
            // check withdrawal amount of USD tokens was withdrawn from 'A'
            return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - withdrawalAmount, "Failed withdrawal");
            done();
        });
    });
}); */

});