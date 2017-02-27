var Populous = artifacts.require("Populous");

contract('Populous', function(accounts) {
    var LEDGER_SYSTEM_NAME = "Populous";
    var USD;
    var P;
    var crowdsale;

    it("should create currency token American Dollar", function(done) {
        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);

            return P.createCurrency("American Dollar", 3, "USD");
        }).then(function(result) {
            return P.getCurrency.call("USD");
        }).then(function(currencyAddress) {
            USD = currencyAddress;
            console.log('Currency', currencyAddress);
            assert.notEqual(currencyAddress, 0, "Failed creating currency token");
            done();
        });
    });

    it("should mint 1000 USD tokens", function(done) {
        var mintAmount = 1000;

        P.mintTokens('USD', mintAmount).then(function() {
            return P.getLedgerEntry.call("USD", LEDGER_SYSTEM_NAME);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
            done();
        });
    });

    it("should transfer 100 USD tokens to accounts A and B", function(done) {
        var mintAmount = 100;

        P.addTransaction("USD", LEDGER_SYSTEM_NAME, "A", mintAmount).then(function() {
            return P.addTransaction("USD", LEDGER_SYSTEM_NAME, "B", mintAmount);
        }).then(function() {
            return P.queueBackIndex.call();
        }).then(function(value) {
            assert.notEqual(value.toNumber(), 0, "Failed adding transactions");
            done();
        });
    });

    it("should execute transactions", function(done) {
        P.txExecuteLoop().then(function() {
            return P.queueBackIndex.call();
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed executing transactions");
            done();
        });
    });

    it("should create crowdsale", function(done) {
        assert(USD, "Currency required.");

        P.createCrowdsale(
            USD,
            "borrower001",
            "John Borrow",
            "Lisa Buyer",
            "invoice001",
            1000,
            900).then(function(result) {
            console.log(result);
            assert(result.logs.length, "Failed creating crowdsale");
            if (result.logs) {
                crowdsale = result.logs[0].args.crowdsale;
            }
            done();
        });
    });

    it("should create bidding group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var groupName = 'test group';
        var groupGoal = 909;

        P.createGroup(crowdsale, groupName, groupGoal).then(function(result) {
            console.log(result);
            assert(result.logs, "Failed creating crowdsale");
            if (result.logs) {
                crowdsale = result.logs[0].args.crowdsale;
            }
            done();
        });
    });
});