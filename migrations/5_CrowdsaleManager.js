var
    AccessManager = artifacts.require("AccessManager"),
    CrowdsaleManager = artifacts.require("CrowdsaleManager"),
    Populous = artifacts.require("Populous");

module.exports = function(deployer) {
    var P;

    deployer.then(function() {
        return AccessManager.deployed().then(function(AM) {
            return deployer.deploy(CrowdsaleManager, AM.address);
        }).then(function() {
            return Populous.deployed();
        }).then(function(instance) {
            P = instance;

            return CrowdsaleManager.deployed();
        //}).then(function(CM) {
        //    return P.setCM(CM.address);
        //}).then(function() {
            console.log('Finished deploying CM');
        });
    });
};