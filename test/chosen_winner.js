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
    it("should init currency token Chinese Yuan CNY", function(done) {
        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);

            if (!global.currencies || !global.currencies.CNY) {
                return commonTests.createCurrency(P, "CNY Pokens", 3, "CNY");
            } else {
                return Promise.resolve();
            }
        }).then(function() {
            done();
        });
    });
});


describe("Bank", function() {
    it("should mint CNY tokens: " + (config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE), function(done) {
        assert(global.currencies.CNY, "Currency required.");
        // amount of CNY tokens to mint = balance of accountIDs 'A' + 'B' + 'C'
        // amount of CNY tokens to mint = 470 + 450 + 600 = 1,520
        var mintAmount = config.INVESTOR1_ACC_BALANCE + config.INVESTOR2_ACC_BALANCE + config.INVESTOR3_ACC_BALANCE;
        // mint mintAmount of CNY tokens and allocate to LEDGER_ACC/"Populous"
        P.mintTokens('CNY', mintAmount).then(function() {
            return P.getLedgerEntry.call("CNY", config.LEDGER_ACC);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting CNY tokens");
            done();
        });
    });

    it("should transfer CNY tokens to config.INVESTOR1_ACC, config.INVESTOR2_ACC, config.INVESTOR3_ACC_BALANCE", function(done) {
        assert(global.currencies.CNY, "Currency required.");
        // transfer 470 CNY tokens from 'Populous' to 'A'
        P.transfer("CNY", config.LEDGER_ACC, config.INVESTOR1_ACC, config.INVESTOR1_ACC_BALANCE).then(function() {
            // transfer 450 CNY tokens from 'Populous' to 'B'
            return P.transfer("CNY", config.LEDGER_ACC, config.INVESTOR2_ACC, config.INVESTOR2_ACC_BALANCE);
        }).then(function() {
            // transfer 600 CNY tokens from 'Populous' to 'C'
            return P.transfer("CNY", config.LEDGER_ACC, config.INVESTOR3_ACC, config.INVESTOR3_ACC_BALANCE);
        }).then(function() {
            // check CNY token balance of 'A' is 470
            return P.getLedgerEntry.call("CNY", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE, "Failed transfer 1");
            // check CNY token balance of 'B' is 450
            return P.getLedgerEntry.call("CNY", config.INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE, "Failed transfer 2");
            // check CNY token balance of 'C' is 600
            return P.getLedgerEntry.call("CNY", config.INVESTOR3_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR3_ACC_BALANCE, "Failed transfer 3");
            done();
        });
    });

    it("should withdraw CNY tokens of config.INVESTOR1_ACC to an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.CNY, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.CNY);
        var externalAddress = accounts[0];
        var withdrawalAmount = 8;

        // withdraw withdrawal amount of CNY tokens from 'A' and send to externalAddress
        P.withdraw(externalAddress, config.INVESTOR1_ACC, 'CNY', withdrawalAmount).then(function() {
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            // check withdrawal amount of CNY tokens was allocated externalAddress
            assert.equal(value.toNumber(), withdrawalAmount, "Failed withdrawal");
            // check withdrawal amount of CNY tokens was withdrawn from 'A'
            return P.getLedgerEntry.call("CNY", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - withdrawalAmount, "Failed withdrawal");
            done();
        });
    });

    it("should deposit CNY tokens of config.INVESTOR1_ACC from an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.CNY, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.CNY);
        var externalAddress = accounts[0];
        var depositAmount = 8;
        // deposit CNY tokens from externalAddress to 'A'
        CT.transferToContract(P.address, depositAmount, config.INVESTOR1_ACC, { from: externalAddress }).then(function(result) {
            console.log('transfer to contract gas cost', result.receipt.gasUsed);
            // check that depositAmount is deducted from externalAddress account
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed deposit");
            // check that the depositAmount has been added to 'A'
            return P.getLedgerEntry.call("CNY", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE, "Failed deposit");
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
        assert(global.currencies.CNY, "Currency required.");
        // new invoice crowdsale
        P.createCrowdsale(
                "CNY",
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

/* 
    it("should close crowdsale and update status", function(done){
        assert(crowdsale, "Crowdsale required.");

        // Check status
        // there are 6 states in total
        // Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed
        // Crowdsale.at(crowdsale).checkDeadline().then(function(){
        // Crowdsale.at(crowdsale).closeCrowdsale().then(function(){
        P.closeCrowdsale(crowdsale).then(function(){
            return Crowdsale.at(crowdsale).status.call();
        }).then(function(status) {
            assert.equal(status.toNumber(), 2, "Failed crowdsale status to closed");
            done();
        });
    });

    it ("should check if crowdsale deadline has reached without any bids", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var CS = Crowdsale.at(crowdsale);

        CS.checkNoBids().then(function(result){
            return CS.getClosedNoBids();
        }).then(function(closedWithNoBids){
            console.log('check no bids', closedWithNoBids);
            assert.equal(closedWithNoBids, false, "Failed checking crowdsale closed without bids");
            done();
        })
        
    }) */

    it("should create groups and make bids", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var CS = Crowdsale.at(crowdsale);
        /* // creating three test groups
        Promise.all([
            commonTests.createGroup(CS, 'Winner group', INVESTOR_GROUP1_GOAL),
            commonTests.createGroup(CS, 'Losing group 1', INVESTOR_GROUP2_GOAL),
            commonTests.createGroup(CS, 'Losing group 2', INVESTOR_GROUP2_GOAL),
        ]) 
        .then(function() {
            done();
        });*/
        var
        groupName1 = 'Winner group',
        groupName2 = 'Losing group 1',
        groupName3 = 'Losing group 2';
        
        // creating three test groups 
        // with initial bids from investor 1, 2 and 3
        commonTests.initialBid(P, crowdsale, groupName1, INVESTOR_GROUP1_GOAL, config.INVESTOR3_ACC, 'ACC3', config.INVESTOR3_ACC_BALANCE)
        .then(function(){
            return commonTests.initialBid(P, crowdsale, groupName2, INVESTOR_GROUP2_GOAL, config.INVESTOR1_ACC, 'ACC1', 25);
            
        }).then(function(){
            return commonTests.initialBid(P, crowdsale, groupName2, INVESTOR_GROUP2_GOAL, config.INVESTOR2_ACC, 'ACC2', 50);
            
        }).then(function(){
            return CS.getGroupsCount();
        }).then(function(value){
            // checking group creation works with initialBid
            assert.equal(value.toNumber(), 3, "Failed creating three groups");
            
            done();
        });
    });

    it("should bid to group 2 from config.INVESTOR1_ACC with 25", function(done) {
        assert(crowdsale, "Crowdsale required.");
        // bid to group 2 with 25 from investor 1
        commonTests.bid(P, crowdsale, 1, config.INVESTOR1_ACC, 'ACC1', 25).then(function(result) {
            console.log('bid gas cost', result.receipt.gasUsed);

            return P.getLedgerEntry.call("CNY", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 50, "Failed bidding twice to group 2");
            return Crowdsale.at(crowdsale).getGroup.call(1);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), 50, "Failed bidding");
            done();
        });
    });

    it("should verify that bids were successful", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var CS = Crowdsale.at(crowdsale);

        P.getLedgerEntry.call("CNY", config.INVESTOR3_ACC)
        .then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR3_ACC_BALANCE - config.INVESTOR3_ACC_BALANCE, "Failed bidding 1");

            return P.getLedgerEntry.call("CNY", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR1_ACC_BALANCE - 50, "Failed bidding 2, 3");

            return P.getLedgerEntry.call("CNY", config.INVESTOR2_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), config.INVESTOR2_ACC_BALANCE - 50, "Failed bidding 4");

            return CS.getGroup.call(0);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), config.INVESTOR3_ACC_BALANCE, "Failed bidding 1");

            return CS.getGroup.call(1);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), 50, "Failed bidding 2");

            return CS.getGroup.call(2);
        }).then(function(group) {
            assert.equal(group[3].toNumber(), 50, "Failed bidding 3, 4");

            done();
        });
    });

    /* it("should make bids", function(done) {
        assert(crowdsale, "Crowdsale required.");
        var
            CS = Crowdsale.at(crowdsale),
            accBalance = {};
        // checking investor token balances on ledger
        P.getLedgerEntry.call("CNY", config.INVESTOR1_ACC).then(function(value) {
            accBalance[config.INVESTOR1_ACC] = value.toNumber();
            console.log("Balance", config.INVESTOR1_ACC, accBalance[config.INVESTOR1_ACC]);

            return P.getLedgerEntry.call("CNY", config.INVESTOR2_ACC);
        }).then(function(value) {
            accBalance[config.INVESTOR2_ACC] = value.toNumber();
            console.log("Balance", config.INVESTOR2_ACC, accBalance[config.INVESTOR2_ACC]);

            return P.getLedgerEntry.call("CNY", config.INVESTOR3_ACC);
        }).then(function(value) {
            accBalance[config.INVESTOR3_ACC] = value.toNumber();
            console.log("Balance", config.INVESTOR3_ACC, accBalance[config.INVESTOR3_ACC]);
            // making multiple bids at once
            return Promise.all([
                commonTests.bid(P, crowdsale, 0, config.INVESTOR3_ACC, 'ACC3', config.INVESTOR3_ACC_BALANCE),
                commonTests.bid(P, crowdsale, 1, config.INVESTOR1_ACC, 'ACC1', 25),
                // to do - should fail
                commonTests.bid(P, crowdsale, 2, config.INVESTOR1_ACC, 'ACC1', 25),
                commonTests.bid(P, crowdsale, 2, config.INVESTOR2_ACC, 'ACC2', 50),
            ]);
        }).then(function() {
            // checking that amount is deducted from investor accounts on ledger
            return P.getLedgerEntry.call("CNY", config.INVESTOR3_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), accBalance[config.INVESTOR3_ACC] - config.INVESTOR3_ACC_BALANCE, "Failed bidding 1");

            return P.getLedgerEntry.call("CNY", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), accBalance[config.INVESTOR1_ACC] - 50, "Failed bidding 2, 3");

            return P.getLedgerEntry.call("CNY", config.INVESTOR2_ACC);
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
    }); */

    it("should choose group 1 as winner", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var CS = Crowdsale.at(crowdsale);
        // choosing a group as winner of invoice crowdsale
        CS.borrowerChooseWinner(0).then(function(result) {
            assert(result.receipt.logs.length, "Failed choosing winner group (flag)");
            console.log('borrower choose winner', result);
            console.log('borrower choose winner log', result.logs[0]);
            console.log('borrower choose winner gas cost', result.receipt.gasUsed);
            return CS.status.call();
            // checking crowdsale status is correct = Closed
            // crowdsale ststuses are : Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed
        }).then(function(value) {
            assert.equal(value.toNumber(), 2, "Failed choosing winner group (status)");
            done();
        });
    });


    it("should check crowdsale haswinner", function(done){
        assert(crowdsale, "Crowdsale required.");

        var CS = Crowdsale.at(crowdsale);
        // Check status
        // there are 6 states in total
        // Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed
        // Crowdsale.at(crowdsale).checkDeadline().then(function(){
        // Crowdsale.at(crowdsale).closeCrowdsale().then(function(){
        CS.getHasWinnerGroup().then(function(haswinner){
            console.log("Crowdsale has winner", haswinner);
            assert.equal(haswinner, true, "Failed to get right haswinner boolean");
            done();
        });
    });

    it("should check if crowdsale deadline has reached", function(done){
        assert(crowdsale, "Crowdsale required.");

        var CS = Crowdsale.at(crowdsale);
        // Check status
        // there are 6 states in total
        // Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed
        // Crowdsale.at(crowdsale).checkDeadline().then(function(){
        // Crowdsale.at(crowdsale).closeCrowdsale().then(function(){
        CS.checkDeadline().then(function(){
            return CS.getDeadlineReached();
        }).then(function(deadline){
            console.log("Crowdsale deadline reached", deadline);
            assert.equal(deadline, false, "Failed to get right deadline reached boolean");
            done();
        });
    });

    it("should fund beneficiary", function(done) {
        assert(crowdsale, "Crowdsale required.");
        // funding beneficiary and checking beneficiary ledger balance
        P.fundBeneficiary(crowdsale).then(function(result) {
            console.log('fund beneficiary gas cost', result.receipt.gasUsed);
            return P.getLedgerEntry.call("CNY", BORROWER_ACC);
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
        // refunding loosers in loosing groups of crowdsale
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

        // Set invoice payment received
        P.invoicePaymentReceived(crowdsale, INVOICE_AMOUNT).then(function(result) {
            assert(result.receipt.logs, "Failed setting payment received");
            console.log('invoice payment received gas cost', result.receipt.gasUsed);
            // Check paidAmount
            return CS.paidAmount.call();
        }).then(function(paidAmount) {
            assert.equal(paidAmount.toNumber(), INVOICE_AMOUNT, "Failed setting payment received");

            // Check status = 4
            // crowdsale statuses = Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed
            return CS.status.call();
        }).then(function(status) {
            assert.equal(status.toNumber(), 4, "Failed setting payment received");

            done();
        });
    });

    it("should get correct invoice paid amount", function(done) {
        assert(crowdsale, "Crowdsale required.");
        var CS = Crowdsale.at(crowdsale);
        
        CS.getPaidAmount().then(function(amount) {
            console.log("Amount received:", amount.toNumber());
            assert.equal(amount.toNumber(), INVOICE_AMOUNT, "Failed getting paid amount");
            
            done();
        });
    });


    it("should get correct crowdsale winner group index", function(done) {
        assert(crowdsale, "Crowdsale required.");
        var CS = Crowdsale.at(crowdsale);
        
        CS.getWinnerGroupIndex().then(function(group_index) {
            console.log("Winner group index:", group_index.toNumber());
            assert.equal(group_index.toNumber(), 0, "Failed getting paid amount");
            
            done();
        });
    });

    it("should fund winner group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            fundPromises = [];
        // funding bidders in winner group based on contributions
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
                return P.getLedgerEntry.call("CNY", config.INVESTOR3_ACC);
            }).then(function(value) {
                assert.equal(value.toNumber(), INVOICE_AMOUNT, "Failed funding winner group (amount)");
                done();
            });
        }, 1000);
    });

});

});