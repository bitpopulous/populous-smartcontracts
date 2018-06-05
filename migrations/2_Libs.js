var
    Utils = artifacts.require("Utils"),
    SafeMath = artifacts.require("SafeMath"),
    //Crowdsale = artifacts.require("Crowdsale"),
    //CrowdsaleManager = artifacts.require("CrowdsaleManager"),
    Populous = artifacts.require("Populous");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath, Populous);
    //deployer.link(SafeMath, CrowdsaleManager);

    deployer.deploy(Utils);
    // to do - link the utils library and the populous smart contract
    //deployer.link(Utils, Populous);
    //deployer.link(Utils, Crowdsale);
    //deployer.link(Utils, CrowdsaleManager);
    console.log('Finished deploying libs');
};