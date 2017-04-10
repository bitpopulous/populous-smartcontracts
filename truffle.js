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
            // geth --testnet --rpc --rpccorsdomain * --bootnodes "enode://20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1@52.169.14.227:30303,enode://6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d@13.84.180.240:30303" console
            network_id: 3,
            host: "localhost",
            port: 8545,
            before_timeout: 900000, //  <=== NEW
            test_timeout: 900000, //  <=== NEW
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
            // geth --networkid 666 --datadir H:\BulgarIT\Projects\Ethereum\Populous\testnet --rpc --rpcapi eth,web3,db,net,debug --rpccorsdomain * console
            network_id: 666,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 4712388
        },
    }
};