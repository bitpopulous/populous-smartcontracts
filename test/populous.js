var Populous = artifacts.require("Populous");
var CurrencyToken = artifacts.require("CurrencyToken");
var Crowdsale = artifacts.require("Crowdsale");

contract('Populous', function(accounts) {
    var
        LEDGER_ACC = "Populous",
        USD, P, crowdsale,
        INVESTOR1_ACC = 'A',
        INVESTOR2_ACC = 'B',
        INVESTOR3_ACC = 'C',
        INVESTOR1_ACC_BALANCE = 470,
        INVESTOR2_ACC_BALANCE = 450,
        INVESTOR3_ACC_BALANCE = 600;

    describe("Create currency token", function() {
        it("should create currency token American Dollar USD", function(done) {
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
    });

    describe("Bank", function() {
        it("should mint USD tokens: " + (INVESTOR1_ACC_BALANCE + INVESTOR2_ACC_BALANCE + INVESTOR3_ACC_BALANCE), function(done) {
            assert(USD, "Currency required.");

            var mintAmount = INVESTOR1_ACC_BALANCE + INVESTOR2_ACC_BALANCE + INVESTOR3_ACC_BALANCE;

            P.mintTokens('USD', mintAmount).then(function() {
                return P.getLedgerEntry.call("USD", LEDGER_ACC);
            }).then(function(amount) {
                assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
                done();
            });
        });

        it("should transfer USD tokens to INVESTOR1_ACC, INVESTOR2_ACC, INVESTOR3_ACC_BALANCE", function(done) {
            assert(USD, "Currency required.");

            P.transfer("USD", LEDGER_ACC, INVESTOR1_ACC, INVESTOR1_ACC_BALANCE).then(function() {
                return P.transfer("USD", LEDGER_ACC, INVESTOR2_ACC, INVESTOR2_ACC_BALANCE);
            }).then(function() {
                return P.transfer("USD", LEDGER_ACC, INVESTOR3_ACC, INVESTOR3_ACC_BALANCE);
            }).then(function() {
                return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE, "Failed transfer 1");

                return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVESTOR2_ACC_BALANCE, "Failed transfer 2");

                return P.getLedgerEntry.call("USD", INVESTOR3_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVESTOR3_ACC_BALANCE, "Failed transfer 3");
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

    describe("Create crowdsale and reac goal with bids", function() {
        var
            BORROWER_ACC = 'borrower001',
            INVOICE_AMOUNT = 1000,
            INVOICE_FUNDING_GOAL = 900,
            INVESTOR_GROUP1_GOAL = 900,
            INVESTOR_GROUP2_GOAL = 999;

        it("should create crowdsale and start auction", function(done) {
            assert(USD, "Currency required.");

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
                    console.log(USD,
                        BORROWER_ACC,
                        "internalsystemid",
                        "#001",
                        INVOICE_AMOUNT,
                        INVOICE_FUNDING_GOAL);

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
                assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE - 450, "Failed bidding");
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
                assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE - 450 - 20, "Failed bidding");
                done();
            });
        });

        it("should bid to group 1 from INVESTOR2_ACC with 500 and reach group goal", function(done) {
            assert(crowdsale, "Crowdsale required.");

            P.bid(crowdsale, 0, INVESTOR2_ACC, "BB007", 500).then(function(result) {
                // Three events should be fired - bid, goal reached, auction closed:
                assert.equal(result.receipt.logs.length, 4, "Failed bidding");

                return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
            }).then(function(value) {
                // Group goal is 900 and the amount raised can't be more than this.
                assert.equal(value.toNumber(), INVESTOR2_ACC_BALANCE - 450, "Failed bidding");
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
                return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE - 450, "Failed refunding losing group");

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
                return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE + 50, "Failed funding winner group");

                // Check investor2 balance
                return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVESTOR2_ACC_BALANCE + 50, "Failed funding winner group");
                done();
            })
        });

    });

    describe("Create crowdsale and borrower choose winner group", function() {
        var
            BORROWER_ACC = 'borrower002',
            INVOICE_AMOUNT = 800,
            INVOICE_FUNDING_GOAL = 700,
            INVESTOR_GROUP1_GOAL = 777;

        it("should create crowdsale and start auction", function(done) {
            assert(USD, "Currency required.");

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
                    console.log(USD,
                        BORROWER_ACC,
                        "internalsystemid2",
                        "#002",
                        INVOICE_AMOUNT,
                        INVOICE_FUNDING_GOAL);

                    done();
                });
        });

        it("should create a bidding group", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var
                groupName1 = 'test group',
                groupGoal1 = INVESTOR_GROUP1_GOAL;

            Crowdsale.at(crowdsale).createGroup(groupName1, groupGoal1).then(function(result) {
                assert(result.logs.length, "Failed creating group 1");

                console.log('Created group 1 with goal', INVESTOR_GROUP1_GOAL);
                done();
            });
        });

        it("should bid to group 1 from INVESTOR3_ACC with " + INVESTOR3_ACC_BALANCE, function(done) {
            assert(crowdsale, "Crowdsale required.");

            P.bid(crowdsale, 0, INVESTOR3_ACC, "CC007", INVESTOR3_ACC_BALANCE).then(function(result) {
                assert(result.receipt.logs.length, "Failed bidding");

                return P.getLedgerEntry.call("USD", INVESTOR3_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), 0, "Failed bidding");
                done();
            });
        });

        it("should choose group 1 as winner", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var CS = Crowdsale.at(crowdsale);

            CS.borrowerChooseWinner(0).then(function(result) {
                assert(result.receipt.logs.length, "Failed choosing winner group");

                return CS.status.call();
            }).then(function(value) {
                assert.equal(value.toNumber(), 2, "Failed choosing winner group");
                done();
            });
        });

        it("should fund beneficiary", function(done) {
            assert(crowdsale, "Crowdsale required.");

            P.fundBeneficiary(crowdsale).then(function(result) {
                return P.getLedgerEntry.call("USD", BORROWER_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVESTOR3_ACC_BALANCE, "Failed funding beneficiary");
                done();
            });
        });

        it("should refund losing groups", function(done) {
            assert(crowdsale, "Crowdsale required.");

            P.refundLosingGroups(crowdsale).then(function(result) {
                console.log(result)
                assert(result.receipt.logs.length, "Failed refunding losing groups");
                done();
            });
        });

    });

});