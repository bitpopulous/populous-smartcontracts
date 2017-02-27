var
    StringUtils = artifacts.require("StringUtils"),
    SafeMath = artifacts.require("SafeMath"),
    Crowdsale = artifacts.require("Crowdsale"),
    CrowdsaleManager = artifacts.require("CrowdsaleManager"),
    Populous = artifacts.require("Populous");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath, Populous);
    deployer.link(SafeMath, CrowdsaleManager);

    deployer.deploy(StringUtils);
    deployer.link(StringUtils, Crowdsale);
    deployer.link(StringUtils, CrowdsaleManager);
};