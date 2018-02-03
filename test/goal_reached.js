var
Populous = artifacts.require("Populous"),
CurrencyToken = artifacts.require("CurrencyToken"),
Crowdsale = artifacts.require("Crowdsale");
CrowdsaleManager = artifacts.require("CrowdsaleManager");

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
    it("should init currency token Euros EUR", function(done) {
        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);
            // create new EUR currency token
            if (!global.currencies || !global.currencies.EUR) {
                return commonTests.createCurrency(P, "EUR Pokens", 8, "EUR");
            } else {
                return Promise.resolve();
            }
        }).then(function() {
            done();
        });
    });
});

describe("Bank", function() {
    it("should mint EUR tokens: " + (config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE), function(done) {
        assert(global.currencies.EUR, "Currency required.");
        // amount of EUR tokens to mint = balance of accountIDs 'A' + 'B' + 'C'
        // amount of EUR tokens to mint = 470 + 450 + 600 = 1,520
        var mintAmount = config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE;
        // mint mintAmount of EUR tokens and allocate to LEDGER_ACC/"Populous"
        P.mintTokens('EUR', mintAmount).then(function() {
            return P.getLedgerEntry.call("EUR", config.LEDGER_ACC);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting EUR tokens");
            done();
        });
    });

    it("should transfer EUR tokens to config.INVESTOR1_ACC, config.INVESTOR2_ACC, config.INVESTOR3_ACC", function(done) {
        assert(global.currencies.EUR, "Currency required.");
        // transfer 470 EUR tokens from 'Populous' to 'A'
        P.transfer("EUR", config.LEDGER_ACC, config.INVESTOR1_ACC, config.INVESTOR1_ACC_BALANCE).then(function() {
            // transfer 600 EUR tokens from 'Populous' to 'B'
            return P.transfer("EUR", config.LEDGER_ACC, config.INVESTOR2_ACC, config.INVESTOR2_ACC_BALANCE);
        }).then(function() {
            // transfer 600 EUR tokens from 'Populous' to 'C'
            return P.transfer("EUR", config.LEDGER_ACC, config.INVESTOR3_ACC, 250);
        }).then(function() {
            // check EUR token balance of 'A' is 470
            return P.getLedgerEntry.call("EUR", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 470, "Failed transfer 1");
            // check EUR token balance of 'B' is 450
            return P.getLedgerEntry.call("EUR", config.INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 450, "Failed transfer 2");
            // check EUR token balance of 'C' is 250
            return P.getLedgerEntry.call("EUR", config.INVESTOR3_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 250, "Failed transfer 3");
            done();
        });
    });

    it("should withdraw EUR tokens of config.INVESTOR1_ACC to a given external address", function(done) {
        assert(global.currencies.EUR, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.EUR);
        var externalAddress = accounts[0];
        var withdrawalAmount = 8;

        // withdraw withdrawal amount of EUR tokens from 'A' and send to externalAddress
        P.withdraw(externalAddress, config.INVESTOR1_ACC, 'EUR', withdrawalAmount, 3).then(function() {
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            // check withdrawal amount of EUR tokens was allocated externalAddress
            assert.equal(value.toNumber(), withdrawalAmount - 3, "Failed withdrawal");
            // check withdrawal amount of EUR tokens was withdrawn from 'A'
            return P.getLedgerEntry.call("EUR", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - withdrawalAmount, "Failed withdrawal");
            done();
        });
    });

    it("should deposit EUR tokens of config.INVESTOR1_ACC from an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.EUR, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.EUR);
        var externalAddress = accounts[0];
        var depositAmount = 8;
        // deposit EUR tokens from externalAddress to 'A'
        P.importExternalPokens("EUR", externalAddress, config.INVESTOR1_ACC).then(function(result) {
            console.log('import external pokens to ledger gas cost', result.receipt.gasUsed);
            // check that depositAmount is deducted from externalAddress account
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed deposit");
            // check that the depositAmount has been added to 'A'
            return P.getLedgerEntry.call("EUR", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 3, "Failed deposit");
            done();
        });
    });

});

