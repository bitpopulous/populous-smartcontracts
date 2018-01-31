pragma solidity ^0.4.17;

import "./Crowdsale.sol";
import './Populous.sol';


/// @title Crowdsalemanager contract
contract CrowdsaleManager is withAccessManager {

    event EventNewCrowdsale(address crowdsale, bytes32 _currencySymbol, bytes32 _borrowerId, bytes32 _invoiceId, string _invoiceNumber, uint _invoiceAmount, uint _fundingGoal, uint deadline);
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
    // invoice number and invoice amount to keep track of crowdsale 
    // invoices and restrict duplicate crowdsales for the same invoice.
    mapping(bytes32 => mapping(string => uint)) invoicesIndex;

    // NON-CONSTANT METHODS

    // The constructor method called when this contract instance is deployed 
    // using a modifier the _accessManager address
    function CrowdsaleManager(address _accessManager) public
        withAccessManager(_accessManager) {} 

        /** @dev Creates a new Crowdsale contract instance for an invoice crowdsale restricted to server.
      * @param _currencySymbol The currency symbol, e.g., GBP.
      * @param _borrowerId The unique borrower ID.
      * @param _invoiceId The unique invoice ID.
      * @param _invoiceNumber The unique invoice number.
      * @param _invoiceAmount The invoice amount.
      * @param _fundingGoal The funding goal of the borrower.
      * @param _platformTaxPercent The percentage charged by the platform
      * @param _signedDocumentIPFSHash The hash of related invoice documentation saved on IPFS.
      */
    function createCrowdsale(
            address populousContract,
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal,
            uint _platformTaxPercent,
            string _signedDocumentIPFSHash,
            uint _extraTime)
        public
        onlyServer
    {
        // Avoid using the same invoice in more than crowdsale
        Populous populous = Populous(populousContract);

        require(populous.getCurrency(_currencySymbol) != 0x0);
        require(invoicesIndex[_borrowerId][_invoiceNumber] != _invoiceAmount);
        require(_fundingGoal < _invoiceAmount);
        invoicesIndex[_borrowerId][_invoiceNumber] = _invoiceAmount;

        address crowdsaleAddr = new Crowdsale(
            address(AM),
            _currencySymbol,
            _borrowerId,
            _invoiceId,
            _invoiceNumber,
            _invoiceAmount,
            _fundingGoal,
            _platformTaxPercent,
            _signedDocumentIPFSHash,
            _extraTime
        );

        uint deadline = now + 24 hours;

        EventNewCrowdsale(crowdsaleAddr, _currencySymbol, _borrowerId, _invoiceId, _invoiceNumber, _invoiceAmount, _fundingGoal, deadline);
    }
}