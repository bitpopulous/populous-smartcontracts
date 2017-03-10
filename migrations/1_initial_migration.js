var Migrations = artifacts.require("Migrations");

module.exports = function(deployer) {
    deployer.deploy(Migrations);
    console.log('Finished deploying migrations contract');
};