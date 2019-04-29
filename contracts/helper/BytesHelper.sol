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
pragma solidity 0.5.7;
pragma experimental ABIEncoderV2;

/**
 * @title BytesHelper
 * @dev The BytesHelper contract converts the memory byte arrays to the standard solidity types
  */

library BytesHelper {
    function getAddress(
        bytes memory  input,
        uint          offset
        )
        internal
        pure
        returns (address output)
    {
        assembly {
            output := mload(add(input, offset))
        }
    }

    function getBool(
        bytes memory  input,
        uint          offset
        )
        internal
        pure
        returns (bool)
    {
        uint8 x;
        assembly {
            x := mload(add(input, offset))
        }
        return (x == 0);
    }

    function getUint256(
        bytes memory  input,
        uint          offset
        )
        internal
        pure
        returns (uint256 output)
    {
        assembly {
            output := mload(add(input, offset))
        }
    }
}