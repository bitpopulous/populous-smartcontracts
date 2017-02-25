pragma solidity ^0.4.8;

import "./Crowdsale.sol";

contract CrowdsaleManager is Owned {

    function CrowdsaleManager(address _guardian)
        withAccessControl(_server, _guardian, _populous) {} 

    function createCrowdsale(
            address _owner,
            address _guardian,
            address _currency,
            string _borrowerId,
            string _borrowerName,
            string _buyerName,
            string _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal)
        //onlyGuardian

        returns (address crowdsaleAddr)
    {
        crowdsaleAddr = new Crowdsale(
            _owner,
            _guardian,
            _currency,
            _borrowerId,
            _borrowerName,
            _buyerName,
            _invoiceId,
            _invoiceAmount,
            _fundingGoal            
        );
    }
}