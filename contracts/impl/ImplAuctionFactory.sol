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

import "../impl/ImplAuction.sol";
import "../iface/IAuctionFactory.sol";
import "../helper/DataHelper.sol";

contract ImplAuctionFactory is DataHelper {

    address public owner;
    address public oedax;
    address public treasury;

    modifier isOedax() {
        require(
            msg.sender == oedax/*,
            "The address should be oedax contract"*/
        );
        _;
    }

    constructor(
        address _treasury
        )
        public
    {
        owner = msg.sender;
        oedax = address(0x0);
        treasury = _treasury;
    }

    function setOedax(
        address _oedax
        )
        public
    {
        require(
            oedax == address(0x0)/*,
            "Oedax could only be set once!"*/
        );
        require(msg.sender == owner);
        oedax = _oedax;
    }

    function createAuction(
        address     curve,
        uint        curveId,
        uint        initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint        initialBidAmount,         // The initial amount of tokenB from the creator's account.
        bytes  memory   bFeeS,
        bytes  memory   bTokenInfo,
        bytes  memory   bAuctionInfo,
        uint        id,
        address     creator
        )
        public
        isOedax
        returns (
            address /* auction */
        )
    {

        ImplAuction auction = new ImplAuction(
            oedax,
            treasury,
            curve,
            curveId,
            initialAskAmount,
            initialBidAmount,
            bytesToFeeSettings(bFeeS),
            bytesToTokenInfo(bTokenInfo),
            bytesToAuctionInfo(bAuctionInfo),
            id,
            creator
        );

        return address(auction);
    }
}