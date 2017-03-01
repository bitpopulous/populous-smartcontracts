var Populous = artifacts.require("Populous");
var Crowdsale = artifacts.require("Crowdsale");

contract('Populous', function(accounts) {
    var
        LEDGER_SYSTEM_NAME = "Populous",
        ACC_BORROW = 'borrower001',
        ACC1 = 'A',
        ACC2 = 'B',
        USD, P, crowdsale;

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

    it("should mint 10000 USD tokens", function(done) {
        var mintAmount = 10000;

        P.mintTokens('USD', mintAmount).then(function() {
            return P.getLedgerEntry.call("USD", LEDGER_SYSTEM_NAME);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
            done();
        });
    });

    it("should transfer 1000 USD tokens to accounts A and B", function(done) {
        var sendAmount = 1000;

        P.transfer("USD", LEDGER_SYSTEM_NAME, ACC1, sendAmount).then(function() {
            return P.transfer("USD", LEDGER_SYSTEM_NAME, ACC2, sendAmount);
        }).then(function() {
            return P.getLedgerEntry.call("USD", ACC1);
        }).then(function(value) {
            assert.equal(value.toNumber(), sendAmount, "Failed transfer 1");

            return P.getLedgerEntry.call("USD", ACC2);
        }).then(function(value) {
            assert.equal(value.toNumber(), sendAmount, "Failed transfer 2");
            done();
        });
    });

    it("should create crowdsale and start auction", function(done) {
        assert(USD, "Currency required.");

        P.createCrowdsale(
                USD,
                ACC_BORROW,
                "John Borrow",
                "Lisa Buyer",
                "invoice001",
                1000,
                900)
            .then(function(createCS) {
                assert(createCS.logs.length, "Failed creating crowdsale");

                crowdsale = createCS.logs[0].args.crowdsale;
                console.log('Crowdsale', crowdsale);

                return Crowdsale.at(crowdsale).openAuction();
            }).then(function(startAuction) {
                assert(startAuction.logs.length, "Failed starting auction");
                done();
            });
    });

    it("should create bidding group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var groupName = 'test group';
        var groupGoal = 909;

        Crowdsale.at(crowdsale).createGroup(groupName, groupGoal).then(function(result) {
            assert(result.logs.length, "Failed creating crowdsale");
            done();
        });
    });

    it("should bid", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 0, ACC1, "AA007", 910).then(function(result) {
            assert(result.receipt.logs.length, "Failed bidding");

            return P.getLedgerEntry.call("USD", ACC1);
        }).then(function(value) {
            assert.equal(value.toNumber(), 1000 - 909, "Failed bidding");
            done();
        });
    });

    it("should fund beneficiary", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.fundBeneficiary(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("USD", ACC_BORROW);
        }).then(function(value) {
            assert.equal(value.toNumber(), 909, "Failed funding beneficiary");
            done();
        });
    });
});