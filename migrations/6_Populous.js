var
    AccessManager = artifacts.require("AccessManager"),
    Populous = artifacts.require("Populous");
module.exports = function(deployer) {
    var AM;
    deployer.then(function() {
        return AccessManager.deployed().then(function(instance) {
            AM = instance;
            //link deployed AccessManager instances to Populous
            return deployer.deploy(Populous, AM.address);
        }).then(function() {
            return Populous.deployed();
        /* }).then(function(P) {
            return AM.changePopulous(P.address);
        }).then(function() { */
            console.log('Finished deploying Populous');
        });
    });
};