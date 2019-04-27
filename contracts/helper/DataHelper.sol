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

import "../iface/IAuctionData.sol";
import "../iface/ICurveData.sol";
import "./BytesToTypes.sol";

contract DataHelper is BytesToTypes, IAuctionData {

    function curveParamsToBytes(
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

    function auctionInfoToBytes(
        AuctionInfo memory auctionInfo
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

    function feeSettingsToBytes(
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

    function tokenInfoToBytes(
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

    function auctionStateToBytes(
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

    function auctionSettingsToBytes(
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

    function bytesToAuctionInfo(bytes memory b)
        internal
        pure
        returns (
            AuctionInfo memory auctionInfo
        )
    {
        require(b.length == 226, "invalid argument size");

        auctionInfo.P = bytesToUint256(32, b);
        auctionInfo.M = bytesToUint256(64, b);
        auctionInfo.S = bytesToUint256(96, b);
        auctionInfo.T = bytesToUint256(128, b);
        auctionInfo.delaySeconds = bytesToUint256(160, b);
        auctionInfo.maxAskAmountPerAddr = bytesToUint256(192, b);
        auctionInfo.maxBidAmountPerAddr = bytesToUint256(224, b);
        auctionInfo.isWithdrawalAllowed = bytesToBool(225, b);
        auctionInfo.isTakerFeeDisabled = bytesToBool(226, b);
    }

    function bytesToFeeSettings(bytes memory b)
        internal
        pure
        returns (
            FeeSettings memory feeSettings
        )
    {
        require(b.length == 180, "invalid argument size");

        feeSettings.recepient = bytesToAddress(20, b);
        feeSettings.creationFeeEth = bytesToUint256(52, b);
        feeSettings.protocolBips = bytesToUint256(84, b);
        feeSettings.walletBipts = bytesToUint256(116, b);
        feeSettings.takerBips = bytesToUint256(148, b);
        feeSettings.withdrawalPenaltyBips = bytesToUint256(180, b);
    }

    function bytesToTokenInfo(bytes memory b)
        internal
        pure
        returns (
            TokenInfo memory tokenInfo
        )
    {
        require(b.length == 136, "invalid argument size");

        tokenInfo.askToken = bytesToAddress(20, b);
        tokenInfo.bidToken = bytesToAddress(40, b);
        tokenInfo.askDecimals = bytesToUint256(72, b);
        tokenInfo.bidDecimals = bytesToUint256(104, b);
        tokenInfo.priceScale = bytesToUint256(136, b);
    }

    function bytesToAuctionState(bytes memory b)
        internal
        pure
        returns (
            AuctionState memory auctionState
        )
    {
        require(b.length == 384, "invalid argument size");

        auctionState.askPrice = bytesToUint256(32, b);
        auctionState.bidPrice = bytesToUint256(64, b);
        auctionState.actualPrice = bytesToUint256(96, b);
        auctionState.totalAskAmount = bytesToUint256(128, b);
        auctionState.totalBidAmount = bytesToUint256(160, b);
        auctionState.estimatedTTLSeconds = bytesToUint256(192, b);
        auctionState.queuedAskAmount = bytesToUint256(224, b);
        auctionState.queuedBidAmount = bytesToUint256(256, b);
        auctionState.askDepositLimit = bytesToUint256(288, b);
        auctionState.bidDepositLimit = bytesToUint256(320, b);
        auctionState.askWithdrawalLimit = bytesToUint256(352, b);
        auctionState.bidWithdrawalLimit = bytesToUint256(384, b);
    }

    function bytesToAuctionSettings(bytes memory b)
        internal
        pure
        returns (
            AuctionSettings memory auctionSettings
        )
    {
        require(b.length == 116, "invalid argument size");

        auctionSettings.creator = bytesToAddress(20, b);
        auctionSettings.auctionId = bytesToUint256(52, b);
        auctionSettings.curveId = bytesToUint256(84, b);
        auctionSettings.startedTimestamp = bytesToUint256(116, b);
    }

    function bytesToCurveParams(bytes memory b)
        internal
        pure
        returns (
            ICurveData.CurveParams memory curveParams
        )
    {
        require(b.length == 360, "invalid argument size");

        curveParams.askToken = bytesToAddress(20, b);
        curveParams.bidToken = bytesToAddress(40, b);
        curveParams.T = bytesToUint256(72, b);
        curveParams.P = bytesToUint256(104, b);
        curveParams.priceScale = bytesToUint256(136, b);
        curveParams.M = bytesToUint256(168, b);
        curveParams.S = bytesToUint256(200, b);
        curveParams.a = bytesToUint256(232, b);
        curveParams.b = bytesToUint256(264, b);
        curveParams.c = bytesToUint256(296, b);
        curveParams.d = bytesToUint256(328, b);
        curveParams.curveName = bytes32(bytesToUint256(360, b));
    }
}