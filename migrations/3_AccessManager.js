var AccessManager = artifacts.require("AccessManager");

module.exports = function(deployer) {
    //var acc_server = acc_guardian = web3.eth.accounts[0];
    // to do - server for test net is default accounts[0]
    var acc_server = web3.eth.accounts[0];
    // to do - server for live net is accounts[1]
    //var acc_server = web3.eth.accounts[1];
    //var acc_server = "0x494e6a97403ed08c186ebd37bcdf410a48993238";
    console.log('main account', acc_server);
    /* var acc_server = acc_guardian = "0x1338e625522717a408039df0549d187a95bec665";
    console.log('main account', acc_guardian);
    */
    //deployer.deploy(AccessManager, acc_server, acc_guardian);
    deployer.deploy(AccessManager, acc_server);
    console.log('Finished deploying AM');
};