pragma solidity ^0.4.8;

contract Owned {
    address public owner;
    address public guardian;

    function Owned(address _owner, address _guardian) {
        owner = _owner;
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

    function changeOwner(address _owner) onlyOwner {
        owner = _owner;
    }

    function changeGuardian(address _guardian) onlyGuardian {
        guardian = _guardian;
    }
}