describe("Reach goal with bids > ", function() {
    var
        BORROWER_ACC = 'borrower001',
        // invoice funding goal must be less than invoice amount
        // INVESTOR_GROUP2_GOAL > INVESTOR_GROUP1_GOAL
        INVOICE_AMOUNT = 1000,
        INVOICE_FUNDING_GOAL = 900,
        INVESTOR_GROUP1_GOAL = 900,
        INVESTOR_GROUP2_GOAL = 999;

    it("should init crowdsale manager", function(done) {
        CrowdsaleManager.deployed().then(function(instance) {
            CM = instance;
            console.log('Crowdsale Manager', CM.address);
            // creating a new currency GBP for which to mint and use tokens
            //return commonTests.createCurrency(P, "GBP Pokens", 3, "GBP");
            //}).then(function() {
            done();
        });
    });

    it("should create crowdsale", function(done) {
        assert(global.currencies.EUR, "Currency required.");
        // create new crowdsale with invoice amount and funding goal
        CM.createCrowdsale(
                P.address,
                "EUR",
                BORROWER_ACC,
                "internalsystemid",
                "#001",
                INVOICE_AMOUNT,
                INVOICE_FUNDING_GOAL,
                1, 'ipfs', 10)
            .then(function(createCS) {
                assert(createCS.logs.length, "Failed creating crowdsale");

                crowdsale = createCS.logs[0].args.crowdsale;
                console.log('Crowdsale', crowdsale);
                console.log('create crowdsale gas cost', createCS.receipt.gasUsed);

                done();
            });
    });

    /* it("should create two bidding groups", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            groupName1 = 'test group',
            groupGoal1 = INVESTOR_GROUP1_GOAL,
            groupName2 = 'massive group',
            groupGoal2 = INVESTOR_GROUP2_GOAL;

        commonTests.createGroup(CS, groupName1, groupGoal1).then(function(result) {
            return commonTests.createGroup(CS, groupName2, groupGoal2);
        }).then(function(result) {
            done();
        });
    }); */

    it("should create bidding group and place initial bid from config.INVESTOR1_ACC with 450", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            groupName1 = 'test group',
            groupGoal1 = INVESTOR_GROUP1_GOAL;
        // place initial bid and create group
        // only bidder not part of another group can create new group
        commonTests.initialBid(P, crowdsale, groupName1, groupGoal1, config.INVESTOR1_ACC, "AA007", 450).then(function(result) {
            return CS.getGroupsCount();
        }).then(function(value){
            // checking  group creation works with initialBid
            assert.equal(value.toNumber(), 1, "Failed creating group");
            return P.getLedgerEntry.call("EUR", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 450 - 3, "Failed bidding");
            return Crowdsale.at(crowdsale).getGroup.call(0);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), 450, "Failed bidding");
            done();
        })
    });

    /* it("should bid to group 1 from config.INVESTOR1_ACC with 450", function(done) {
        assert(crowdsale, "Crowdsale required.");

        commonTests.bid(P, crowdsale, 0, config.INVESTOR1_ACC, "AA007", 450).then(function(result) {
            return P.getLedgerEntry.call("EUR", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 450, "Failed bidding");

            return Crowdsale.at(crowdsale).getGroup.call(0);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), 450, "Failed bidding");
            done();
        });
    }); */

    it("should fail create new bidding group and place initial bid to group 1 from config.INVESTOR1_ACC with 450", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            groupName2 = 'massive group',
            groupGoal2 = INVESTOR_GROUP2_GOAL;
            
            var isCaught = false;
            // creation of this group should fail since investor1 has already created
            // and is part of a bidding group for this crowdsale.
            commonTests.initialBid(P, crowdsale, groupName2, groupGoal2, config.INVESTOR1_ACC, "AA007", 450)
            .catch(function () {isCaught = true;}
            ).then(function () {
                if (isCaught === false) {
                    throw new Error('Not allowed group creation passed !!!');
                }
                done();
            });      
    });

    it("should create bidding group and place initial bid from config.INVESTOR3_ACC with 20", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            groupName2 = 'massive group',
            groupGoal2 = INVESTOR_GROUP2_GOAL;
        // place initial bid and create bidding group
        commonTests.initialBid(P, crowdsale, groupName2, groupGoal2, config.INVESTOR3_ACC, "CC99", 20).then(function(result) {
            console.log('initial bid gas cost', result.receipt.gasUsed);
            return CS.getGroupsCount();
        }).then(function(value){
            // check group count is increased
            assert.equal(value.toNumber(), 2, "Failed creating group");
            return P.getLedgerEntry.call("EUR", config.INVESTOR3_ACC);
        }).then(function(value) {
            // check initial bid went through successfully
            assert.equal(value.toNumber(), 230, "Failed bidding");
            return Crowdsale.at(crowdsale).getGroup.call(1);
        }).then(function(group) {
            // check amount raised for group so far is = amount placed in bid
            assert.equal(group[3].toNumber(), 20, "Failed bidding");
            done();
        })
    });

    it("should bid to group 1 from config.INVESTOR2_ACC with 450 and reach group goal", function(done) {
        assert(crowdsale, "Crowdsale required.");

        commonTests.bid(P, crowdsale, 0, config.INVESTOR2_ACC, "BB007", 450).then(function(result) {
            console.log('bid gas cost', result.receipt.gasUsed);
            // Three events should be fired - bid, goal reached, crowdsale closed:
            assert.equal(result.receipt.logs.length, 4, "Failed bidding");

            return P.getLedgerEntry.call("EUR", config.INVESTOR2_ACC);
        }).then(function(value) {
            // Group goal is 900 and the amount raised can't be more than this.
            assert.equal(value.toNumber(), 0, "Failed bidding");
            return Crowdsale.at(crowdsale).getGroup.call(0);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), 900, "Failed bidding");
            return Crowdsale.at(crowdsale).getStatus();
        }).then(function(crowdsale_status){
            console.log("crowdsale status", crowdsale_status.toNumber());
            return Crowdsale.at(crowdsale).getGroupsCount();
        }).then(function(group_count){
            console.log("groups count", group_count);
            return Crowdsale.at(crowdsale).getGroup.call(0);
        }).then(function(group_info){
            console.log("group details", group_info);
            return Crowdsale.at(crowdsale).getWinnerGroupIndex();
        }).then(function(winner_index){
            console.log("winner group index", winner_index);
            done();
        });
    });
    

    it("should fund beneficiary", function(done) {
        assert(crowdsale, "Crowdsale required.");
        // fund beneficiary of crowdsale
        P.fundBeneficiary(crowdsale).then(function(result) {
            console.log('fund beneficiary gas cost', result.receipt.gasUsed);
            return P.getLedgerEntry.call("EUR", BORROWER_ACC);
        }).then(function(value) {
            // check beneficiary is funded with winning group's goal amount
            assert.equal(value.toNumber(), INVESTOR_GROUP1_GOAL, "Failed funding beneficiary");
            done();
        });
    });

    it("should refund losing group bidders", function(done) {
        assert(crowdsale, "Crowdsale required.");
        // refund loosing groups
        Crowdsale.at(crowdsale).findBidder(config.INVESTOR3_ACC).then(function(result){
            console.log('find bidder', result);
            var groupIndex = result[1].toNumber();
            var bidderIndex = result[2].toNumber();
            return P.refundLosingGroupBidder(crowdsale, result[1].toNumber(), result[2].toNumber());
        }).then(function(result){
            console.log('refund losing group bidder gas cost', result.receipt.gasUsed);
            return P.getLedgerEntry.call("EUR", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 450 - 3, "Failed refunding losing group");

            return Crowdsale.at(crowdsale).status.call();
        }).then(function(status) {
            assert.equal(status.toNumber(), 3, "Failed changing crowdsale status");
            return P.getLedgerEntry.call("EUR", config.INVESTOR3_ACC);
        }).then(function(value) {
            console.log('investor 3 balance', value);
            assert.equal(value.toNumber(), config.INVESTOR3_ACC_BALANCE - 350, "Failed refunding losing group bidder");

            done();
        });
    });

    it("should fund winner group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        // Set payment received
        P.invoicePaymentReceived(crowdsale, INVOICE_AMOUNT).then(function(result) {
            assert(result.receipt.logs, "Failed setting payment received");
            console.log('invoice payment received gas cost', result.receipt.gasUsed);
            // Check paidAmount
            return Crowdsale.at(crowdsale).paidAmount.call();
        }).then(function(paidAmount) {
            assert.equal(paidAmount.toNumber(), INVOICE_AMOUNT, "Failed setting payment received");
        
            return Crowdsale.at(crowdsale).getPaidAmount();
        }).then(function(getPaidAmount) {
            assert.equal(getPaidAmount.toNumber(), INVOICE_AMOUNT, "Failed setting payment received");
            console.log("invoice paid amount", getPaidAmount);
            
            // Check status
            return Crowdsale.at(crowdsale).status.call();
        }).then(function(status) {
            assert.equal(status.toNumber(), 4, "Failed setting payment received");

            // Fund winner group
            return P.fundWinnerGroup(crowdsale);
        }).then(function(result) {
            console.log('fund winner group gas cost', result.receipt.gasUsed);
            assert(result.receipt.logs, "Failed funding winner group");

            // Check investor1 balance
            return P.getLedgerEntry.call("EUR", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE + 50 - 3, "Failed funding winner group");

            // Check investor2 balance
            return P.getLedgerEntry.call("EUR", config.INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE + 50, "Failed funding winner group");
            done();
        })
    });

});

});