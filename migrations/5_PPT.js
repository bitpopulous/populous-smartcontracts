var PopulousToken = artifacts.require("PopulousToken");

module.exports = function(deployer) {
    /* deployer.then(function() {
        return deployer.deploy(PopulousToken).then(function() {
            console.log('Finished deploying PopulousToken');
        });
    }); */
    deployer.then(function() {
        return PopulousToken.deployed().then(function(instance) {
            PT = instance;
            console.log('Finished deploying Populous Token ', PT.address);
        });
    });
};