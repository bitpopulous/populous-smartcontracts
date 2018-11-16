module.exports = {
    networks: {
      testrpc: {
        network_id: "*",
        host: "localhost",
        port: 8545,
        before_timeout: 200000, //  <=== NEW
        test_timeout: 300000 //  <=== NEW
        //gas: 4712388
      },
      ropsten: {
        network_id: 3,
        //host: "35.177.79.70",
        // geth
        //host: "18.130.20.123",
        // parity
        host: "217.138.132.58",
        //port: 8545,
        port: 8541,
        //before_timeout: 900000, //  <=== NEW
        //test_timeout: 900000, //  <=== NEW
        gas: 8000029,
        //gasPrice: 100000000000
        //from: '0x1326e1caba0680fce27a4beb6514713c9be4db6a'
      },
      live: {
        network_id: 1,
        //geth
        //host: "35.176.131.242",
        //parity
        host: "3.8.120.99",
        port: 8545,
        //from: "0x3688bb90126e666d6fd97353f0a568147a007017",
        // new account on parity created in truffle
        // truffle(live)> web3.personal.newAccount('Emirates21')
        // '0x9602fe1f115341e958166a1a0f3d9f4697012b6d'
        //parity
        //old host: "18.130.87.214",
        //old port: 8545,
        // from: "0x093f653f337924ebc311599476b235dd937be5cc",
        //gas: 4700036
        gas: 8000000,
        gasPrice: 100000000000
      }
    }
  };
  
  