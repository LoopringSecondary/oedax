pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

contract MathLib {
    function add(
        uint x, 
        uint y
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        require((z = x + y) >= x, "add-overflow");
    }
    
    function sub(
        uint x, 
        uint y
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        require((z = x - y) <= x, "sub-underflow");
    }
    
    function mul(
        uint x, 
        uint y
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    function min(
        uint x, 
        uint y
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        return x <= y ? x : y;
    }

    function max(
        uint x, 
        uint y
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        return x >= y ? x : y;
    }
  
}