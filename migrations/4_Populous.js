var
    AccessManager = artifacts.require("AccessManager"),
    Populous = artifacts.require("Populous"),
    DataManager = artifacts.require("DataManager");

module.exports = function(deployer) {
    var AM;
    // to do - re-deploy populous and update changePopulous in AccessManager and test
    // comment out other deployments and re-deploy only libs and populous
    deployer.then(function() {
        return AccessManager.deployed().then(function(instance) {
            AM = instance;
            //deploy DataManager.sol
            return deployer.deploy(DataManager, AM.address);
        }).then(function(){
            //get deployed DataManager instance
            return DataManager.deployed();
        }).then(function(DM){
            //link deployed DataManager and AccessManager instances to Populous
            return deployer.deploy(Populous, AM.address, DM.address);
        }).then(function() {
            return Populous.deployed();
        }).then(function(P) {
            return AM.changePopulous(P.address);
        }).then(function() {
            console.log('Finished deploying Populous');
        });
    });
};