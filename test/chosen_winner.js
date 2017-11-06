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

    // Crowdsale - borrower choose winner group (refund and fund groups with split function
    describe("Chosen winner > ", function() {
        var
            BORROWER_ACC = 'borrower002',
            INVOICE_AMOUNT = 800,
            INVOICE_FUNDING_GOAL = 700,
            INVESTOR_GROUP1_GOAL = 777,
            INVESTOR_GROUP2_GOAL = 800;

        it("should create crowdsale", function(done) {
            assert(global.currencies.USD, "Currency required.");

            P.createCrowdsale(
                    "USD",
                    BORROWER_ACC,
                    "internalsystemid2",
                    "#002",
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

        it("should create groups", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var CS = Crowdsale.at(crowdsale);

            Promise.all([
                // initialBid()
                commonTests.createGroup(CS, 'Winner group', INVESTOR_GROUP1_GOAL),
                commonTests.createGroup(CS, 'Losing group 1', INVESTOR_GROUP2_GOAL),
                commonTests.createGroup(CS, 'Losing group 2', INVESTOR_GROUP2_GOAL),
            ]).then(function() {
                done();
            });
        });

        it("should make bids", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var
                CS = Crowdsale.at(crowdsale),
                accBalance = {};

            P.getLedgerEntry.call("USD", config.INVESTOR1_ACC).then(function(value) {
                accBalance[config.INVESTOR1_ACC] = value.toNumber();
                console.log("Balance", config.INVESTOR1_ACC, accBalance[config.INVESTOR1_ACC]);

                return P.getLedgerEntry.call("USD", config.INVESTOR2_ACC);
            }).then(function(value) {
                accBalance[config.INVESTOR2_ACC] = value.toNumber();
                console.log("Balance", config.INVESTOR2_ACC, accBalance[config.INVESTOR2_ACC]);

                return P.getLedgerEntry.call("USD", config.INVESTOR3_ACC);
            }).then(function(value) {
                accBalance[config.INVESTOR3_ACC] = value.toNumber();
                console.log("Balance", config.INVESTOR3_ACC, accBalance[config.INVESTOR3_ACC]);

                return Promise.all([
                    commonTests.bid(P, crowdsale, 0, config.INVESTOR3_ACC, 'ACC3', config.INVESTOR3_ACC_BALANCE),
                    commonTests.bid(P, crowdsale, 1, config.INVESTOR1_ACC, 'ACC1', 25),
                    commonTests.bid(P, crowdsale, 2, config.INVESTOR1_ACC, 'ACC1', 25),
                    commonTests.bid(P, crowdsale, 2, config.INVESTOR2_ACC, 'ACC2', 50),
                ]);
            }).then(function() {
                return P.getLedgerEntry.call("USD", config.INVESTOR3_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), accBalance[config.INVESTOR3_ACC] - config.INVESTOR3_ACC_BALANCE, "Failed bidding 1");

                return P.getLedgerEntry.call("USD", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), accBalance[config.INVESTOR1_ACC] - 50, "Failed bidding 2, 3");

                return P.getLedgerEntry.call("USD", config.INVESTOR2_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), accBalance[config.INVESTOR2_ACC] - 50, "Failed bidding 4");

                return CS.getGroup.call(0);
            }).then(function(group) {
                assert.equal(group[3].toNumber(), config.INVESTOR3_ACC_BALANCE, "Failed bidding 1");

                return CS.getGroup.call(1);
            }).then(function(group) {
                assert.equal(group[3].toNumber(), 25, "Failed bidding 2");

                return CS.getGroup.call(2);
            }).then(function(group) {
                assert.equal(group[3].toNumber(), 75, "Failed bidding 3, 4");

                done();
            });
        });

        it("should choose group 1 as winner", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var CS = Crowdsale.at(crowdsale);

            CS.borrowerChooseWinner(0).then(function(result) {
                assert(result.receipt.logs.length, "Failed choosing winner group (flag)");

                return CS.status.call();
            }).then(function(value) {
                assert.equal(value.toNumber(), 2, "Failed choosing winner group (status)");
                done();
            });
        });

        it("should fund beneficiary", function(done) {
            assert(crowdsale, "Crowdsale required.");

            P.fundBeneficiary(crowdsale).then(function(result) {
                return P.getLedgerEntry.call("USD", BORROWER_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), config.INVESTOR3_ACC_BALANCE, "Failed funding beneficiary");
                done();
            });
        });

        it("should refund losing groups with split function", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var
                CS = Crowdsale.at(crowdsale),
                refundPromises = [];

            CS.getGroupsCount().then(function(groupsCount) {
                for (var groupIndex = 0; groupIndex < groupsCount; groupIndex++) {
                    (function(groupIndex) {
                        var groupCall = CS.getGroup(groupIndex).then(function(group) {
                            var biddersCount = group[2].toNumber();

                            for (var bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
                                console.log('Executing refund', groupIndex, bidderIndex);

                                var refundCall = P.refundLosingGroupBidder(crowdsale, groupIndex, bidderIndex);
                                refundPromises.push(refundCall);
                            }
                        });

                        refundPromises.push(groupCall);
                    })(groupIndex);
                }
            });

            setTimeout(function() {
                console.log('Promises count', refundPromises.length);
                Promise.all(refundPromises).then(function() {
                    return CS.sentToLosingGroups();
                }).then(function(sentToLosingGroups) {
                    assert(sentToLosingGroups, "Failed refunding losing groups");
                    done();
                });
            }, 1000);
        });

        it("should mark invoice as paid", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var CS = Crowdsale.at(crowdsale);

            // Set payment received
            P.invoicePaymentReceived(crowdsale, INVOICE_AMOUNT).then(function(result) {
                assert(result.receipt.logs, "Failed setting payment received");

                // Check paidAmount
                return CS.paidAmount.call();
            }).then(function(paidAmount) {
                assert.equal(paidAmount.toNumber(), INVOICE_AMOUNT, "Failed setting payment received");

                // Check status
                return CS.status.call();
            }).then(function(status) {
                assert.equal(status.toNumber(), 4, "Failed setting payment received");

                done();
            });
        });

        it("should fund winner group", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var
                CS = Crowdsale.at(crowdsale),
                fundPromises = [];

            CS.winnerGroupIndex().then(function(winnerGroupIndex) {
                winnerGroupIndex = winnerGroupIndex.toNumber();

                var groupCall = CS.getGroup(winnerGroupIndex).then(function(group) {
                    var biddersCount = group[2].toNumber();

                    for (var bidderIndex = 0; bidderIndex < biddersCount; bidderIndex++) {
                        console.log('Funding winner', winnerGroupIndex, bidderIndex);

                        var fundCall = P.fundWinnerGroupBidder(crowdsale, bidderIndex);
                        fundPromises.push(fundCall);
                    }
                });

                fundPromises.push(groupCall);
            });

            setTimeout(function() {
                console.log('Promises count', fundPromises.length);
                Promise.all(fundPromises).then(function() {
                    // Check if the flag has been set
                    return CS.sentToWinnerGroup();
                }).then(function(sentToWinnerGroup) {
                    assert(sentToWinnerGroup, 'Failed funding winner group (flag)');

                    return CS.status();
                }).then(function(status) {
                    // Check if status is Completed
                    assert.equal(status, 5, "Failed funding winner group (status)");

                    // Check winner investor balance
                    return P.getLedgerEntry.call("USD", config.INVESTOR3_ACC);
                }).then(function(value) {
                    assert.equal(value.toNumber(), INVOICE_AMOUNT, "Failed funding winner group (amount)");
                    done();
                });
            }, 1000);
        });

    });

});