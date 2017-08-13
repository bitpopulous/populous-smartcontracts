var
    AccessManager = artifacts.require("AccessManager"),
    DepositContractsManager = artifacts.require("DepositContractsManager"),
    Populous = artifacts.require("Populous");

module.exports = function(deployer) {
    var P;

    deployer.then(function() {
        return AccessManager.deployed().then(function(AM) {
            return deployer.deploy(DepositContractsManager, AM.address);
        }).then(function() {
            return Populous.deployed();
        }).then(function(instance) {
            P = instance;

            return DepositContractsManager.deployed();
        }).then(function(DCM) {
            return P.setDCM(DCM.address);
        }).then(function() {
            console.log('Finished deploying DCM');
        });
    });
};