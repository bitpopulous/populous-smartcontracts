contract('Populous', function(accounts) {
    var LEDGER_SYSTEM_NAME = "Populous";
    var USD;

    it("should create currency token American Dollar", function(done) {
        var P = Populous.deployed();

        console.log(P.address);

        P.createCurrency("American Dollar", 3, "USD").then(function(txId) {
            P.getCurrency.call("USD").then(function(currencyAddress) {
                USD = currencyAddress;
                assert.notEqual(currencyAddress, 0, "Failed creating currency token");
                done();
            });
        });
    });

    it("should mint 1000 USD tokens", function(done) {
        var P = Populous.deployed();
        var mintAmount = 1000;

        P.mintTokens('USD', mintAmount).then(function() {
            P.getLedgerEntry.call(LEDGER_SYSTEM_NAME).then(function(amount) {
                assert.equal(amount.toNumber(), mintAmount, "Failed minting USD tokens");
                done();
            });
        });
    });

    it("should transfer 100 USD tokens to accounts A and B", function(done) {
        var P = Populous.deployed();
        var mintAmount = 100;

        P.addTransaction("USD", LEDGER_SYSTEM_NAME, "A", mintAmount).then(function() {
            P.addTransaction("USD", LEDGER_SYSTEM_NAME, "B", mintAmount).then(function() {
                P.queueBackIndex.call().then(function(value) {
                    assert.notEqual(value.toNumber(), 0, "Failed adding transactions");
                    done();
                });
            });
        });
    });

    it("should execute transactions", function(done) {
        var P = Populous.deployed();

        P.txExecuteLoop().then(function(txId) {
            P.queueBackIndex.call().then(function(value) {
                assert.equal(value.toNumber(), 0, "Failed executing transactions");
                done();
            });
        });
    });
});