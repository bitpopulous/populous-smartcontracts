var  AccessManager = artifacts.require("AccessManager"), 
    DataManager = artifacts.require("DataManager");

module.exports = function(deployer) {
    var DM;
    var version = 1;
    /* deployer.then(function() {
        return AccessManager.deployed().then(function(instance) {
            AM = instance;
            //deploy DataManager.sol
        return deployer.deploy(DataManager, AM.address, version);
            }).then(function(){
            //get deployed DataManager instance
            //return DataManager.deployed();
            console.log('Finished deploying DataManager');
        });
    }); */

    deployer.then(function() {
        return DataManager.deployed().then(function(instance) {
            DM = instance;
            console.log('Finished deploying Data Manager ', DM.address);
        });
    });
};