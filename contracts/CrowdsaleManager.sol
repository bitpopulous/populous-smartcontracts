pragma solidity ^0.4.8;

import "./Crowdsale.sol";

contract CrowdsaleManager is withAccessManager {

    function CrowdsaleManager(address _accessManager)
        withAccessManager(_accessManager) {} 

    function createCrowdsale(
            address _currency,
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _borrowerName,
            bytes32 _buyerName,
            bytes32 _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal)
        onlyPopulous

        returns (address crowdsaleAddr)
    {
        crowdsaleAddr = new Crowdsale(
            address(AM),
            _currency,
            _currencySymbol,
            _borrowerId,
            _borrowerName,
            _buyerName,
            _invoiceId,
            _invoiceAmount,
            _fundingGoal            
        );
    }
}