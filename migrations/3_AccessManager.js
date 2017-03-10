var AccessManager = artifacts.require("AccessManager");

module.exports = function(deployer) {
    var acc_server = acc_guardian = web3.eth.accounts[0];
    console.log('main account', web3.eth.accounts[0]);
    deployer.deploy(AccessManager, acc_server, acc_guardian);
    console.log('Finished deploying AM');
};