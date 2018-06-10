pragma solidity ^0.4.17;



import "./withAccessManager.sol";

/// @title DataManager contract
contract DataManager is withAccessManager {
    // FIELDS
    // currency symbol => currency erc20 contract address
    mapping(bytes32 => address) currencyAddresses;
    // currency address => currency symbol
    mapping(address => bytes32) currencySymbols;
    // clientId => depositAddress
    mapping(bytes32 => address) depositAddresses;
    // depositAddress => clientId
    mapping(address => bytes32) depositClientIds;
    //address ppt = ;


    // NON-CONSTANT METHODS

    /** @dev Constructor that sets the server when contract is deployed.
      * @param _accessManager The address to set as the access manager.
      */
    function DataManager(address _accessManager) public withAccessManager(_accessManager) {
        
    }

    function setDepositAddress(address _depositAddress, bytes32 _clientId) public onlyServerOrOnlyPopulous returns (bool success) {
        if (depositAddresses[_clientId] != 0x0 && depositClientIds[_depositAddress] != 0x0){
            return false;
        } else {
            depositAddresses[_clientId] = _depositAddress;
            depositClientIds[_depositAddress] = _clientId;
            return true;
        }
    }

    function setCurrency(address _currencyAddress, bytes32 _currencySymbol) public onlyServerOrOnlyPopulous returns (bool success) {
        if (currencySymbols[_currencyAddress] != 0x0 && currencyAddresses[_currencySymbol] != 0x0){
            return false;
        } else {
            currencySymbols[_currencyAddress] = _currencySymbol;
            currencyAddresses[_currencySymbol] = _currencyAddress;
            return true;
        }
    }

    // CONSTANT METHODS

    function getDepositAddress(bytes32 _clientId) public view returns (address clientDepositAddress){
        return depositAddresses[_clientId];
    }

    function getClientIdWithDepositAddress(address _depositContract) public view returns (bytes32 depositClientId){
        return depositClientIds[_depositContract];
    }

    function getCurrency(bytes32 _currencySymbol) public view returns (address currencyAddress) {
        return currencyAddresses[_currencySymbol];
    }
   
    function getCurrencySymbol(address _currencyAddress) public view returns (bytes32 currencySymbol) {
        return currencySymbols[_currencyAddress];
    }


}