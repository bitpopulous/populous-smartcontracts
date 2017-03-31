module.exports = {
    networks: {
        "kovan": {
            // https://github.com/paritytech/parity/wiki/Configuring-Parity#config-file
            // ./parity --chain "kovan" --unlock "0x004D164D39039c32cb8a268f10C430E3654d5bF1" --password "peers.txt" --jsonrpc-apis "web3,eth,net,parity,traces,rpc,personal" --jsonrpc-cors "localhost" --no-dapps
            network_id: 42,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 3500000
        },
        "ropsten": {
            network_id: 3,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 4712388
        },
        "testrpc": {
            // testrpc -m "hat wet present young sphere observe enact shock retire island admit boil"
            network_id: "*",
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 4712388
        },
        "private": {
            network_id: 666,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 4712388
        },
    }
};