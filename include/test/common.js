module.exports = {
    createCurrency: function(P, name, decimals, symbol) {
        var currencyPromise =
            P.createCurrency(name, decimals, symbol).then(function(result) {
                console.log("new currency", result.logs[0]);
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

    createGroup: function(CS, name, goal) {
        return new Promise(function(resolve, reject) {
            CS.createGroup(name, goal).then(function(result) {
                assert(result.logs.length, "Failed creating group " + name + ' ' + goal);
                console.log('Created group', name, goal);

                resolve(result);
            }).catch(reject);
        });
    },

    bid: function(P, crowdsaleAddress, groupIndex, investorId, investorName, bidAmount) {
        return new Promise(function(resolve, reject) {
            P.bid(crowdsaleAddress, groupIndex, investorId, investorName, bidAmount).then(function(result) {
                assert(result.receipt.logs.length, "Failed bidding: no bidding event");
                console.log('Bid', groupIndex, investorId, investorName, bidAmount);

                resolve(result);
            }).catch(reject);
        });
    },

    initialBid: function(P, crowdsaleAddress, groupName, goal, investorId, investorName, bidAmount) {
        return new Promise(function(resolve, reject) {
            P.initialBid(crowdsaleAddress, groupName, goal, investorId, investorName, bidAmount).then(function(result) {
                assert(result.receipt.logs.length, "Failed bidding: no bidding event");
                console.log('Initial Bid', groupName, goal, investorId, investorName, bidAmount);
                console.log('Initial Bid logs', result.logs);
                resolve(result);
            }).catch(reject);
        });
    }
};