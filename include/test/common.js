module.exports = {
    createCurrency: function(P, name, decimals, symbol) {
        var _blockchainActionId = "createCurrency1"

        var currencyPromise =
            P.createCurrency(_blockchainActionId, name, decimals, symbol).then(function(result) {
                //console.log("new currency", result.logs[0]);
                return P.getCurrency.call(symbol);
            }).then(function(currencyAddress) {
                assert.notEqual(currencyAddress, 0, "Failed creating currency token");

                if (!global.currencies) {
                    global.currencies = {};
                }
                global.currencies[symbol] = currencyAddress;
                console.log('Currency', symbol, currencyAddress);
            });

        return currencyPromise;
    },
};