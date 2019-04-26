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

import "./IAuctionData.sol";
import "./IAuctionEvents.sol";
import "./IOedaxEvents.sol";

contract IOedax is IAuctionData{

    function receiveEvents(
        uint status
    )
        external;

    // Initiate an auction
    function createAuction(
        uint    curveId,
        address askToken,
        address bidToken,
        uint    initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint    initialBidAmount,         // The initial amount of tokenB from the creator's account.
        AuctionInfo    memory  info
    )
        public
        returns (
            address /* auction */,
            uint    /* id */
        );

    // 获取用户创建的所有合约
    function getAuctionsAll(
        address creator
    )
        public
        view
        returns (
            uint /*  count */,
            uint[] memory /* auction index */
        );

    // 获取合约信息
    function getAuctionInfo(uint id)
        external
        view
        returns (
            uint,
            AuctionSettings memory,
            AuctionState    memory
        );

    function getAuctions(
        address creator,
        Status status
    )
        external
        view
        returns (
            uint /*  count */,
            uint[] memory /* auction index */
        );

    function getAuctions(
        uint    skip,
        uint    count,
        address creator,
        Status  status
    )
        external
        view
        returns (
            uint[] memory /* auction index */
        );

    // /@dev clone an auction from existing auction using its id
    function cloneAuction(
        uint auctionID,
        uint delaySeconds,
        uint initialAskAmount,
        uint initialBidAmount
        )
        public
        returns (
            address /* auction */,
            uint    /* id */,
            bool    /* successful */
        );

    // /@dev clone an auction using its address
    function cloneAuction(
        address auctionAddr,
        uint    delaySeconds,
        uint    initialAskAmount,
        uint    initialBidAmount
        )
        public
        returns (
            address /* auction */,
            uint    /* id */,
            bool    /* successful */
        );

    // All fee settings will only apply to future auctions, but not exxisting auctions.
    // One basis point is equivalent to 0.01%.
    // We suggest the followign values:
    // creationFeeEth           = 0 ETH
    // protocolBips             = 5   (0.05%)
    // walletBips               = 5   (0.05%)
    // takerBips                = 25  (0.25%)
    // withdrawalPenaltyBips    = 250 (2.50%)
    // The earliest maker will earn 25-5-5=15 bips (0.15%) rebate, the latest taker will pay
    // 25+5+5=35 bips (0.35) fee. All user combinedly pay 5+5=10 bips (0.1%) fee out of their
    // purchased tokens.
    function setFeeSettings(
        address recepient,
        uint    creationFeeEth,     // the required Ether fee from auction creators. We may need to
                                    // increase this if there are too many small auctions.
        uint    protocolBips,       // the fee paid to Oedax protocol
        uint    walletBipts,        // the fee paid to wallet or tools that help create the deposit
                                    // transactions, note that withdrawal doen't imply a fee.
        uint    takerBips,          // the max bips takers pays makers.
        uint    withdrawalPenaltyBips  // the percentage of withdrawal amount to pay the protocol.
                                       // Note that wallet and makers won't get part of the penalty.
    )
        external;

    function getFeeSettings(
    )
        external
        view
        returns (
            address recepient,
            uint    creationFeeEth,
            uint    protocolBips,
            uint    walletBipts,
            uint    takerBips,
            uint    withdrawalPenaltyBips
        );

    // 目前采用曲线合约中存储参数的形式，曲线可以命名
    // 无需单独生成合约
    // register a curve sub-contract.
    // The first curve should have id 1, not 0.
    function registerCurve(
        address ICurve
    )
        external
        returns (
            uint /* curveId */
        );

    // unregister a curve sub-contract
    function unregisterCurve(
        uint curveId
    )
        external
        returns (
            address /* curve */
        );

    function getCurves(
        )
        external
        view
        returns (
            address[] memory /* curves */
        );
}
