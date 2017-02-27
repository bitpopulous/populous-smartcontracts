pragma solidity ^0.4.8;

import "./AccessManager.sol";

contract withAccessManager {
    AccessManager public AM;

    function withAccessManager(address _accessManager) {
        AM = AccessManager(_accessManager);
    }

    modifier onlyServer {
        if (AM.isServer(msg.sender) == false) throw;
        _;
    }

    modifier onlyGuardian {
        if (AM.isGuardian(msg.sender) == false) throw;
        _;
    }

    modifier onlyPopulous {
        if (AM.isPopulous(msg.sender) == false) throw;
        _;
    }

    function updateAccessManager(address _accessManager) onlyGuardian {
        AM = AccessManager(_accessManager);
    }
    
}