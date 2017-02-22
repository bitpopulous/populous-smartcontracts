var SafeMath = artifacts.require("SafeMath");
var CrowdsaleManager = artifacts.require("CrowdsaleManager");
var Populous = artifacts.require("Populous");

module.exports = function(deployer) {
    var P, CM;

    deployer.deploy(SafeMath);
    deployer.link(SafeMath, Populous);
    deployer.link(SafeMath, CrowdsaleManager);

    deployer.deploy(Populous).then(function() {
        return Populous.deployed();
    }).then(function(instance) {
        P = instance;

        return deployer.deploy(CrowdsaleManager, instance.address);
    }).then(function() {
        return CrowdsaleManager.deployed();
    }).then(function(instance) {
        P.setCM(instance.address);
    });
};