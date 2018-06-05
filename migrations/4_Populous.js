var
    AccessManager = artifacts.require("AccessManager"),
    Populous = artifacts.require("Populous");

module.exports = function(deployer) {
    var AM;
    // to do - re-deploy populous and update changePopulous in AccessManager and test
    // comment out other deployments and re-deploy only libs and populous
    deployer.then(function() {
        return AccessManager.deployed().then(function(instance) {
            AM = instance;
            return deployer.deploy(Populous, AM.address);
        }).then(function() {
            return Populous.deployed();
        }).then(function(P) {
            return AM.changePopulous(P.address);
        }).then(function() {
            console.log('Finished deploying Populous');
        });
    });
};