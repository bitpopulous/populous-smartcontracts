pragma solidity ^0.4.8;

contract Owned {
    address public owner;
    address public guardian;

    function Owned(address _guardian) {
        owner = msg.sender;
        guardian = _guardian;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }

    modifier onlyGuardian {
        if (msg.sender != guardian) throw;
        _;
    }    

    function changeOwner(address _owner) onlyGuardian {
        owner = _owner;
    }

    function changeGuardian(address _guardian) onlyGuardian {
        guardian = _guardian;
    }
}