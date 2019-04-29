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

import "../lib/Ownable.sol";
import "../lib/ERC20.sol";
import "../lib/MathUint.sol";
import "../helper/DataHelper.sol";
import "../iface/IOedax.sol";
import "../iface/ITreasury.sol";
import "../iface/IAuctionFactory.sol";
import "../iface/IAuction.sol";
import "../iface/ICurveData.sol";


// REVIEW? why define another contract called ICurve?
interface ICurve {
    function getCurveBytes(uint cid)
        external
        view
        returns (bytes memory);

    function cloneCurve(
        uint cid,
        uint T,
        uint P
        )
        external
        returns (uint curveId);
}

// TODO(dong): remove IAuctionEvents
contract Oedax is IOedax, Ownable {

    using MathUint   for uint;
    using DataHelper for bytes;
    using DataHelper for IAuctionData.AuctionInfo;
    using DataHelper for IAuctionData.AuctionState;
    using DataHelper for IAuctionData.FeeSettings;
    using DataHelper for IAuctionData.TokenInfo;

    ITreasury       public treasury;
    ICurve          public curve;
    FeeSettings     public feeSettings;
    IAuctionFactory public auctionFactory;

    // All fee settings will only apply to future auctions, not existing auctions.
    //
    // We suggest the followign values:
    // creationFeeEth           = 0 ETH
    // protocolBips             = 5   (0.05%) - 1 basis point is equivalent to 0.01%.
    // walletBips               = 5   (0.05%)
    // takerBips                = 25  (0.25%)
    // withdrawalPenaltyBips    = 250 (2.50%)
    //
    // The earliest maker will earn 25-5-5=15 bips (0.15%) rebate, the latest taker will pay
    // 25+5+5=35 bips (0.35) fee. All user combinedly pay 5+5=10 bips (0.1%) fee out of their
    // purchased tokens (tokenB).
    constructor(
        address _treasury,
        address _curve,
        address _auctionFactory,
        address _recepient
        )
        public
    {
        treasury = ITreasury(_treasury);
        curve = ICurve(_curve);
        auctionFactory = IAuctionFactory(_auctionFactory);
        feeSettings.recepient = _recepient;

        feeSettings.creationFeeEth = 0;
        feeSettings.protocolBips = 5;
        feeSettings.walletBipts = 5;
        feeSettings.takerBips = 25;
        feeSettings.withdrawalPenaltyBips = 250;

        emit FeeSettingsUpdated (
            feeSettings.recepient,
            feeSettings.creationFeeEth,
            feeSettings.protocolBips,
            feeSettings.walletBipts,
            feeSettings.takerBips,
            feeSettings.withdrawalPenaltyBips,
            block.timestamp
        );
    }

    // REVIEW？ 这个方法也应该是Internal的
    function emitEvent(
        uint events
        )
        external
    {
        emitEvent(events, msg.sender);
    }

    // REVIEW? 所有public和external method都应该放到文件最前面（排序最好和接口定义一致）；
    // 所有内部的internal方法都应该放到文件最后。这个规则对其它所有文件也适应！！！

    function emitEvent(
        uint events,
        address auctionAddr
        )
        internal
    {
        require(
            treasury.auctionAddressMap(auctionAddr) != 0,
            "auction does not exist"
        );

        AuctionSettings memory auctionSettings = IAuction(auctionAddr)
            .getAuctionSettingsBytes()
            .bytesToAuctionSettings();

        AuctionInfo memory auctionInfo = IAuction(auctionAddr)
            .getAuctionBytes()
            .bytesToAuctionInfo();

        AuctionState memory auctionState = IAuction(auctionAddr)
            .getAuctionStateBytes()
            .bytesToAuctionState();

        TokenInfo memory tokenInfo = IAuction(auctionAddr)
            .getTokenInfoBytes()
            .bytesToTokenInfo();

        if (events == 1) {
            emit AuctionCreated(
                auctionSettings.creator,
                auctionSettings.auctionId,
                msg.sender,
                auctionInfo.delaySeconds,
                auctionInfo.P,
                tokenInfo.priceScale,
                auctionInfo.M,
                auctionInfo.S,
                auctionInfo.T,
                auctionInfo.isWithdrawalAllowed
            );
        }

        if (events == 2) {
            emit AuctionOpened (
                auctionSettings.auctionId,
                msg.sender,
                block.timestamp
            );
        }

        if (events == 3) {
            emit AuctionConstrained(
                auctionSettings.auctionId,
                msg.sender,
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp
            );
        }

        if (events == 4) {
            emit AuctionClosed(
                auctionSettings.auctionId,
                msg.sender,
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp,
                true
            );
        }

        if (events == 5) {
            emit AuctionSettled (
                auctionSettings.auctionId,
                msg.sender,
                block.timestamp
            );
        }
    }

    // REVIEW: 所有public/external方法都应该对应于接口里面的定义，这个方法接口里面就没定义。
    // 这个规则也适用于其他所有文件。
    function setAuctionFactory(
        address addr
        )
        external
        onlyOwner
    {
        require(addr != address(0x0), "zero address");
        auctionFactory = IAuctionFactory(addr);
    }

    // Initiate an auction
    function createAuction(
        uint        curveId,
        uint        initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint        initialBidAmount,         // The initial amount of tokenB from the creator's account.
        FeeSettings memory feeS,
        TokenInfo   memory tokenInfo,
        AuctionInfo memory auctionInfo
        )
        internal
        returns (
            address auctionAddr,
            uint    auctionId
        )
    {
        auctionId = treasury.getNextAuctionId();
        auctionAddr = auctionFactory.createAuction(
            address(curve),
            curveId,
            initialAskAmount,
            initialBidAmount,
            feeS.feeSettingsToBytes(),
            tokenInfo.tokenInfoToBytes(),
            auctionInfo.auctionInfoToBytes(),
            auctionId,
            msg.sender
        );

        treasury.registerAuction(auctionAddr, msg.sender);

        // REVIEW? 这个合约里面，只需要emit AuctionCreated事件，其它Auction事件放到IAuction里面。
        // 因此可以极大简化这个方法。
        emitEvent(1, auctionAddr);

        if (initialAskAmount > 0) {
            treasury.initDeposit(
                msg.sender,
                auctionAddr,
                tokenInfo.askToken,
                initialAskAmount
            );
        }

        if (initialBidAmount > 0) {
            treasury.initDeposit(
                msg.sender,
                auctionAddr,
                tokenInfo.bidToken,
                initialBidAmount
            );
        }
    }

    function checkTokenInfo(
        uint    curveId,
        address askToken,
        address bidToken,
        AuctionInfo    memory  info
        )
        internal
        view
        returns (
            TokenInfo memory _tokenInfo
        )
    {
        uint askDecimals = ERC20(askToken).decimals();
        uint bidDecimals = ERC20(bidToken).decimals();
        uint priceScale;

        // REVIEW? 这个地方绝对需要商榷...
        require(
            askDecimals <= bidDecimals && askDecimals + 18 > bidDecimals,
            "decimals not correct"
        );

        priceScale = MathUint.pow(10, 18 + askDecimals - bidDecimals);

        ICurveData.CurveParams memory cp;

        cp = curve.getCurveBytes(curveId).bytesToCurveParams();

        require(
            cp.T == info.T &&
            cp.M == info.M &&
            cp.P == info.P &&
            cp.S == info.S &&
            cp.priceScale == priceScale,
            "curve does not match the auction parameters"
        );

        _tokenInfo = TokenInfo(
            askToken,
            bidToken,
            askDecimals,
            bidDecimals,
            priceScale
        );
    }

    // Initiate an auction
    function createAuction(
        uint    curveId,
        address askToken,
        address bidToken,
        uint    initialAskAmount,
        uint    initialBidAmount,
        AuctionInfo    memory  info
        )
        public
        returns (
            address auctionAddr,
            uint    auctionId
        )
    {
        TokenInfo memory tokenInfo = checkTokenInfo(
            curveId,
            askToken,
            bidToken,
            info
        );

        (auctionAddr, auctionId) = createAuction(
            curveId,
            initialAskAmount,         // The initial amount of tokenA from the creator's account.
            initialBidAmount,         // The initial amount of tokenB from the creator's account.
            feeSettings,
            tokenInfo,
            info
        );
    }

    function getAuction(uint id)
        external
        view
        returns (
            uint lastSynTime,
            AuctionSettings memory auctionSettings,
            AuctionState    memory auctionState
        )
    {
        address auctionAddr = treasury.auctionIdMap(id);
        lastSynTime = IAuction(auctionAddr).lastSynTime();

        auctionSettings = IAuction(auctionAddr)
            .getAuctionSettingsBytes()
            .bytesToAuctionSettings();

        auctionState = IAuction(auctionAddr)
            .getAuctionStateBytes()
            .bytesToAuctionState();
    }

    function getAuctions(
        address creator
        )
        public
        view
        returns (
            uint[] memory
        )
    {
        return treasury.getAuctions(creator);
    }

    function getAuctions(
        address creator,
        Status  status
        )
        external
        view
        returns (
            uint[] memory auctionIds
        )
    {
        uint[] memory auctions = getAuctions(creator);
        address auctionAddr;
        uint count;
        for (uint i = 0; i < auctions.length; i++) {
            auctionAddr = treasury.auctionIdMap(auctions[i]);
            if (IAuction(auctionAddr).status() == status) {
                auctionIds[count++] = auctionIds[i];
            }
        }
    }

    function getAuctions(
        uint    skip,
        uint    count,
        address creator,
        Status  status
        )
        external
        view
        returns (
            uint[] memory auctionIds
        )
    {
        // REVIEW? 这个代码可以极大简化，参考上面的getAuctions方法的实现。无需循环两次。
        uint[] memory auctionIds = getAuctions(creator);
        uint len = auctionIds.length;

        address auctionAddr;
        uint cnt = 0;

        for (uint i = 0; i < len; i++) {
            auctionAddr = treasury.auctionIdMap(auctionIds[i]);
            if (
                auctionIds[i] > skip &&
                auctionIds[i] <= skip.add(count) &&
                IAuction(auctionAddr).status() == status
            )
            {
                cnt++;
            }
        }

        if (cnt>0) {
            cnt = 0;
            for (uint i = 0; i < len; i++) {
                auctionAddr = treasury.auctionIdMap(auctionIds[i]);
                if (
                    auctionIds[i] > skip &&
                    auctionIds[i] <= skip.add(count) &&
                    IAuction(auctionAddr).status() == status
                ) {
                    auctionIds[cnt] = auctionIds[i];
                    cnt++;
                }
            }
        }
    }

    /// @dev clone an auction from existing auction using its id
    function cloneAuction(
        uint auctionId,
        uint delaySeconds,
        uint initialAskAmount,
        uint initialBidAmount
        )
        public
        returns (
            address,
            uint
        )
    {
        address auctionAddr = treasury.auctionIdMap(auctionId);

        require(
            auctionAddr != address(0x0),
            "auction not correct"
        );

        return cloneAuction(
            auctionAddr,
            delaySeconds,
            initialAskAmount,
            initialBidAmount
        );
    }

    // /@dev clone an auction using its address
    function cloneAuction(
        address auctionAddr,
        uint    delaySeconds,
        uint    initialAskAmount,
        uint    initialBidAmount
        )
        public
        returns (
            address newAuctionAddr,
            uint    newAuctionId
        )
    {
        require(
            block.timestamp - IAuction(auctionAddr).lastSynTime() <= 7 days,
            "auction should be closed less than 7 days ago"
        );
        require(
            IAuction(auctionAddr).status() >= Status.CLOSED,
            "only closed auction can be cloned"
        );

        AuctionSettings memory auctionSettings = IAuction(auctionAddr)
            .getAuctionSettingsBytes()
            .bytesToAuctionSettings();

        AuctionInfo memory auctionInfo = IAuction(auctionAddr)
            .getAuctionBytes()
            .bytesToAuctionInfo();

        TokenInfo memory tokenInfo = IAuction(auctionAddr)
            .getTokenInfoBytes()
            .bytesToTokenInfo();

        FeeSettings memory _feeSettings = IAuction(auctionAddr)
            .getFeeSettingsBytes()
            .bytesToFeeSettings();


        auctionSettings.startedTimestamp = block.timestamp;
        auctionInfo.delaySeconds = delaySeconds;
        auctionInfo.P = IAuction(auctionAddr).getActualPrice();

        uint cid = ICurve(curve).cloneCurve(
            auctionSettings.curveId,
            auctionInfo.T,
            auctionInfo.P
        );

        (newAuctionAddr, newAuctionId) = createAuction(
            cid,
            initialAskAmount,         // The initial amount of tokenA from the creator's account.
            initialBidAmount,         // The initial amount of tokenB from the creator's account.
            _feeSettings,
            tokenInfo,
            auctionInfo
        );
    }

    // All fee settings will only apply to future auctions, not existing auctions.
    //
    // We suggest the followign values:
    // creationFeeEth           = 0 ETH
    // protocolBips             = 5   (0.05%) - 1 basis point is equivalent to 0.01%.
    // walletBips               = 5   (0.05%)
    // takerBips                = 25  (0.25%)
    // withdrawalPenaltyBips    = 250 (2.50%)
    //
    // The earliest maker will earn 25-5-5=15 bips (0.15%) rebate, the latest taker will pay
    // 25+5+5=35 bips (0.35) fee. All user combinedly pay 5+5=10 bips (0.1%) fee out of their
    // purchased tokens (tokenB).
    function setFeeSettings(
        address recepient,
        uint    creationFeeEth,         // the required Ether fee from auction creators. We may need to
                                        // increase this if there are too many small auctions.
        uint    protocolBips,           // the fee paid to Oedax protocol
        uint    walletBipts,            // the fee paid to wallet or tools that help create the deposit
                                        // transactions, note that withdrawal doen't imply a fee.
        uint    takerBips,              // the max bips takers pays makers.
        uint    withdrawalPenaltyBips   // the percentage of withdrawal amount to pay the protocol.
                                        // Note that wallet and makers won't get part of the penalty.
        )
        external
        onlyOwner
    {
        require(
            feeSettings.protocolBips +
            feeSettings.walletBipts +
            feeSettings.takerBips < 10000,
            "invalid bips value"
        );

        require(
            withdrawalPenaltyBips < 10000,
            "invalid bips value"
        );

        feeSettings.recepient = recepient;
        feeSettings.creationFeeEth = creationFeeEth;
        feeSettings.protocolBips = protocolBips;
        feeSettings.walletBipts = walletBipts;
        feeSettings.takerBips = takerBips;
        feeSettings.withdrawalPenaltyBips = withdrawalPenaltyBips;

        emit FeeSettingsUpdated (
            recepient,
            creationFeeEth,
            protocolBips,
            walletBipts,
            takerBips,
            withdrawalPenaltyBips,
            block.timestamp
        );
    }

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
        )
    {
        recepient = feeSettings.recepient;
        creationFeeEth = feeSettings.creationFeeEth;
        protocolBips = feeSettings.protocolBips;
        walletBipts = feeSettings.walletBipts;
        takerBips = feeSettings.takerBips;
        withdrawalPenaltyBips = feeSettings.withdrawalPenaltyBips;
    }

    // no need to used the following functions
    // if all curves are stored in a contract
    // register a curve sub-contract.
    // The first curve should have id 1, not 0.
    function registerCurve(
        address ICurve
        )
        external
        returns (
            uint /* curveId */
        )
    {
        revert();  // REVIEW? if we do not support these methods, please delete them
    }

    // unregister a curve sub-contract
    function unregisterCurve(
        uint curveId
        )
        external
        returns (
            address /* curve */
        )
    {
        revert();  // REVIEW? if we do not support these methods, please delete them
    }

    function getCurves(
        )
        external
        view
        returns (
            address[] memory /* curves */
        )
    {
        revert();  // REVIEW? if we do not support these methods, please delete them
    }
}