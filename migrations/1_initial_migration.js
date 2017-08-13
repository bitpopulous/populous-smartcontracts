var Migrations = artifacts.require("Migrations");

module.exports = function(deployer) {
    deployer.then(function() {
        return deployer.deploy(Migrations).then(function() {
            console.log('Finished deploying migrations contract');
        });
    });
};