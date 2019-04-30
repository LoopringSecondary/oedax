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

import "../iface/IAuctionData.sol";
import "../iface/ICurveData.sol";

import "./BytesHelper.sol";

library SerializationHelper {

    using BytesHelper for bytes;

    function toBytes(
        ICurveData.CurveParams memory curveParams
        )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            curveParams.askToken,
            curveParams.bidToken,
            curveParams.T,
            curveParams.P,
            curveParams.priceScale,
            curveParams.M,
            curveParams.S,
            curveParams.a,
            curveParams.b,
            curveParams.c,
            curveParams.d,
            curveParams.curveName
        );
    }

    function toBytes(
        IAuctionData.AuctionInfo memory auctionInfo
        )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            auctionInfo.P,
            auctionInfo.M,
            auctionInfo.S,
            auctionInfo.T,
            auctionInfo.delaySeconds,
            auctionInfo.maxAskAmountPerAddr,
            auctionInfo.maxBidAmountPerAddr,
            auctionInfo.isWithdrawalAllowed,
            auctionInfo.isTakerFeeDisabled
        );
    }

    function toBytes(
        IAuctionData.FeeSettings memory feeSettings
        )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            feeSettings.recepient,
            feeSettings.creationFeeEth,
            feeSettings.protocolBips,
            feeSettings.walletBipts,
            feeSettings.takerBips,
            feeSettings.withdrawalPenaltyBips
        );
    }

    function toBytes(
        IAuctionData.TokenInfo memory tokenInfo
        )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            tokenInfo.askToken,
            tokenInfo.bidToken,
            tokenInfo.askDecimals,
            tokenInfo.bidDecimals,
            tokenInfo.priceScale
        );
    }

    function toBytes(
        IAuctionData.AuctionState memory auctionState
        )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            auctionState.askPrice,
            auctionState.bidPrice,
            auctionState.actualPrice,
            auctionState.totalAskAmount,
            auctionState.totalBidAmount,
            auctionState.estimatedTTLSeconds,
            auctionState.queuedAskAmount,
            auctionState.queuedBidAmount,
            auctionState.askDepositLimit,
            auctionState.bidDepositLimit,
            auctionState.askWithdrawalLimit,
            auctionState.bidWithdrawalLimit
        );
    }

    function toBytes(
        IAuctionData.AuctionSettings memory auctionSettings
        )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            auctionSettings.creator,
            auctionSettings.auctionId,
            auctionSettings.curveId,
            auctionSettings.startedTimestamp
        );
    }

    function toAuctionInfo(bytes memory b)
        internal
        pure
        returns (
            IAuctionData.AuctionInfo memory auctionInfo
        )
    {
        require(b.length == 226, "invalid argument size");

        auctionInfo.P = b.getUint256(32);
        auctionInfo.M = b.getUint256(64);
        auctionInfo.S = b.getUint256(96);
        auctionInfo.T = b.getUint256(128);
        auctionInfo.delaySeconds = b.getUint256(160);
        auctionInfo.maxAskAmountPerAddr = b.getUint256(192);
        auctionInfo.maxBidAmountPerAddr = b.getUint256(224);
        auctionInfo.isWithdrawalAllowed = b.getBool(225);
        auctionInfo.isTakerFeeDisabled = b.getBool(226);
    }

    function toFeeSettings(bytes memory b)
        internal
        pure
        returns (
            IAuctionData.FeeSettings memory feeSettings
        )
    {
        require(b.length == 180, "invalid argument size");

        feeSettings.recepient = b.getAddress(20);
        feeSettings.creationFeeEth = b.getUint256(52);
        feeSettings.protocolBips = b.getUint256(84);
        feeSettings.walletBipts = b.getUint256(116);
        feeSettings.takerBips = b.getUint256(148);
        feeSettings.withdrawalPenaltyBips = b.getUint256(180);
    }

    function toTokenInfo(bytes memory b)
        internal
        pure
        returns (
            IAuctionData.TokenInfo memory tokenInfo
        )
    {
        require(b.length == 136, "invalid argument size");

        tokenInfo.askToken = b.getAddress(20);
        tokenInfo.bidToken = b.getAddress(40);
        tokenInfo.askDecimals = b.getUint256(72);
        tokenInfo.bidDecimals = b.getUint256(104);
        tokenInfo.priceScale = b.getUint256(136);
    }

    function toAuctionState(bytes memory b)
        internal
        pure
        returns (
            IAuctionData.AuctionState memory auctionState
        )
    {
        require(b.length == 384, "invalid argument size");

        auctionState.askPrice = b.getUint256(32);
        auctionState.bidPrice = b.getUint256(64);
        auctionState.actualPrice = b.getUint256(96);
        auctionState.totalAskAmount = b.getUint256(128);
        auctionState.totalBidAmount = b.getUint256(160);
        auctionState.estimatedTTLSeconds = b.getUint256(192);
        auctionState.queuedAskAmount = b.getUint256(224);
        auctionState.queuedBidAmount = b.getUint256(256);
        auctionState.askDepositLimit = b.getUint256(288);
        auctionState.bidDepositLimit = b.getUint256(320);
        auctionState.askWithdrawalLimit = b.getUint256(352);
        auctionState.bidWithdrawalLimit = b.getUint256(384);
    }

    function toAuctionSettings(bytes memory b)
        internal
        pure
        returns (
            IAuctionData.AuctionSettings memory auctionSettings
        )
    {
        require(b.length == 116, "invalid argument size");
        auctionSettings.creator = b.getAddress(20);
        auctionSettings.auctionId = b.getUint256(52);
        auctionSettings.curveId = b.getUint256(84);
        auctionSettings.startedTimestamp = b.getUint256(116);
    }

    function toCurveParams(bytes memory b)
        internal
        pure
        returns (
            ICurveData.CurveParams memory curveParams
        )
    {
        require(b.length == 360, "invalid argument size");

        curveParams.askToken = b.getAddress(20);
        curveParams.bidToken = b.getAddress(40);
        curveParams.T = b.getUint256(72);
        curveParams.P = b.getUint256(104);
        curveParams.priceScale = b.getUint256(136);
        curveParams.M = b.getUint256(168);
        curveParams.S = b.getUint256(200);
        curveParams.a = b.getUint256(232);
        curveParams.b = b.getUint256(264);
        curveParams.c = b.getUint256(296);
        curveParams.d = b.getUint256(328);
        curveParams.curveName = bytes32(b.getUint256(360));
    }
}