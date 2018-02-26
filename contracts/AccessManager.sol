pragma solidity ^0.4.17;


/// @title AccessManager contract
contract AccessManager {
    // FIELDS

    // fields that can be changed by constructor and functions

    address public server; // Address, which the platform website uses.
    address public populous; // Address of the Populous bank contract.

    // NON-CONSTANT METHODS

    /** @dev Constructor that sets the server when contract is deployed.
      * @param _server The address to set as the server.
      */
    function AccessManager(address _server) public {
        server = _server;
        //guardian = _guardian;
    }

    /** @dev Changes the server address that is set by the constructor.
      * @dev The method requires the message sender to be the set server.
      * @param _server The new address to be set as the server.
      */
    function changeServer(address _server) public {
        require(isServer(msg.sender) == true);
        server = _server;
    }

    /** @dev Changes the guardian address that is set by the constructor.
      * @dev The method requires the message sender to be the set guardian.
      */
    /* function changeGuardian(address _guardian) public {
        require(isGuardian(msg.sender) == true);
        guardian = _guardian;
    } */

    /** @dev Changes the populous contract address.
      * @dev The method requires the message sender to be the set server.
      * @param _populous The address to be set as populous.
      */
    function changePopulous(address _populous) public {
        require(isServer(msg.sender) == true);
        populous = _populous;
    }

    // CONSTANT METHODS
    
    /** @dev Checks a given address to determine whether it is the server.
      * @param sender The address to be checked.
      * @return bool returns true or false is the address corresponds to the server or not.
      */
    function isServer(address sender) public view returns (bool) {
        return sender == server;
    }

    /** @dev Checks a given address to determine whether it is the guardian.
      * @param sender The address to be checked.
      * @return bool returns true or false is the address corresponds to the guardian or not.
      */
    /* function isGuardian(address sender) public view returns (bool) {
        return sender == guardian;
    } */

    /** @dev Checks a given address to determine whether it is populous address.
      * @param sender The address to be checked.
      * @return bool returns true or false is the address corresponds to populous or not.
      */
    function isPopulous(address sender) public view returns (bool) {
        return sender == populous;
    }

}