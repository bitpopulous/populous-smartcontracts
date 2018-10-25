var
    Utils = artifacts.require("Utils"),
    SafeMath = artifacts.require("SafeMath"),
    //Crowdsale = artifacts.require("Crowdsale"),
    //CrowdsaleManager = artifacts.require("CrowdsaleManager"),
    Populous = artifacts.require("Populous");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    // will link SafeMath library to Populous smart contract for calculations
    deployer.link(SafeMath, Populous);
};