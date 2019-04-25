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
        require((z = x + y) >= x);
    }
    
    function sub(
        uint x, 
        uint y
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        require((z = x - y) <= x);
    }
    
    function mul(
        uint x, 
        uint y
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        require(y == 0 || (z = x * y) / y == x);
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
  
    function pow(
        uint x, 
        uint n
    ) 
        internal 
        pure 
        returns (uint z) 
    {
        z = n % 2 != 0 ? x : 1;

        for (n /= 2; n != 0; n /= 2) {
            x = mul(x, x);

            if (n % 2 != 0) {
                z = mul(z, x);
            }
        }
    }
}