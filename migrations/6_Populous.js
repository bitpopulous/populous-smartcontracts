var
    AccessManager = artifacts.require("AccessManager"),
    Populous = artifacts.require("Populous");
module.exports = function(deployer) {
    var AM;
    deployer.then(function() {
        return AccessManager.deployed().then(function(instance) {
            AM = instance;
            //add deployed AccessManager instance to Populous
            return deployer.deploy(Populous, AM.address);
        })/* .then(function() {
            return Populous.deployed();
        }).then(function(P) {
            return AM.changePopulous(P.address); // comment when re-deploying to livenet
            // also check populous constructor for token addresses before deployment to ropsten or livenet
        });*/
    });
};