module.exports = {
    networks: {
        "development": {
            network_id: 3,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 4712388
        }
    }
};