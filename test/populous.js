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
            assert.notEqual(currencyAddress, 0, "Failed creating currency token");

            USD = currencyAddress;
            console.log('Currency', currencyAddress);

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

    it("should transfer 1000 USD tokens to each acc1 and acc2", function(done) {
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

    it("should create crowdsale (invoice amount 1000, minimum goal 900) and start auction", function(done) {
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

    it("should create two bidding groups", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            groupName1 = 'test group',
            groupGoal1 = 900,
            groupName2 = 'massive group',
            groupGoal2 = 999;

        Crowdsale.at(crowdsale).createGroup(groupName1, groupGoal1).then(function(result) {
            assert(result.logs.length, "Failed creating group 1");

            console.log('Created group 1 with goal 900');

            return Crowdsale.at(crowdsale).createGroup(groupName2, groupGoal2);
        }).then(function(result) {
            assert(result.logs.length, "Failed creating group 2");
            console.log('Created group 2 with goal 999');
            done();
        });
    });

    it("should bid to group 1 from acc1 with 450", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 0, ACC1, "AA007", 450).then(function(result) {
            assert(result.receipt.logs.length, "Failed bidding");

            return P.getLedgerEntry.call("USD", ACC1);
        }).then(function(value) {
            assert.equal(value.toNumber(), 1000 - 450, "Failed bidding");
        }).then(function(result) {
            done();
        });
    });

    it("should bid to group 2 from acc1 with 10", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 1, ACC1, "AA007", 10).then(function(result) {
            assert(result.receipt.logs.length, "Failed bidding");

            return P.getLedgerEntry.call("USD", ACC1);
        }).then(function(value) {
            assert.equal(value.toNumber(), 1000 - 450 - 10, "Failed bidding");
        }).then(function(result) {
            done();
        });
    });

    it("should bid to group 1 from acc2 with 500 and reach group goal", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 0, ACC2, "BB007", 450).then(function(result) {
            console.log(result);
            assert.equal(result.receipt.logs.length, 2, "Failed bidding");

            return P.getLedgerEntry.call("USD", ACC2);
        }).then(function(value) {
            // Group goal is 900 and the amount raised can't be more than this.
            assert.equal(value.toNumber(), 1000 - 450, "Failed bidding");
            done();
        });
    });


    it("should fund beneficiary", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.fundBeneficiary(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("USD", ACC_BORROW);
        }).then(function(value) {
            assert.equal(value.toNumber(), 900, "Failed funding beneficiary");
            done();
        });
    });

    it("should refund losing groups", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.refundLosingGroup(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("USD", ACC1);
        }).then(function(value) {
            assert.equal(value.toNumber(), 1000 - 450, "Failed refunding losing group");
            done();
        });
    });

    it("should change crowdsale status to waiting for invoice payment", function(done) {
        assert(crowdsale, "Crowdsale required.");

        Crowdsale.at(crowdsale).endAuction().then(function(result) {
            return Crowdsale.at(crowdsale).status.call();
        }).then(function(value) {
            assert.equal(value.toNumber(), 3, "Failed changing crowdsale status");
            done();
        });
    });

    it("should change crowdsale status to completed", function(done) {
        assert(crowdsale, "Crowdsale required.");

        Crowdsale.at(crowdsale).invoicePaymentReceived().then(function(result) {
            return Crowdsale.at(crowdsale).status.call();
        }).then(function(value) {
            assert.equal(value.toNumber(), 4, "Failed changing crowdsale status");
            done();
        });
    });

    it("should fund winner group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.fundWinnerGroup(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("USD", ACC1);
        }).then(function(value) {
            assert.equal(value.toNumber(), 1050, "Failed funding winner group");
            return P.getLedgerEntry.call("USD", ACC2);
        }).then(function(value) {
            assert.equal(value.toNumber(), 1050, "Failed funding winner group");
            done();
        });
    });

});