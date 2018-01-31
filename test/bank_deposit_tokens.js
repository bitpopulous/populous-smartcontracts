var
Populous = artifacts.require("Populous"),
CurrencyToken = artifacts.require("CurrencyToken"),
PopulousToken = artifacts.require("PopulousToken"),
DepositContractsManager = artifacts.require("DepositContractsManager"),
Crowdsale = artifacts.require("Crowdsale");
CrowdsaleManager = artifacts.require("CrowdsaleManager");


contract('Populous / Tokens > ', function(accounts) {
var
    config = require('../include/test/config.js'),
    commonTests = require('../include/test/common.js'),
    P, DCM, depositAddress, crowdsale, CM;

describe("Init currency token > ", function() {
    it("should init currency GBP Pokens", function(done) {
        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);
            // creating a new currency GBP for which to mint and use tokens
            return commonTests.createCurrency(P, "GBP Pokens", 3, "GBP");
        }).then(function() {
            done();
        });
    });


    it("should mint GBP tokens: " + (config.INVESTOR1_ACC_BALANCE), function(done) {
        assert(global.currencies.GBP, "Currency required.");
        // amount of GBP tokens to mint = balance of accountIDs 'A' + 'B' + 'C'
        // amount of GBP tokens to mint = 470 + 450 + 600 = 1,520
        var mintAmount = config.INVESTOR1_ACC_BALANCE;
        // mint mintAmount of GBP tokens and allocate to LEDGER_ACC/"Populous"
        P.mintTokens('GBP', mintAmount).then(function(result) {
            console.log('mint tokens gas cost', result.receipt.gasUsed);
            return P.getLedgerEntry.call("GBP", config.LEDGER_ACC);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), mintAmount, "Failed minting GBP tokens");
            done();
        });
    });
    
    it("should transfer GBP tokens to config.INVESTOR1_ACC", function(done) {
        assert(global.currencies.GBP, "Currency required.");
        // transfer 190 GBP tokens from 'Populous' to 'A'
        P.transfer("GBP", config.LEDGER_ACC, config.INVESTOR1_ACC, 190).then(function(result) {
            console.log('transfer pokens gas cost', result.receipt.gasUsed);
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 190, "Failed transfer 1");
            done();
        });
    });
    

    it("should init PPT", function(done) {
        PopulousToken.new().then(function(instance) {
            assert(instance);
            // creating a new instance of the populous token contract
            // PPT which is linked to ERC23Token.sol
            global.PPT = instance;
            console.log('PPT', global.PPT.address);

            done();
        });
    });
});

