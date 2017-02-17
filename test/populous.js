contract('Populous', function(accounts) {
    it("should create currency token", function(done) {
        var Popu = Populous.deployed();

        Popu.createCurrency("American Dollar", 3, "USD").then(function(txId) {
            console.log(txId);

            Popu.getCurrency.call("USD").then(function(currencyAddress) {
                console.log(currencyAddress);
                assert.notEqual(currencyAddress, 0, "Failed creating currency token");
                done();
            });
        });
    });
});