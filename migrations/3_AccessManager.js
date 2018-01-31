var AccessManager = artifacts.require("AccessManager");

module.exports = function(deployer) {
    //var acc_server = acc_guardian = web3.eth.accounts[0];
    var acc_server = web3.eth.accounts[0];
    console.log('main account', web3.eth.accounts[0]);
    /* var acc_server = acc_guardian = "0x1338e625522717a408039df0549d187a95bec665";
    console.log('main account', "0x1338e625522717a408039df0549d187a95bec665");
     */
    //deployer.deploy(AccessManager, acc_server, acc_guardian);
    deployer.deploy(AccessManager, acc_server);
    console.log('Finished deploying AM');
};