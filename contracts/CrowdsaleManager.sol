pragma solidity ^0.4.8;

import "./Crowdsale.sol";

contract CrowdsaleManager is withAccessManager {

    struct CrowdsaleEntry {
        address addr;
        bytes32 borrowerId;
        bytes32 invoiceId;
        bytes32 invoiceNumber;
        uint invoiceAmount;
        uint fundingGoal;
    }

    CrowdsaleEntry[] crowdsales;
    mapping(bytes32 => mapping(string => uint)) invoicesIndex;

    function CrowdsaleManager(address _accessManager)
        withAccessManager(_accessManager) {} 

    function createCrowdsale(
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal,
            uint _platformTaxPercent,
            string _signedDocumentIPFSHash)
        onlyPopulous

        returns (address crowdsaleAddr)
    {
        if (invoicesIndex[_borrowerId][_invoiceNumber] == _invoiceAmount) { throw; }
        invoicesIndex[_borrowerId][_invoiceNumber] = _invoiceAmount;

        crowdsaleAddr = new Crowdsale(
            address(AM),
            _currencySymbol,
            _borrowerId,
            _invoiceId,
            _invoiceNumber,
            _invoiceAmount,
            _fundingGoal,
            _platformTaxPercent,
            _signedDocumentIPFSHash
        );
    }
}