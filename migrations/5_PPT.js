var PopulousToken = artifacts.require("PopulousToken");

module.exports = function(deployer) {
    deployer.then(function() {
        return deployer.deploy(PopulousToken).then(function() {
            console.log('Finished deploying PopulousToken');
        });
    });
};