var PopulousToken = artifacts.require("PopulousToken");

module.exports = function(deployer) {
    // not redeployed after initial deployment, only redeployed for local tests
    deployer.then(function() {
        return deployer.deploy(PopulousToken).then(function() {
            console.log('Finished deploying PopulousToken');
        });
    });
    /* deployer.then(function() {
        return PopulousToken.deployed().then(function(instance) {
            PT = instance;
            console.log('Finished deploying Populous Token ', PT.address);
        });
    }); */
};