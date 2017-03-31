var Populous = artifacts.require("Populous");
var CurrencyToken = artifacts.require("CurrencyToken");
var Crowdsale = artifacts.require("Crowdsale");

contract('Bank', function(accounts) {
    var
        LEDGER_ACC = "Populous",
        BORROWER_ACC = 'borrower001',
        INVESTOR1_ACC = 'A',
        INVESTOR2_ACC = 'B',
        INVESTOR1_ACC_BALANCE = 470,
        INVESTOR2_ACC_BALANCE = 450,
        USD, P, crowdsale;

    it("should get Populous and USD currency token addresses", function(done) {
        assert(USD, "Currency required.");

        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);

            return P.getCurrency.call("USD");
        }).then(function(currencyAddress) {
            assert.notEqual(currencyAddress, 0, "Failed getting currency token");

            USD = currencyAddress;
            console.log('Currency', currencyAddress);

            done();
        });
    });

    it("should mint USD tokens: " + (INVESTOR1_ACC_BALANCE + INVESTOR2_ACC_BALANCE), function(done) {
        assert(USD, "Currency required.");

        var mintAmount = INVESTOR1_ACC_BALANCE + INVESTOR2_ACC_BALANCE;

        P.mintTokens('USD', mintAmount).then(function() {
            return P.getLedgerEntry.call("USD", LEDGER_ACC);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
            done();
        });
    });

    it("should transfer USD tokens to INVESTOR1_ACC and INVESTOR2_ACC", function(done) {
        assert(USD, "Currency required.");

        P.transfer("USD", LEDGER_ACC, INVESTOR1_ACC, INVESTOR1_ACC_BALANCE).then(function() {
            return P.transfer("USD", LEDGER_ACC, INVESTOR2_ACC, INVESTOR2_ACC_BALANCE);
        }).then(function() {
            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE, "Failed transfer 1");

            return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), INVESTOR2_ACC_BALANCE, "Failed transfer 2");
            done();
        });
    });

    it("should withdraw USD tokens of INVESTOR1_ACC to 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(USD, "Currency required.");

        var CT = CurrencyToken.at(USD);
        var externalAddress = '0x93123461712617b2f828494dbf5355b8a76d6051';
        var withdrawalAmount = 8;

        P.withdraw(externalAddress, INVESTOR1_ACC, 'USD', withdrawalAmount).then(function() {
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            assert.equal(value.toNumber(), withdrawalAmount, "Failed withdrawal");

            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE - withdrawalAmount, "Failed withdrawal");
            done();
        });
    });

    it("should deposit USD tokens of INVESTOR1_ACC from 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(USD, "Currency required.");

        var CT = CurrencyToken.at(USD);
        var externalAddress = '0x93123461712617b2f828494dbf5355b8a76d6051';
        var depositAmount = 8;

        CT.transferToContract(P.address, depositAmount, INVESTOR1_ACC, { from: externalAddress }).then(function(result) {
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed deposit");

            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE, "Failed deposit");
            done();
        });
    });

});