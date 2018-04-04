var
Populous = artifacts.require("Populous"),
CurrencyToken = artifacts.require("CurrencyToken"),
PopulousToken = artifacts.require("PopulousToken")
DepositContract = artifacts.require("DepositContract");


contract('Populous / CurrencyToken > ', function(accounts) {
var
    config = require('../include/test/config.js'),
    commonTests = require('../include/test/common.js'),
    P, CT, DC;

describe("Init currency token", function() {
    it("should init currency token American Dollar USD", function(done) {
        Populous.deployed().then(function(instance) {
            P = instance;
            console.log('Populous', P.address);
            // creating a new currency USD for which to mint and use tokens
            if (!global.currencies || !global.currencies.USD) {
                //create new currency/token
                return commonTests.createCurrency(P, "USD Pokens", 8, "USD");
            } else {
                return Promise.resolve();
            }
        }).then(function() {
            done();
        });
    });
});


describe("Init and transfer PPT", function() {

    it("should init PPT", function(done) {
        //create new populous PPT token
        PopulousToken.new().then(function(instance) {
            assert(instance);
            // creating a new instance of the populous token contract
            // PPT which is linked to ERC23Token.sol
            global.PPT = instance;
            console.log('PPT', global.PPT.address);
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

    it("should transfer PPT to investors ethereum wallet", function(done) {
        assert(global.PPT, "PPT required.");

        var transferAmount = 100;
        // transferring 100 PPT tokens to accounts[1] from accounts[0]
        global.PPT.transfer(config.INVESTOR1_WALLET, transferAmount).catch(console.log).then(function(result) {
            console.log('transfer to address gas cost', result.receipt.gasUsed);
            // checking the balance of accounts[1] is 100
            return global.PPT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(amount) {
            // check that balance is = amount transferred
            assert.equal(amount.toNumber(), transferAmount, "Failed getting tokens from faucet");
            done();
        });
    });


    it("should create deposit contract for client", function(done) {
        assert(global.PPT, "PPT required.");

        // create new deposit smart contract for client Id 'A'
        P.createAddress(config.INVESTOR1_ACC).then(function(instance) {
            assert(instance);
            // get deposit address with client Id 'A'
            return P.getDepositAddress(config.INVESTOR1_ACC);
        }).then(function(deposit_contract_address) {
            // display deposit smart contract address
            console.log('deposit contract address', deposit_contract_address);
            DC = DepositContract.at(deposit_contract_address);
            // call balanceOf function of deposit smart contract to check its PPT balance
            return DC.balanceOf(global.PPT.address);
        }).then(function(result) {
            // PPT balance of newly created deposit contract address should be 0
            assert.equal(result.toNumber(), 0, "failed creating deposit contract");
            done();
        });
    });


    it("should transfer PPT to deposit address", function(done) {
        assert(global.PPT, "PPT required.");

        var depositAmount = 100;
        var deposit_address;
        // transferring 100 PPT tokens to depositAddress for client from accounts[0]
        // depositAddress is the address of the deposit contract for client Id 'A'
        P.getDepositAddress(config.INVESTOR1_ACC).then(function(depositAddress){
            assert(depositAddress);
            deposit_address = depositAddress;
            // transfer PPT from accounts[1] to deposit contract address as PPT crowdsale deposit
            return global.PPT.transfer(depositAddress, depositAmount, {from: config.INVESTOR1_WALLET});
        }).then(function(result) {
            console.log('transfer to address gas cost', result.receipt.gasUsed);
            // checking the balance of depositAddress is 100
            return global.PPT.balanceOf(deposit_address);
        }).then(function(amount) {
            assert.equal(amount.toNumber(), depositAmount, "Failed getting tokens from faucet");
            done();
        });
    });

});


describe("Bank", function() {

    it("should withdraw USD tokens of config.INVESTOR1_ACC to an external address, e.g., 0x93123461712617b2f828494dbf5355b8a76d6051", function(done) {
        assert(global.currencies.USD, "Currency required.");

        var CT = CurrencyToken.at(global.currencies.USD);
        var externalAddress = config.INVESTOR1_WALLET;
        var withdrawalAmount = 370;
        var _blockchainActionId = "actionId1"
        // withdraw withdrawal amount of USD tokens for client Id 'A' from platform and send to clients externalAddress
        P.withdrawPoken(_blockchainActionId, config.INVESTOR1_ACC, externalAddress, withdrawalAmount, 'USD').then(function(result) {
            //console.log('withdraw pokens gas cost', result.receipt.gasUsed);
            // check balance of clients external address
            return CT.balanceOf(externalAddress);
        }).then(function(value) {
            // check withdrawal amount of USD tokens was correctly allocated externalAddress
            assert.equal(value.toNumber(), withdrawalAmount, "Failed withdrawal");
            return P.getActionStatus(_blockchainActionId);
        }).then(function(actionStatus){
            assert.equal(true, actionStatus, "Failed withdrawal of Pokens");
            console.log("blockchain action status for "+ _blockchainActionId + "is ", actionStatus);
            

            return P.getBlockchainActionIdData(_blockchainActionId);
        }).then(function(actionData){
            assert.equal(web3.toUtf8(actionData[0]), 'USD', "Failed getting correct currency");
            assert.equal(actionData[1], withdrawalAmount, "Failed getting correct amount");
            assert.equal(web3.toUtf8(actionData[2]), config.INVESTOR1_ACC, "Failed getting correct action id");
            assert.equal(actionData[3], externalAddress, "Failed getting correct address to/from");
        
            done();
        });
    });


    it("should import USD tokens of config.INVESTOR1_WALLET to an internal account Id, e.g., A", function(done) {
        assert(global.currencies.USD, "Currency required.");
        var CT = CurrencyToken.at(global.currencies.USD);
        var _blockchainActionId = "import1"
        //check balance of clients external address is 370 sent to it earlier using withdraw function
        CT.balanceOf(config.INVESTOR1_WALLET).then(function(balance){
            assert.equal(balance.toNumber(), 370, "failed earlier withdrawal of tokens");
            // import all the tokens from external 
            return P.importPokens(_blockchainActionId, 'USD', config.INVESTOR1_WALLET, config.INVESTOR1_ACC);
        }).then(function(result) {
            // check token balance of wallet is 0
            return CT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(value) {
            assert.equal(value.toNumber(), 0, "Failed importing tokens");
            done();
        });
    });


    it("should withdraw PPT to investor wallet", function(done) {
        assert(global.PPT, "PPT required.");

        var depositAmount = 100;
        var balances = 50;
        var inCollateral = 49;
        var deposit_address;
        var depositContractPPTBalance, investorPPTBalance;
        var _blockchainActionId = "withdrawppt1"

        // get address of deposit address for client Id 'A'
        P.getDepositAddress(config.INVESTOR1_ACC).then(function(depositAddress){
            assert(depositAddress);
            deposit_address = depositAddress;
            // get PPT balance of the address is 100 PPT sent to it as deposit amount
            return global.PPT.balanceOf(depositAddress);
        }).then(function(result) {
            // checking the balance of depositAddress is 100
            assert.equal(result.toNumber(), 100, "failed depositing PPT");
            //withdraw 50 PPT from deposit contract to wallet
            return P.withdrawPPT(_blockchainActionId, global.PPT.address, config.INVESTOR1_ACC, deposit_address, config.INVESTOR1_WALLET, 50, inCollateral);
        }).then(function(withdrawPPT) {
            assert(withdrawPPT.logs.length, "Failed withdrawing PPT");
            // get PPT token balance of deposit contract address
            return global.PPT.balanceOf(deposit_address); 
        }).then(function(balanceOfDepositContract){
            assert.equal(balanceOfDepositContract.toNumber(), balances, "failed withdrawing PPT");
            depositContractPPTBalance = balanceOfDepositContract.toNumber();
            // check balance of external address is deposit contract balance - amount withdrawn
            return global.PPT.balanceOf(config.INVESTOR1_WALLET);
        }).then(function(balanceOfInvestor){
            investorPPTBalance = balanceOfInvestor.toNumber();
            // check balance of external wallet and deposit contract address are equal
            assert.equal(balanceOfInvestor.toNumber(), balances, "failed withdrawing PPT");
            assert.equal(investorPPTBalance, depositContractPPTBalance, "failed withdrawing PPT");
            done();
        });
    });


});


describe("Crowdsale data", function() {

    var crowdsaleId = "#AA001";

    it("should get number of crowdsale document blocks", function(done) {
        // get crowdsale document records
        P.getRecordDocumentIndexes(crowdsaleId).then(function(numberofBlocks) {
            assert.equal(numberofBlocks.toNumber(), 0, "failed getting correct number of crowdsale blocks");
            done();
        });
    });

    it("should insert crowdsale block", function(done) {
        var _invoiceId = "#invoice023";
        //var _ipfsHash1 = "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2t";
        //length 47
        var _ipfsHash = "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2tp";
        //var _ipfsHash2 = "QmT4AeWE9Q9EaoyLJiqaZuYQ8mJeq4ZBncjjFH9dQ9uDVA";
        //var _awsHash1 = "QmT9qk3CRYbFDWpDFYeAv8T8H1gnongwKhh5J68NLkLir6"; 
        //var _awsHash = "QmT2qk3CRYbFDWpDFYeAv8T8H1gnongwKhh5J68NLkLir6";
        var _dataType = "pdf contract";
        var _blockchainActionId = "insertBlock1"
        // insert crowdsale block in populous.sol contract
        // ipfs hashes are length 46 and need to be stored as bytes and not bytes32
        P.insertBlock(_blockchainActionId, crowdsaleId, _invoiceId, _ipfsHash, _dataType).then(function(result){
            //console.log('insert block log', result.logs[0]);
            assert(result.logs.length, "Failed inserting block");
            console.log('insert block source length', result.logs[0].args.sourceLength.toNumber());
            // get inserted record at index 0
            return P.getRecord(crowdsaleId, 0);
        }).then(function(crowdsale_record){
            //console.log('crowdsale record', crowdsale_record);
            assert.equal(web3.toUtf8(crowdsale_record[0]), _invoiceId, "failed returning correct crowdsale record");
            console.log('hash from contract', web3.toUtf8(crowdsale_record[1]));
            console.log('hash param', _ipfsHash);
            assert.equal(web3.toUtf8(crowdsale_record[1]), _ipfsHash, "failed returning correct crowdsale record");
            // get total number of blocks inserted for a crowdsale Id
            return P.getRecordDocumentIndexes(crowdsaleId);
        }).then(function(numberofBlocks) {
            // insertBlock pushes into one arrays
            assert.equal(numberofBlocks.toNumber(), 1, "failed getting correct number of crowdsale blocks");
            done();
        });
    });

    it("should insert crowdsale source", function(done) {
        var _invoiceId = "#invoice023";
        //var _dataHash1 = "QmWWQSuPMS6aXCbZKpEjPHPUZN2NjB3YrhJTHsV4X3vb2z";
        var _dataHash = "QmT4AeWE9Q9EaoyLJiqaZuYQ8mJeq4ZBncjjFH9dQ9uDVL";
        var _dataSource = "ipfs"; 
        var _dataType = "pdf contract";
        // insert crowdsale record using public function inserSource in populous.sol
        // this will only make one array push only after 
        P.insertSource(crowdsaleId, _dataHash, _dataSource, _dataType).then(function(result){
            assert(result.logs.length, "Failed inserting source");
            //console.log('insert source log', result.logs[0]);
            console.log('insert block source length', result.logs[0].args.sourceLength.toNumber());
            // get inserted record at index 1
            return P.getRecord(crowdsaleId, 1);
        }).then(function(crowdsale_record){
            // check hash stored at index 0 for inserted block at index 2
            assert.equal(web3.toUtf8(crowdsale_record[0]), _invoiceId, "failed returning correct crowdsale record");
            //console.log('crowdsale record', crowdsale_record);
            // get total number of inserted crowdsale document blocks for a crowdsale Id
            return P.getRecordDocumentIndexes(crowdsaleId);
        }).then(function(numberofBlocks) {
            assert.equal(numberofBlocks.toNumber(), 2, "failed getting correct number of crowdsale blocks");
            done();
        });
    });

});

});