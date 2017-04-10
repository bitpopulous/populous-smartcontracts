var
    Populous = artifacts.require("Populous"),
    CurrencyToken = artifacts.require("CurrencyToken"),
    Crowdsale = artifacts.require("Crowdsale");

/**
 * @TODO
 * Split into separete tests.
 * Extract the bank functionality in external file and include it in tests.
 * Make a lib with util functions.
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

                if (!global.currencies || !global.currencies.USD) {
                    return commonTests.createCurrency(P, "American Dollar", 3, "USD");
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

            var mintAmount = config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE;

            P.mintTokens('USD', mintAmount).then(function() {
                return P.getLedgerEntry.call("USD", config.LEDGER_ACC);
            }).then(function(amount) {
                assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
                done();
            });
        });

        it("should transfer USD tokens to config.INVESTOR1_ACC, config.INVESTOR2_ACC, config.INVESTOR3_ACC_BALANCE", function(done) {
            assert(global.currencies.USD, "Currency required.");

            P.transfer("USD", config.LEDGER_ACC, config.INVESTOR1_ACC, config.INVESTOR1_ACC_BALANCE).then(function() {
                return P.transfer("USD", config.LEDGER_ACC, config.INVESTOR2_ACC, config.INVESTOR2_ACC_BALANCE);
            }).then(function() {
                return P.transfer("USD", config.LEDGER_ACC, config.INVESTOR3_ACC, config.INVESTOR3_ACC_BALANCE);
            }).then(function() {
                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE, "Failed transfer 1");

                return P.getLedgerEntry.call("USD", config.INVESTOR2_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE, "Failed transfer 2");

                return P.getLedgerEntry.call("USD", config.INVESTOR3_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR3_ACC_BALANCE, "Failed transfer 3");
                done();
            });
        });

        it("should withdraw USD tokens of config.INVESTOR1_ACC to 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
            assert(global.currencies.USD, "Currency required.");

            var CT = CurrencyToken.at(global.currencies.USD);
            var externalAddress = accounts[0];
            var withdrawalAmount = 8;

            P.withdraw(externalAddress, config.INVESTOR1_ACC, 'USD', withdrawalAmount).then(function() {
                return CT.balanceOf(externalAddress);
            }).then(function(value) {
                assert.equal(value.toNumber(), withdrawalAmount, "Failed withdrawal");

                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - withdrawalAmount, "Failed withdrawal");
                done();
            });
        });

        it("should deposit USD tokens of config.INVESTOR1_ACC from 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
            assert(global.currencies.USD, "Currency required.");

            var CT = CurrencyToken.at(global.currencies.USD);
            var externalAddress = accounts[0];
            var depositAmount = 8;

            CT.transferToContract(P.address, depositAmount, config.INVESTOR1_ACC, { from: externalAddress }).then(function(result) {
                return CT.balanceOf(externalAddress);
            }).then(function(value) {
                assert.equal(value.toNumber(), 0, "Failed deposit");

                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE, "Failed deposit");
                done();
            });
        });

    });

});