var
Populous = artifacts.require("Populous"),
CurrencyToken = artifacts.require("CurrencyToken"),
PopulousToken = artifacts.require("PopulousToken"),
DepositContractsManager = artifacts.require("DepositContractsManager"),
Crowdsale = artifacts.require("Crowdsale");

contract('Populous / Tokens > ', function(accounts) {
var
    config = require('../include/test/config.js'),
    commonTests = require('../include/test/common.js'),
    P, DCM, depositAddress, crowdsale;

describe("Init currency token > ", function() {
    it("should init currency GBP Pokens", function(done) {
        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);

            return commonTests.createCurrency(P, "GBP Pokens", 3, "GBP");
        }).then(function() {
            done();
        });
    });

    it("should init PPT", function(done) {
        PopulousToken.new().then(function(instance) {
            assert(instance);

            global.PPT = instance;
            console.log('PPT', global.PPT.address);

            done();
        });
    });
});

describe("Deposit Tokens > ", function() {
    it("should create deposit contract for client", function(done) {
        assert(global.PPT, "PPT required.");

        P.DCM.call().then(function(address) {
            DCM = DepositContractsManager.at(address);
            return P.createDepositContact(config.INVESTOR1_ACC);
        }).then(function() {
            return DCM.getDepositAddress.call(config.INVESTOR1_ACC);
        }).then(function(address) {
            assert(address);
            depositAddress = address;
            done();
        });
    });

    it("should get PPT from faucet", function(done) {
        assert(global.PPT, "PPT required.");

        var faucetAmount = 200;

        global.PPT.faucet(faucetAmount).then(function() {
            return global.PPT.balanceOf(accounts[0]);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), faucetAmount, "Failed getting tokens from faucet");
            done();
        });
    });

    it("should transfer PPT to deposit address", function(done) {
        assert(global.PPT, "PPT required.");

        var faucetAmount = 200;

        global.PPT.transferToAddress(depositAddress, faucetAmount).catch(console.log).then(function() {
            return global.PPT.balanceOf(depositAddress);;
        }).then(function(amount) {
            assert.equal(amount.toNumber(), faucetAmount, "Failed getting tokens from faucet");
            done();
        });
    });

    it("should deposit PPT", function(done) {
        assert(global.PPT, "PPT required.");

        var
            depositAmount = 200,
            receiveCurrency = 'GBP',
            receiveAmount = 90;
        // the deposit amount is refunded later
        // When the actor deposits funds into the platform, an equivalent amount of tokens is deposited into his account
        // client gets receive amount in the particular currency ledger from populous
        P.deposit(config.INVESTOR1_ACC, global.PPT.address, receiveCurrency, depositAmount, receiveAmount).then(function() {
            return DCM.getActiveDepositList.call(config.INVESTOR1_ACC, global.PPT.address, "GBP");
        }).then(function(deposit) {
            assert.equal(deposit[1].toNumber(), depositAmount, 'Failed depositing PPT');
            assert.equal(deposit[2].toNumber(), receiveAmount, 'Failed depositing PPT');
            done();
        });
    });

    it("should create crowdsale", function(done) {
        assert(global.currencies.GBP, "Currency required.");
        // borrowerId is account B and is funded when fundBeneficiary is called
        // the 100 (_invoiceAmount) is sent to invoice funders / winning group
        // the 90 (_fundingGoal) is sent to borrower from funding group
        // at the end of crowdsale
        P.createCrowdsale(
                "GBP",
                "B",
                "#8888",
                "#8888",
                100,
                90,
                1, 'ipfs')
            .then(function(createCS) {
                assert(createCS.logs.length, "Failed creating crowdsale");

                crowdsale = createCS.logs[0].args.crowdsale;
                console.log('Crowdsale', crowdsale);

                done();
            });
    });

    it("should create bidding group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            groupName1 = 'test group',
            groupGoal1 = 90;
        // initialBid()
        commonTests.createGroup(CS, groupName1, groupGoal1).then(function(result) {
            done();
        });
    });

    /* it("should create bidding group and place initial bid from config.INVESTOR1_ACC with 90", function(done) {
            assert(crowdsale, "Crowdsale required.");

            var
                CS = Crowdsale.at(crowdsale),
                groupName1 = 'test group',
                groupGoal1 = 45;

            commonTests.initialBid(P, crowdsale, groupName1, groupGoal1, config.INVESTOR1_ACC, "AA007", 45).then(function(result) {
                return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), 45, "Failed bidding");
                return Crowdsale.at(crowdsale).getGroup.call(0);
            }).then(function(group) {
                assert.equal(group[3].toNumber(), 45, "Failed bidding");
                done();
            })
        }); */

    it("should bid to group 1 from config.INVESTOR1_ACC with 90", function(done) {
        assert(crowdsale, "Crowdsale required.");

        commonTests.bid(P, crowdsale, 0, config.INVESTOR1_ACC, "AA007", 90).then(function(result) {
            // when you bid you are using your tokens 
            // so making a transfer of currency pegged token to populous accountId in ledger
            // which is sent to beneficiary at the end of a crowsdale
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed bidding");

            return Crowdsale.at(crowdsale).getGroup.call(0);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), 90, "Failed bidding");
            done();
        });
    });

    it("should fund beneficiary", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.fundBeneficiary(crowdsale).then(function(result) {
            return P.getLedgerEntry.call("GBP", "B");
        }).then(function(value) {
            assert.equal(value.toNumber(), 90, "Failed funding beneficiary");
            done();
        });
    });

    it("should refund losing groups", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.refundLosingGroups(crowdsale).then(function(result) {
            done();
        });
    });

    it("should fund winner group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        // Set payment received
        P.invoicePaymentReceived(crowdsale, 100).then(function(result) {
            assert(result.receipt.logs, "Failed setting payment received");

            // Check paidAmount
            return Crowdsale.at(crowdsale).paidAmount.call();
        }).then(function(paidAmount) {
            assert.equal(paidAmount.toNumber(), 100, "Failed setting payment received");

            // Check status
            return Crowdsale.at(crowdsale).status.call();
        }).then(function(status) {
            assert.equal(status.toNumber(), 4, "Failed setting payment received");

            // Fund winner group
            return P.fundWinnerGroup(crowdsale);
        }).then(function(result) {
            assert(result.receipt.logs, "Failed funding winner group");

            // Check investor1 balance
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 100, "Failed funding winner group");
            done();
        })
    });

    it("should release deposit PPT", function(done) {
        assert(global.PPT, "PPT required.");

        var
            depositAmount = 200,
            receiver = accounts[1],
            releaseCurrency = 'GBP',
            depositIndex = 0;
        // timelock
        P.releaseDeposit(config.INVESTOR1_ACC, global.PPT.address, releaseCurrency, receiver, depositIndex).then(function() {
            return DCM.getActiveDepositList.call(config.INVESTOR1_ACC, global.PPT.address, "GBP");
        }).then(function(deposit) {
            assert.equal(deposit[1].toNumber(), 0, "Failed releasing deposit");
            assert.equal(deposit[2].toNumber(), 0, "Failed releasing deposit");

            return global.PPT.balanceOf(receiver);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), depositAmount, "Failed releasing deposit");
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 10, "Failed funding winner group");
            done();
        })
    });
});
});