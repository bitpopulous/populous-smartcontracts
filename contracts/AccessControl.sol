pragma solidity ^0.4.8;

contract AccessControl {
    address public server; // Address, which the platform website uses.
    address public guardian; // Address of the guardian, who confirms actions.
    address public populous; // Address of the Populous bank contract.

    function AccessControl(address _server, address _guardian, address _populous) {
        server = _server;
        guardian = _guardian;
        populous = _populous;
    }

    function isServer(address sender) public constant returns (bool) {
        return msg.sender == server;
    }

    function isGuardian(address guardian) public constant returns (bool) {
        return msg.sender == server;
    }

    function isPopulous(address populous) public constant returns (bool) {
        return msg.sender == server;
    }

    modifier onlyServer {
        if (msg.sender != server) throw;
        _;
    }

    modifier onlyGuardian {
        if (msg.sender != guardian) throw;
        _;
    }

    modifier onlyPopulous {
        if (msg.sender != populous) throw;
        _;
    }

    function changeServer(address _server) onlyGuardian {
        server = _server;
    }

    function changeGuardian(address _guardian) onlyGuardian {
        guardian = _guardian;
    }

    function changePopulous(address _populous) onlyGuardian {
        populous = _populous;
    }
}