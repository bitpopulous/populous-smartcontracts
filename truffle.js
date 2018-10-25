module.exports = {
    networks: {
        "kovan": {
            // https://github.com/paritytech/parity/wiki/Configuring-Parity#config-file
            // ./parity --chain "kovan" --jsonrpc-apis "web3,eth,net,parity,traces,rpc,personal" --jsonrpc-cors "localhost" --no-dapps
            network_id: 42,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 3500000
        },
        "ropsten": {
            network_id: 3,
            //host: "35.177.79.70",
            // geth
            // host: "18.130.20.123",
            // parity
            host: "217.138.132.58",
            //port: 8545,
            port: 8541,
            before_timeout: 900000, //  <=== NEW
            test_timeout: 900000, //  <=== NEW
            gas: 8000000,
            gasPrice: 100000000000,
            from: '0x1326e1caba0680fce27a4beb6514713c9be4db6a'
        },
        "live": {
            network_id: 1,
            //geth
            //host: "35.176.131.242",
            //parity
            host: "18.130.87.214",
            port: 8545,
            //from: "0x3688bb90126e666d6fd97353f0a568147a007017",
            // new account on parity created in truffle
            from: "0x093f653f337924ebc311599476b235dd937be5cc",
            //gas: 4700036
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
            // geth --dev --networkid 666 --rpc --rpcapi eth,web3,db,net,debug --rpccorsdomain * console
            network_id: 666,
            host: "localhost",
            port: 8545,
            before_timeout: 200000, //  <=== NEW
            test_timeout: 300000, //  <=== NEW
            gas: 4712388
        },
        
    }
};