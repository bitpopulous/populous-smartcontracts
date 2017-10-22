pragma solidity ^0.4.17;

/// @title Library used when comparing pairs of strings for the condiiton of equality
library Utils {
    
    // CONSTANT METHODS 

    /** @dev Determines whether two strings are equal.
      * @param a The first string.
      * @param b The second string.
      * @return bool A boolean value True/False to indicate the presence or absence of equality.
      */
    function equal(bytes32 a, bytes32 b) internal pure returns (bool) {
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