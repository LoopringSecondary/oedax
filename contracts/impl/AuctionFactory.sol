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

import "../helper/SerializationHelper.sol";

import "../iface/IAuctionFactory.sol";

import "../impl/Auction.sol";

contract AuctionFactory {

    using SerializationHelper for bytes;

    address public oedax;
    address public treasury;

    modifier onlyOedax() {
        require(msg.sender == oedax, "unauthorized");
        _;
    }

    constructor(
        address _treasury,
        address _oedax
        )
        public
    {
        require(_oedax != address(0x0), "zero address");
        require(_treasury != address(0x0), "zero address");

        oedax = _oedax;
        treasury = _treasury;
    }

    function createAuction(
        address         curve,
        uint            curveId,
        uint            initialAskAmount,   // The initial amount of tokenA from the creator's account.
        uint            initialBidAmount,   // The initial amount of tokenB from the creator's account.
        bytes  memory   feeSettingsBytes,
        bytes  memory   tokenInfoBytes,
        bytes  memory   auctionInfoBytes,
        uint            id,
        address         creator
        )
        public
        onlyOedax
        returns (address)
    {

        Auction auction = new Auction(
            oedax,
            treasury,
            curve,
            curveId,
            initialAskAmount,
            initialBidAmount,
            feeSettingsBytes.toFeeSettings(),
            tokenInfoBytes.toTokenInfo(),
            auctionInfoBytes.toAuctionInfo(),
            id,
            creator
        );

        return address(auction);
    }
}