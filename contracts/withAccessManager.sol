pragma solidity ^0.4.13;

import "./AccessManager.sol";

contract withAccessManager {
    AccessManager public AM;

    function withAccessManager(address _accessManager) {
        AM = AccessManager(_accessManager);
    }

    modifier onlyServer {
        require(AM.isServer(msg.sender) == true);
        _;
    }

    modifier onlyGuardian {
        require(AM.isGuardian(msg.sender) == true);
        _;
    }

    modifier onlyPopulous {
        require(AM.isPopulous(msg.sender) == true);
        _;
    }

    function updateAccessManager(address _accessManager) onlyGuardian {
        AM = AccessManager(_accessManager);
    }
    
}