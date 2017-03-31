var Populous = artifacts.require("Populous");
var CurrencyToken = artifacts.require("CurrencyToken");
var Crowdsale = artifacts.require("Crowdsale");

contract('Borrower choose winner', function(accounts) {
    var
        LEDGER_ACC = "Populous",
        BORROWER_ACC = 'borrower001',
        INVESTOR1_ACC = 'A',
        INVESTOR1_ACC_BALANCE = 470,
        INVOICE_AMOUNT = 1000,
        INVOICE_FUNDING_GOAL = 900,
        INVESTOR_GROUP1_GOAL = 900,
        USD, P, crowdsale;

    it("should get Populous and USD currency token addresses", function(done) {
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

    it("should create crowdsale and start auction", function(done) {
        assert(USD, "Currency required.");

        P.createCrowdsale(
                "USD",
                BORROWER_ACC,
                "John Borrow",
                "Lisa Buyer",
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
                    "John Borrow",
                    "Lisa Buyer",
                    "internalsystemid",
                    "#001",
                    INVOICE_AMOUNT,
                    INVOICE_FUNDING_GOAL);

                done();
            });
    });

    it("should createa bidding group", function(done) {
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

    it("should bid to group 1 from INVESTOR1_ACC with " + INVESTOR1_ACC_BALANCE, function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.bid(crowdsale, 0, INVESTOR1_ACC, "AA007", INVESTOR1_ACC_BALANCE).then(function(result) {
            assert(result.receipt.logs.length, "Failed bidding");

            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
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

            return CS.getStatus.call();
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
            assert.equal(value.toNumber(), INVESTOR_GROUP1_GOAL, "Failed funding beneficiary");
            done();
        });
    });

    it("should refund losing groups", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.refundLosingGroup(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("USD", INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE - 450, "Failed refunding losing group");
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
            assert.equal(value.toNumber(), INVESTOR1_ACC_BALANCE + 50, "Failed funding winner group");
            return P.getLedgerEntry.call("USD", INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), INVESTOR2_ACC_BALANCE + 50, "Failed funding winner group");

            return Crowdsale.at(crowdsale).status.call();
        }).then(function(value) {
            assert.equal(value.toNumber(), 4, "Failed changing crowdsale status");
            done();
        });
    });
});