pragma solidity ^0.4.13;

library Utils {
    
    function equal(bytes32 a, bytes32 b) internal constant returns (bool) {
        if (a.length != b.length) { 
            return false;
        }

        for (uint i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }

        return true;
    }

}