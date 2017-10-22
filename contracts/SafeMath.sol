pragma solidity ^0.4.17;

/// @title Overflow aware uint math functions.
/// @notice Inspired by https://github.com/MakerDAO/maker-otc/blob/master/contracts/simple_market.sol
library SafeMath {

  /** @dev Safely multiplies two unsigned/non-negative integers.
    * @dev Ensures that one of both numbers can be derived from dividing the product by the other.
    * @param a The first number.
    * @param b The second number.
    * @return uint The expected result.
    */
    function safeMul(uint a, uint b) internal pure returns (uint) {
      uint c = a * b;
      assert(a == 0 || c / a == b);
      return c;
    }

  /** @dev Safely subtracts one number from another
    * @dev Ensures that the number to subtract is lower.
    * @param a The first number.
    * @param b The second number.
    * @return uint The expected result.
    */
    function safeSub(uint a, uint b) internal pure returns (uint) {
      assert(b <= a);
      return a - b;
    }

  /** @dev Safely adds two unsigned/non-negative integers.
    * @dev Ensures that the sum of both numbers is greater or equal to one of both.
    * @param a The first number.
    * @param b The second number.
    * @return uint The expected result.
    */
    function safeAdd(uint a, uint b) internal pure returns (uint) {
      uint c = a + b;
      assert(c>=a && c>=b);
      return c;
    }
}