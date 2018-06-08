pragma solidity ^0.4.17;



import "./withAccessManager.sol";

/// @title DataManager contract
contract DataManager is withAccessManager {
    // FIELDS
    // currency symbol => currency erc20 contract address
    mapping(bytes32 => address) currencies;
    // currency address => currency symbol
    mapping(address => bytes32) currenciesSymbols;
    // clientId => depositAddress
    mapping(bytes32 => address) depositAddress;
    // depositAddress => clientId
    mapping(address => bytes32) depositClientIds;
    //address ppt = ;


    // NON-CONSTANT METHODS

    /** @dev Constructor that sets the server when contract is deployed.
      * @param _server The address to set as the server.
      */
    function DataManager(address _accessManager) public withAccessManager(_accessManager) {
        
    }

    function setDepositAddress() public onlyServerOrOnlyPopulous returns (bool success) {

    }

    function setCurrency() public onlyServerOrOnlyPopulous returns (bool success) {

    }

    // CONSTANT METHODS

    function getDepositAddress(bytes32 _clientId) public view returns (address clientDepositAddress){

    }

    function getClientIdWithDeposit() public view returns (bytes32 depositClientId){

    }

    function getCurrency(bytes32 _currencySymbol) public view returns (address currencyAddress) {

    }
   
    function getCurrencySymbol(address _currencyAddress) public view returns (bytes32 currencySymbol) {

    }


}