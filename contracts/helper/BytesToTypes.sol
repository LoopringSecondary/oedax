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

/**
 * @title BytesToTypes
 * @dev The BytesToTypes contract converts the memory byte arrays to the standard solidity types
 * @author pouladzade@gmail.com
 */

// REVIEW? 感觉这个应该是个Library而不是一个contract。
contract BytesToTypes {
    function bytesToAddress(
        uint          offset,
        bytes memory  input
        )
        internal
        pure
        returns (address output)
    {
        assembly {
            output := mload(add(input, offset))
        }
    }

    function bytesToBool(
        uint          offset,
        bytes memory  input
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

    function bytesToUint256(
        uint          offset,
        bytes memory  input
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