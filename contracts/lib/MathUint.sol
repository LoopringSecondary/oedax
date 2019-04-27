/*

  Copyright 2017 Loopring Project Ltd (Loopring Foundation).

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/
pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

/// @title Utility Functions for uint
/// @author Daniel Wang - <daniel@loopring.org>
library MathUint
{
    function mul(
        uint a,
        uint b
        )
        internal
        pure
        returns (uint c)
    {
        c = a * b;
        require(a == 0 || c / a == b, "MUL_OVERFLOW");
    }

    function sub(
        uint a,
        uint b
        )
        internal
        pure
        returns (uint)
    {
        require(b <= a, "SUB_UNDERFLOW");
        return a - b;
    }

    function add(
        uint a,
        uint b
        )
        internal
        pure
        returns (uint c)
    {
        c = a + b;
        require(c >= a, "ADD_OVERFLOW");
    }

    function min(
        uint x,
        uint y
        )
        internal
        pure
        returns (uint)
    {
        return x <= y ? x : y;
    }

    function max(
        uint x,
        uint y
        )
        internal
        pure
        returns (uint)
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
        uint y = x;

        for (n /= 2; n != 0; n /= 2) {
            y = mul(y, y);

            if (n % 2 != 0) {
                z = mul(z, y);
            }
        }
    }
}