describe("Deposit Tokens > ", function() {
    it("should create deposit contract for client", function(done) {
        assert(global.PPT, "PPT required.");

        DepositContractsManager.deployed().then(function(instance) {
            DCM = instance;
            console.log('Deposit contracts manager', DCM.address);
            // create deposit contract for accountID 'A'
            return DCM.create(config.INVESTOR1_ACC);
        }).then(function(result) {
            console.log('create deposit contract log');
            // printing transaction log in console
            console.log(result.logs[0]);
            console.log('create deposit contract gas cost', result.receipt.gasUsed);
            console.log('create deposit contract FULL log', result.receipt);
            // getting the address of the deposit contract for accountID 'A'
            return DCM.getDepositAddress.call(config.INVESTOR1_ACC);
        }).then(function(address) {
            assert(address);
            depositAddress = address;
            console.log('deposit contract address', address);
            done();
        });
    });

    it("should get PPT from faucet", function(done) {
        assert(global.PPT, "PPT required.");

        var faucetAmount = 200;
        // getting PPT from faucet which increases the total amount in supply
        // and adds to the balance of the message sender accounts[0]
        global.PPT.faucet(faucetAmount).then(function() {
            return global.PPT.balanceOf(accounts[0]);
        }).then(function(amount) {
            // check that accounts[0] has the amount of PPT tokens -- 200
            // gotten from the faucet
            assert.equal(amount.toNumber(), faucetAmount, "Failed getting tokens from faucet");
            done();
        });
    });

    it("should transfer PPT to deposit address", function(done) {
        assert(global.PPT, "PPT required.");

        var faucetAmount = 200;
        // transferring 200 PPT tokens to depositAddress for client from accounts[0]
        // deositAddress is the address of the deposit contract for accountID 'A'
        global.PPT.transfer(depositAddress, faucetAmount).catch(console.log).then(function(result) {
            console.log('transfer to address gas cost', result.receipt.gasUsed);
            // checking the balance of depositAddress is 200
            return global.PPT.balanceOf(depositAddress);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), faucetAmount, "Failed getting tokens from faucet");
            done();
        });
    });

    it("should deposit PPT", function(done) {
        assert(global.PPT, "PPT required.");
        // deposit the 200 PPT from 'A' and get 190 GBP Pokens
        var
            depositAmount = 200,
            receiveCurrency = 'GBP',
            receiveAmount = 190;

        // the deposit amount is refunded later
        // When the actor deposits funds into the platform, an equivalent amount of tokens is deposited into his account
        // client gets receive amount in the particular currency ledger from 'Populous'
        DCM.deposit(P.address, config.INVESTOR1_ACC, global.PPT.address, receiveCurrency, depositAmount, receiveAmount).then(function(result) {
            console.log('new deposit log', result.logs[2]);
            console.log('PPT address', global.PPT.address);
            return DCM.getActiveDepositList.call(config.INVESTOR1_ACC, global.PPT.address, "GBP");
        }).then(function(deposit) {
            console.log('active deposit list', deposit);
            // getActiveDepositList returns three uints
            // first is length of the list.
            // the last two are amount deposited and amount received.
            assert.equal(deposit[1].toNumber(), depositAmount, 'Failed depositing PPT');
            assert.equal(deposit[2].toNumber(), receiveAmount, 'Failed depositing PPT');
            done();
        });
    });


    it("should deposit PPT and get active deposit details", function(done) {
        assert(global.PPT, "PPT required.");
        
        DCM.getActiveDeposit.call(config.INVESTOR1_ACC, global.PPT.address, "GBP", 0)
        .then(function(deposit) {
            console.log('active deposit', deposit);
            // getActiveDeposit returns three uints.
            // the first two are amount deposited and amount received.
            // the last is a boolean indicating if deposit has been released or not.
            assert.equal(deposit[0].toNumber(), 200, 'Failed depositing PPT');
            assert.equal(deposit[1].toNumber(), 190, 'Failed depositing PPT');
            assert.equal(deposit[2], false, 'Failed depositing PPT');
            done();
        });
    });


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
        assert(global.currencies.GBP, "Currency required.");
        // borrowerId is accountID 'B' and is funded when fundBeneficiary is called
        // the 200 (_invoiceAmount) is sent to invoice funders / winning group
        // the 190 (_fundingGoal) is sent to borrower from funding group
        // at the end of crowdsale
        CM.createCrowdsale(
                P.address,
                "GBP",
                "B",
                "#8888",
                "#8888",
                200,
                190,
                1, 'ipfs', 10)
            .then(function(createCS) {
                assert(createCS.logs.length, "Failed creating crowdsale");

                crowdsale = createCS.logs[0].args.crowdsale;
                deadline = createCS.logs[0].args.deadline;
                let date = new Date(deadline*1000);

                console.log('new crowdsale log', createCS.logs[0]);
                console.log('new crowdsale deadline timestamp', date);
                console.log('Crowdsale', crowdsale);
                console.log('create crowdsale gas cost', createCS.receipt.gasUsed);
                done();
            });
    });

    /* it("should create bidding group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            groupName1 = 'test group',
            groupGoal1 = 190;
        
        commonTests.createGroup(CS, groupName1, groupGoal1).then(function(result) {
            done();
        });
    }); */

    
     
    it("should create bidding group and place initial bid from config.INVESTOR1_ACC with 190", function(done) {
        assert(crowdsale, "Crowdsale required.");

        var
            CS = Crowdsale.at(crowdsale),
            groupName1 = 'test group',
            groupGoal1 = 190;
        // when bid occurs, the token amount is sent to Populous
        // so bidder must have the required amount in the currency ledger
        // investor1 has 380 GBP tokens - 190 = 190 balance
        commonTests.initialBid(P, crowdsale, groupName1, groupGoal1, config.INVESTOR1_ACC, "AA007", 190).then(function(result) {
            console.log('initial bid gas cost', result.receipt.gasUsed);
            // when you bid you are using your tokens 
            // so making a transfer of currency pegged token to populous accountId in ledger
            // which is sent to beneficiary at the end of a crowsdale
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 190, "Failed bidding");
            // getGroup returns 
            // 0 = name, 1 = goal, 2 = biddersCount, 3 = amountRaised
            // 4 = bool hasReceivedTokensBack
            return Crowdsale.at(crowdsale).getGroup.call(0);
        }).then(function(group) {
            // check that amountRaised for the group with index = 0 is 190
            assert.equal(group[3].toNumber(), 190, "Failed bidding");
            done();
        })
    });

    /* it("should bid to group 1 from config.INVESTOR1_ACC with 190", function(done) {
        assert(crowdsale, "Crowdsale required.");
        // when bid occurs, the token amount is sent to Populous
        // so bidder must have the required amount in the currency ledger
        // investor1 has 380 GBP tokens - 190 = 190 balance
        commonTests.bid(P, crowdsale, 0, config.INVESTOR1_ACC, "AA007", 190).then(function(result) {
            // when you bid you are using your tokens 
            // so making a transfer of currency pegged token to populous accountId in ledger
            // which is sent to beneficiary at the end of a crowsdale
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 190, "Failed bidding");
            // getGroup returns 
            // 0 = name, 1 = goal, 2 = biddersCount, 3 = amountRaised
            // 4 = bool hasReceivedTokensBack
            return Crowdsale.at(crowdsale).getGroup.call(0);
        }).then(function(group) {
            // check that amountRaised for the group with index = 0 is 190
            assert.equal(group[3].toNumber(), 190, "Failed bidding");
            done();
        });
    }); */


    it("should fund beneficiary", function(done) {
        assert(crowdsale, "Crowdsale required.");

        P.fundBeneficiary(crowdsale).then(function(result) {
            console.log('fund beneficiary gas cost', result.receipt.gasUsed);
            return P.getLedgerEntry.call("GBP", "B");
        }).then(function(value) {
            assert.equal(value.toNumber(), 190, "Failed funding beneficiary");
            done();
        });
    });

    it("should refund losing groups", function(done) {
        assert(crowdsale, "Crowdsale required.");
        // refund any loosing groups
        P.refundLosingGroups(crowdsale).then(function(result) {
            console.log('refund losing groups gas cost', result.receipt.gasUsed);
            done();
        });
    });


    it("should fund winner group", function(done) {
        assert(crowdsale, "Crowdsale required.");

        // Set payment received for funded invoice 
        // this sets paidAmount in crowdsale as well to the same amount
        // investor1 group will receive invoice amount of 200 and
        // investor1 the only one in the group will receive all 10 GBP interest
        // 200 + 190 = 390 balance
        P.invoicePaymentReceived(crowdsale, 200).then(function(result) {
            assert(result.receipt.logs, "Failed setting payment received");

            console.log('invoice payment received gas cost', result.receipt.gasUsed);

            // Check paidAmount set when invoicePaymentReceived
            return Crowdsale.at(crowdsale).paidAmount.call();
        }).then(function(paidAmount) {
            assert.equal(paidAmount.toNumber(), 200, "Failed setting payment received");

            // Check status
            // after paidAmount is set, status = States.PaymentReceived;
            // there are 6 states in total
            // Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed
            return Crowdsale.at(crowdsale).status.call();
        }).then(function(status) {
            assert.equal(status.toNumber(), 4, "Failed setting payment received");

            // Fund winner group
            return P.fundWinnerGroup(crowdsale);
        }).then(function(result) {
            console.log('fund winner group gas cost', result.receipt.gasUsed);
            assert(result.receipt.logs, "Failed funding winner group");

            // Check investor1 GBP balance is increased by invoice amount = 190 + 200 = 390
            // investor1 was the only bidder in winner group and bid 190 GBP
            // invoice amount was 200
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            assert.equal(value.toNumber(), 390, "Failed funding winner group");
            return Crowdsale.at(crowdsale).bidderHasTokensBack.call(config.INVESTOR1_ACC);
        }).then(function(result) {
            assert.equal(result, 1, "Failed funding bidder in winner group");
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
        // release investor1 PPT token deposit of 200 to receiver address
        // and update total as groupDeposit - investorDeposit
        // and update received as groupReceived - investorReceived 
        // and transfer balance to investor1
        // 390 - 190 = 200 gbp balance for investor1
        // gbp (received) is destroyed and ppt (deposited) is sent back
        // timelock
        DCM.releaseDeposit(P.address, config.INVESTOR1_ACC, global.PPT.address, releaseCurrency, receiver, depositIndex).then(function(result) {
            console.log('release deposit gas cost', result.receipt.gasUsed);
            // getActiveDepositList returns 1 = deposited and 2 = received
            return DCM.getActiveDepositList.call(config.INVESTOR1_ACC, global.PPT.address, "GBP");
        }).then(function(deposit) {
            // check that amount deposited and received are both = 0
            // and no longer 1 = 200, 2 = 190
            // remove 190 from investor1 received and transfer it to account[1]
            // o.transfer(populousTokenContract, receiver, deposits[clientId][populousTokenContract][receiveCurrency].list[depositIndex].deposited)
            // transfer received balance to investor1
            // _transfer(releaseCurrency, clientId, LEDGER_SYSTEM_ACCOUNT, received);
            
            assert.equal(deposit[1].toNumber(), 0, "Failed releasing deposit");
            assert.equal(deposit[2].toNumber(), 0, "Failed releasing deposit");
            // check reveiver has received the 200 token deposit
            return global.PPT.balanceOf(receiver);
        }).then(function(amount) {
            // check reveiver has been credited with 200 PPT token
            assert.equal(amount.toNumber(), depositAmount, "Failed releasing deposit");
            // get investor1 account balance in GBP tokens after 190 GBP pokens are destroyed
            return P.getLedgerEntry.call("GBP", config.INVESTOR1_ACC);
        }).then(function(value) {
            // investor1 should have 390 - 190 = 200 GBP Pokens left in GBP ledger
            // as 190 GBP Poken received when 200 PPT was deposited will be destroyed 
            // upon calling release deposit 
            assert.equal(value.toNumber(), 200, "Failed funding winner group");
            done();
        })
    });
});
});