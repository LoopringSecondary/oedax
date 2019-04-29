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

///@title OedaxEvent - A contract for the events in Oedax contract.
///@dev events to trigger in Oedax contract.

contract IOedaxEvents {

    event AuctionCreated(
        // REVIEW? add this `factory` address.
        // address         factory,
        address indexed creator,
        uint256 indexed aucitionId,
        address indexed aucitionAddress,
        uint256         delaySeconds,
        uint256         targetPrice,
        uint256         priceScale,
        uint256         scaleFactor,
        uint256         shapeFactor,
        uint256         durationSeconds,
        bool            isWithdrawalAllowed
    );

    event AuctionFactoryChanged(
        address         factory
    );

    event FeeSettingsUpdated (
        address indexed recepient,
        uint            creationFeeEth,
        uint            protocolBips,
        uint            walletBipts,
        uint            rebateBips,
        uint            withdrawalPenaltyBips,
        uint            timestamp
    );
}