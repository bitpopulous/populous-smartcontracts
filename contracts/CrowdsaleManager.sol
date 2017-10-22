pragma solidity ^0.4.17;

import "./Crowdsale.sol";


/// @title Crowdsalemanager contract
contract CrowdsaleManager is withAccessManager {

    // FIELDS


    // This CrowdsaleEntry variable represents
    // the structure/details of individual invoice crowdsales
    // with details to be recorded for each crowdsale entry.
    struct CrowdsaleEntry {
        address addr; // an address
        bytes32 borrowerId; // borrowerd id
        bytes32 invoiceId; // invoice id
        bytes32 invoiceNumber; // invoice number
        uint invoiceAmount; // invoice amount
        uint fundingGoal; // funding goal
    }

    
    CrowdsaleEntry[] crowdsales;

    // The variable invoicesIndex keeps track of invoices by borrower ID, 
    // invoice number and invoice amount to keep track of auctioned 
    // invoices and restrict duplicate auctions for the same invoice.
    mapping(bytes32 => mapping(string => uint)) invoicesIndex;

    // NON-CONSTANT METHODS

    // The constructor method called when this contract instance is deployed 
    // using a modifier the _accessManager address
    function CrowdsaleManager(address _accessManager) public
        withAccessManager(_accessManager) {} 

    /** @dev Creates a new crowdsale for an invoice.
      * @param _currencySymbol The currency symbol.
      * @param _borrowerId The borrower ID.
      * @param _invoiceId The invoice ID.
      * @param _invoiceNumber The invoice number.
      * @param _fundingGoal The funding goal.
      * @param _platformTaxPercent The tax percentage
      * @param _signedDocumentIPFSHash The hash of a document stored in IPFS.
      * @return crowdsaleAddr The crowdsale address derived from deploying a crowdsale.
      */
    function createCrowdsale(
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal,
            uint _platformTaxPercent,
            string _signedDocumentIPFSHash)
        public
        onlyPopulous
        returns (address crowdsaleAddr)
    {
        // Avoid auctioning the same invoice more than once
        require(invoicesIndex[_borrowerId][_invoiceNumber] != _invoiceAmount);
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