pragma solidity ^0.4.17;

import "./AccessManager.sol";


/// @title withAccessManager contract
contract withAccessManager {

    // FIELDS
    
    AccessManager public AM;

    // MODIFIERS

    // This modifier uses the isServer method in the AccessManager contract AM to determine
    // whether the msg.sender address is server.
    modifier onlyServer {
        require(AM.isServer(msg.sender) == true);
        _;
    }

    modifier onlyServerOrOnlyPopulous {
        require(AM.isServer(msg.sender) == true || AM.isPopulous(msg.sender) == true);
        _;
    }

    // This modifier uses the isGuardian method in the AccessManager contract AM to determine
    // whether the msg.sender address is guardian.
    /* modifier onlyGuardian {
        require(AM.isGuardian(msg.sender) == true);
        _;
    } */

    // This modifier uses the isPopulous method in the AccessManager contract AM to determine
    // whether the msg.sender address is populous.
    modifier onlyPopulous {
        require(AM.isPopulous(msg.sender) == true);
        _;
    }

    // NON-CONSTANT METHODS
    
    /** @dev Sets the AccessManager contract address while deploying this contract`.
      * @param _accessManager The address to set.
      */
    function withAccessManager(address _accessManager) public {
        AM = AccessManager(_accessManager);
    }
    
    /** @dev Updates the AccessManager contract address if msg.sender is guardian.
      * @param _accessManager The address to set.
      */
    function updateAccessManager(address _accessManager) public onlyServer {
        AM = AccessManager(_accessManager);
    }

}