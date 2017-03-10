var Populous = artifacts.require("Populous");
var Crowdsale = artifacts.require("Crowdsale");

contract('Populous', function(accounts) {
    var
        LEDGER_ACC = "Populous",
        BORROWER_ACC = 'borrower001',
        INVESTOR1_ACC = 'A',
        INVESTOR2_ACC = 'B',
        ACCOUNTS_BALANCE = 2000,
        INVOICE_AMOUNT = 1000,
        INVOICE_FUNDING_GOAL = 900,
        INVESTOR_GROUP1_GOAL = 900,
        INVESTOR_GROUP2_GOAL = 999,
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
            return P.getLedgerEntry.call("USD", LEDGER_ACC);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
            done();
        });
    });

    it("should transfer 2000 USD tokens to each INVESTOR1_ACC and INVESTOR2_ACC", function(done) {
        P.transfer("USD", LEDGER_ACC, INVESTOR1_ACC, ACCOUNTS_BALANCE).then(function() {
            return P.transfer("USD", LEDGER_ACC, INVESTOR2_ACC, ACCOUNTS_BALANCE);
        }).then(function() {
            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE, "Failed transfer 1");

            return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE, "Failed transfer 2");
            done();
        });
    });

    it("should create crowdsale (invoice amount 1000, minimum goal 900) and start auction", function(done) {
        assert(USD, "Currency required.");

        P.createCrowdsale(
                USD,
                BORROWER_ACC,
                "John Borrow",
                "Lisa Buyer",
                "internalsystemid",
                "#001",
                INVOICE_AMOUNT,
                INVOICE_FUNDING_GOAL)
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
            groupGoal1 = INVESTOR_GROUP1_GOAL,
            groupName2 = 'massive group',
            groupGoal2 = INVESTOR_GROUP2_GOAL;

        Crowdsale.at(crowdsale).createGroup(groupName1, groupGoal1).then(function(result) {
            assert(result.logs.length, "Failed creating group 1");

            console.log('Created group 1 with goal', INVESTOR_GROUP1_GOAL);

            return Crowdsale.at(crowdsale).createGroup(groupName2, groupGoal2);
        }).then(function(result) {
            assert(result.logs.length, "Failed creating group 2");
            console.log('Created group 2 with goal', INVESTOR_GROUP2_GOAL);
            done();
        });
    });

    it("should bid to group 1 from INVESTOR1_ACC with 450", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 0, INVESTOR1_ACC, "AA007", 450).then(function(result) {
            assert(result.receipt.logs.length, "Failed bidding");

            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE - 450, "Failed bidding");
            done();
        });
    });

    it("should bid to group 2 from INVESTOR1_ACC two times with 10", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 1, INVESTOR1_ACC, "AA007", 10).then(function(result) {
            assert(result.receipt.logs.length, "Failed bidding");

            return P.bid(crowdsale, 1, INVESTOR1_ACC, "AA007", 10);
        }).then(function(result) {
            assert(result.receipt.logs.length, "Failed bidding");

            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE - 450 - 20, "Failed bidding");
            done();
        });
    });

    it("should bid to group 1 from INVESTOR2_ACC with 500 and reach group goal", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 0, INVESTOR2_ACC, "BB007", 500).then(function(result) {
            // Three events should be fired - bid, goal reached, auction closed:
            assert.equal(result.receipt.logs.length, 3, "Failed bidding");

            return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
        }).then(function(value) {
            // Group goal is 900 and the amount raised can't be more than this.
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE - 450, "Failed bidding");
            done();
        });
    });

    it("should fund beneficiary", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.fundBeneficiary(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("USD", BORROWER_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), INVESTOR_GROUP1_GOAL, "Failed funding beneficiary");
            done();
        });
    });

    it("should refund losing groups", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.refundLosingGroup(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE - 450, "Failed refunding losing group");
            done();
        });
    });

    it("should change crowdsale status to waiting for invoice payment", function(done) {
        assert(crowdsale, "Crowdsale required.");

        Crowdsale.at(crowdsale).waitingForPayment().then(function(result) {
            return Crowdsale.at(crowdsale).status.call();
        }).then(function(value) {
            assert.equal(value.toNumber(), 3, "Failed changing crowdsale status");
            done();
        });
    });

    it("should fund winner group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.invoicePaymentReceived(crowdsale, INVOICE_AMOUNT).then(function(result) {
            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE + 50, "Failed funding winner group");
            return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), ACCOUNTS_BALANCE + 50, "Failed funding winner group");

            return Crowdsale.at(crowdsale).status.call();
        }).then(function(value) {
            assert.equal(value.toNumber(), 4, "Failed changing crowdsale status");
            done();
        });
    });

});