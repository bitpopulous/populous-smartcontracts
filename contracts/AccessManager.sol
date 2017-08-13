pragma solidity ^0.4.13;

contract AccessManager {
    address public server; // Address, which the platform website uses.
    address public guardian; // Address of the guardian, who confirms actions.
    address public populous; // Address of the Populous bank contract.

    function AccessManager(address _server, address _guardian) {
        server = _server;
        guardian = _guardian;
    }

    function isServer(address sender) public constant returns (bool) {
        return sender == server;
    }

    function isGuardian(address sender) public constant returns (bool) {
        return sender == guardian;
    }

    function isPopulous(address sender) public constant returns (bool) {
        return sender == populous;
    }

    function changeServer(address _server) {
        require(isGuardian(msg.sender) == true);
        server = _server;
    }

    function changeGuardian(address _guardian) {
        require(isGuardian(msg.sender) == true);
        guardian = _guardian;
    }

    function changePopulous(address _populous) {
        require(isGuardian(msg.sender) == true);
        populous = _populous;
    }
}