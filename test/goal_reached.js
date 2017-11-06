var
    Populous = artifacts.require("Populous"),
    CurrencyToken = artifacts.require("CurrencyToken"),
    Crowdsale = artifacts.require("Crowdsale");

/**
 * @TODO
 * Write tests for the restrictions: deadline checks, status checks, sent tokens checks, balances checks
 */

contract('Populous / Crowdsale > ', function(accounts) {
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

    describe("Reach goal with bids > ", function() {
        var
            BORROWER_ACC = 'borrower001',
            INVOICE_AMOUNT = 1000,
            INVOICE_FUNDING_GOAL = 900,
            INVESTOR_GROUP1_GOAL = 900,
            INVESTOR_GROUP2_GOAL = 999;

        it("should create crowdsale", function(done) {
            assert(global.currencies.USD, "Currency required.");

            P.createCrowdsale(
                    "USD",
                    BORROWER_ACC,
                    "internalsystemid",
                    "#001",
                    INVOICE_AMOUNT,
                    INVOICE_FUNDING_GOAL,
                    1, 'ipfs')
                .then(function(createCS) {
                    assert(createCS.logs.length, "Failed creating crowdsale");

                    crowdsale = createCS.logs[0].args.crowdsale;
                    console.log('Crowdsale', crowdsale);

                    done();
                });
        });

        it("should create two bidding groups", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var
                CS = Crowdsale.at(crowdsale),
                groupName1 = 'test group',
                groupGoal1 = INVESTOR_GROUP1_GOAL,
                groupName2 = 'massive group',
                groupGoal2 = INVESTOR_GROUP2_GOAL;
            // initialBid()
            commonTests.createGroup(CS, groupName1, groupGoal1).then(function(result) {
                return commonTests.createGroup(CS, groupName2, groupGoal2);
            }).then(function(result) {
                done();
            });
        });

        it("should bid to group 1 from config.INVESTOR1_ACC with 450", function(done) {
            assert(crowdsale, "Crowdsale required.");

            commonTests.bid(P, crowdsale, 0, config.INVESTOR1_ACC, "AA007", 450).then(function(result) {
                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 450, "Failed bidding");

                return Crowdsale.at(crowdsale).getGroup.call(0);
            }).then(function(group) {
                assert.equal(group[3].toNumber(), 450, "Failed bidding");
                done();
            });
        });

        it("should bid to group 2 from config.INVESTOR1_ACC two times with 10", function(done) {
            assert(crowdsale, "Crowdsale required.");

            commonTests.bid(P, crowdsale, 1, config.INVESTOR1_ACC, "AA007", 10).then(function(result) {
                return commonTests.bid(P, crowdsale, 1, config.INVESTOR1_ACC, "AA007", 10);
            }).then(function(result) {
                assert(result.receipt.logs.length, "Failed bidding");

                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 450 - 20, "Failed bidding");

                return Crowdsale.at(crowdsale).getGroup.call(1);
            }).then(function(group) {
                assert.equal(group[3].toNumber(), 20, "Failed bidding");
                done();
            });
        });

        it("should bid to group 1 from config.INVESTOR2_ACC with 500 and reach group goal", function(done) {
            assert(crowdsale, "Crowdsale required.");

            commonTests.bid(P, crowdsale, 0, config.INVESTOR2_ACC, "BB007", 500).then(function(result) {
                // Three events should be fired - bid, goal reached, auction closed:
                assert.equal(result.receipt.logs.length, 4, "Failed bidding");

                return P.getLedgerEntry.call("USD", config.INVESTOR2_ACC);
            }).then(function(value) {
                // Group goal is 900 and the amount raised can't be more than this.
                assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE - 450, "Failed bidding");

                return Crowdsale.at(crowdsale).getGroup.call(0);
            }).then(function(group) {
                assert.equal(group[3].toNumber(), 900, "Failed bidding");
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

            P.refundLosingGroups(crowdsale).then(function(result) {
                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 450, "Failed refunding losing group");

                return Crowdsale.at(crowdsale).status.call();
            }).then(function(status) {
                assert.equal(status.toNumber(), 3, "Failed changing crowdsale status");
                done();
            });
        });

        it("should fund winner group", function(done) {
            assert(crowdsale, "Crowdsale required.");

            // Set payment received
            P.invoicePaymentReceived(crowdsale, INVOICE_AMOUNT).then(function(result) {
                assert(result.receipt.logs, "Failed setting payment received");

                // Check paidAmount
                return Crowdsale.at(crowdsale).paidAmount.call();
            }).then(function(paidAmount) {
                assert.equal(paidAmount.toNumber(), INVOICE_AMOUNT, "Failed setting payment received");

                // Check status
                return Crowdsale.at(crowdsale).status.call();
            }).then(function(status) {
                assert.equal(status.toNumber(), 4, "Failed setting payment received");

                // Fund winner group
                return P.fundWinnerGroup(crowdsale);
            }).then(function(result) {
                assert(result.receipt.logs, "Failed funding winner group");

                // Check investor1 balance
                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE + 50, "Failed funding winner group");

                // Check investor2 balance
                return P.getLedgerEntry.call("USD", config.INVESTOR2_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE + 50, "Failed funding winner group");
                done();
            })
        });

    });

});