var AccessManager = artifacts.require("AccessManager");

module.exports = function(deployer) {
    var acc_server = acc_guardian = acc_populous = web3.eth.accounts[0];

    deployer.deploy(AccessManager, acc_server, acc_guardian, acc_populous);
};