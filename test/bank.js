var
Populous = artifacts.require("Populous"),
CurrencyToken = artifacts.require("CurrencyToken"),
Crowdsale = artifacts.require("Crowdsale");

/**
* @TODO
* Write tests for the restrictions: deadline checks, status checks, sent tokens checks, balances checks
*/

contract('Populous / CurrencyToken > ', function(accounts) {
var
    config = require('../include/test/config.js'),
    commonTests = require('../include/test/common.js'),
    P, crowdsale;

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

describe("Bank", function() {
    it("should mint USD tokens: " + (config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE), function(done) {
        assert(global.currencies.USD, "Currency required.");
        // amount of USD tokens to mint = balance of accountIDs 'A' + 'B' + 'C'
        // amount of USD tokens to mint = 470 + 450 + 600 = 1,520
        var mintAmount = config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE;
        // mint mintAmount of USD tokens and allocate to LEDGER_ACC/"Populous"
        P.mintTokens('USD', mintAmount).then(function(result) {
            console.log('mint tokens gas cost', result.receipt.gasUsed);
            return P.getLedgerEntry.call("USD", config.LEDGER_ACC);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
            done();
        });
    });

    it("should transfer USD tokens to config.INVESTOR1_ACC, config.INVESTOR2_ACC, config.INVESTOR3_ACC_BALANCE", function(done) {
        assert(global.currencies.USD, "Currency required.");
        // transfer 470 USD tokens from 'Populous' to 'A'
        P.transfer("USD", config.LEDGER_ACC, config.INVESTOR1_ACC, config.INVESTOR1_ACC_BALANCE).then(function(result) {
            console.log('transfer pokens gas cost', result.receipt.gasUsed);
            // transfer 450 USD tokens from 'Populous' to 'B'
            return P.transfer("USD", config.LEDGER_ACC, config.INVESTOR2_ACC, config.INVESTOR2_ACC_BALANCE);
        }).then(function() {
            // transfer 600 USD tokens from 'Populous' to 'C'
            return P.transfer("USD", config.LEDGER_ACC, config.INVESTOR3_ACC, config.INVESTOR3_ACC_BALANCE);
        }).then(function() {
            // check USD token balance of 'A' is 470
            return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE, "Failed transfer 1");
            // check USD token balance of 'B' is 450
            return P.getLedgerEntry.call("USD", config.INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE, "Failed transfer 2");
            // check USD token balance of 'C' is 600
            return P.getLedgerEntry.call("USD", config.INVESTOR3_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR3_ACC_BALANCE, "Failed transfer 3");
            done();
        });
    });

    it("should withdraw USD tokens of config.INVESTOR1_ACC to an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.USD, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.USD);
        var externalAddress = accounts[0];
        var withdrawalAmount = 8;

        // withdraw withdrawal amount of USD tokens from 'A' and send to externalAddress
        P.withdraw(externalAddress, config.INVESTOR1_ACC, 'USD', withdrawalAmount, 1).then(function(result) {
            console.log('withdraw pokens gas cost', result.receipt.gasUsed);
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            // check withdrawal amount of USD tokens was allocated externalAddress
            assert.equal(value.toNumber(), withdrawalAmount - 1, "Failed withdrawal");
            // check withdrawal amount of USD tokens was withdrawn from 'A'
            return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - withdrawalAmount, "Failed withdrawal");
            done();
        });
    });

    it("should deposit USD tokens of config.INVESTOR1_ACC from an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.USD, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.USD);
        var externalAddress = accounts[0];
        //var depositAmount = 8;
        // deposit USD tokens from externalAddress to 'A'

        P.importExternalPokens("USD", externalAddress, config.INVESTOR1_ACC).then(function(result) {
            console.log('import external pokens to ledger gas cost', result.receipt.gasUsed);
            // check that depositAmount is deducted from externalAddress account
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed deposit");
            // check that the depositAmount has been added to 'A'
            return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 1, "Failed deposit");
            done();
        });
    });

});

});