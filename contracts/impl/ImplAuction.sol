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

import "../iface/IAuction.sol";
import "../lib/MathLib.sol";
import "../helper/DataHelper.sol";

interface IOedax {
    function logEvents(uint status)
        external;
}

contract IAuctionEvents {

    // REVIEW? 下面这些event哪些field是需要index的？
    event AuctionCreated(
        address         creator,
        uint256         aucitionId,
        uint256         createTime
    );

    event AuctionOpened (
        uint256         openTime
    );

    event AuctionConstrained(
        uint256         totalAskAmount,
        uint256         totalBidAmount,
        uint256         priceScale,
        uint256         actualPrice,
        uint256         constrainedTime
    );

    event AuctionClosed(
        uint256         totalAskAmount,
        uint256         totalBidAmount,
        uint256         priceScale,
        uint256         closePrice,
        uint256         closeTime,
        bool            canSettle
    );

    event AuctionSettled (
        uint256         settleTime
    );
}

contract ICurve {
    function calcEstimatedTTL(
        uint cid,
        uint t1,
        uint t2
        )
        public
        view
        returns (
            uint /* ttlSeconds */
        );

    function calcAskPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint);

    function calcInvAskPrice(
        uint cid,
        uint p
        )
        public
        view
        returns (
            bool,
            uint
        );

    function calcBidPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint);

    function calcInvBidPrice(
        uint cid,
        uint p
        )
        public
        view
        returns (
            bool,
            uint
        );
}

interface ITreasury {

    function auctionDeposit(
        address user,
        address token,
        uint    amount
        )
        external
        returns (bool);

    function auctionWithdraw(
        address user,
        address token,
        uint    amount
        )
        external
        returns (bool);

    function sendFee(
        address recepient,
        address user,
        address token,
        uint    amount
        )
        external
        returns (bool);

    function exchangeTokens(
        address recepient,
        address user,
        address tokenA,
        address tokenB,
        uint    amountA,
        uint    amountB
        )
        external
        returns (bool);

    function sendFeeAll(
        address recepient,
        address token,
        uint    amount
        )
        external
        returns (bool);
}

contract ImplAuction is IAuction, MathLib, DataHelper, IAuctionEvents, IParticipationEvents {

    mapping(address => uint[]) private participationIndex;  // user address => index of Participation[]

    uint private askPausedTime;//time on askCurve = block.timestamp-contrainedTime-askPausedTime
    uint private bidPausedTime;//time on bidCurve = block.timestamp-contrainedTime-bidPausedTime

    IOedax      public oedax;
    ITreasury   public treasury;
    address     public curve;

    modifier onlyOedax() {
        require(msg.sender == address(oedax), "unauthorized");
        _;
    }

    constructor(
        address _oedax,
        address _treasury,
        address _curve,
        uint    _curveId,
        uint    initialAskAmount,
        uint    initialBidAmount,

        FeeSettings memory _feeSettings,
        TokenInfo   memory _tokenInfo,
        AuctionInfo memory _auctionInfo,

        uint    id,
        address creator
        )
        public
    {

        oedax = IOedax(_oedax);
        treasury = ITreasury(_treasury);
        curve = _curve;

        auctionSettings.creator = creator;
        auctionSettings.auctionId = id;
        auctionSettings.curveId = _curveId;
        auctionSettings.startedTimestamp = block.timestamp;

        auctionInfo = _auctionInfo;
        feeSettings = _feeSettings;
        tokenInfo = _tokenInfo;

        lastSynTime = block.timestamp;
        auctionState.askPrice = auctionInfo.P*auctionInfo.M;
        auctionState.bidPrice = auctionInfo.P/auctionInfo.M;

        status = Status.STARTED;
        //transfer complete in Oedax contract

        // REVIEW? += is dangourse, should use `add`
        if (initialAskAmount > 0) {
            askAmount[creator] += initialAskAmount;
            auctionState.totalAskAmount += initialAskAmount;
        }

        if (initialBidAmount > 0) {
            bidAmount[creator] += initialBidAmount;
            auctionState.totalBidAmount += initialBidAmount;
        }

        auctionState.estimatedTTLSeconds = _auctionInfo.T;

        if (initialBidAmount != 0) {
            auctionState.actualPrice = mul(tokenInfo.priceScale, initialAskAmount)/initialBidAmount;
        }

        /*
        emit AuctionCreated(
            creator,
            id,
            address(this),
            auctionInfo.delaySeconds,
            auctionInfo.P,
            tokenInfo.priceScale,
            auctionInfo.M,
            auctionInfo.S,
            auctionInfo.T,
            auctionInfo.isWithdrawalAllowed
        );
        */

        //oedax.logEvents(1);
        auctionEvents(1);

        if (auctionInfo.delaySeconds == 0) {
            status = Status.OPEN;

            /*
            emit AuctionOpened (
                creator,
                auctionSettings.auctionId,
                address(this),
                block.timestamp
            );
            */
            auctionEvents(2);
            // 此处event在oedax合约中完成
            //oedax.logEvents(2);

        }
    }

    function auctionEvents(uint status)
        internal
    {

        if (status == 1) {
            emit AuctionCreated(
                auctionSettings.creator,
                auctionSettings.auctionId,
                block.timestamp
            );
        }

        if (status == 2) {
            emit AuctionOpened (
                block.timestamp
            );
        }

        if (status == 3) {
            emit AuctionConstrained(
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp
            );
        }

        if (status == 4) {
            emit AuctionClosed(
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp,
                true
            );
        }

        if (status == 5) {
            emit AuctionSettled (
                block.timestamp
            );
        }
    }

    function newParticipation(
        address token,
        int     amount
        )
        internal
    {
        Participation memory P;
        P.index = participations.length;
        P.user = msg.sender;
        P.token = token;
        P.amount = amount;
        P.timestamp = block.timestamp;
        participations.push(P);
        participationIndex[msg.sender].push(P.index);
        if (!userParticipated[msg.sender]) {
            users.push(msg.sender);
            userParticipated[msg.sender] = true;
        }
    }

    function triggerEvent(
        uint action,
        uint amount
        )
        internal
    {
        bool isAsk;
        if (action%2 == 1) {
            isAsk = true;
        }

        if (action <= 2) {
            emit Deposited(
                msg.sender,
                isAsk,
                amount,
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                auctionState.queuedAskAmount,
                auctionState.queuedBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp
            );
        } else {
            emit Withdrawn(
                msg.sender,
                isAsk,
                amount,
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                auctionState.queuedAskAmount,
                auctionState.queuedBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp
            );
        }
    }

    function getLimitsWithoutQueue(
        uint _ask,
        uint _bid,
        uint askPrice,
        uint bidPrice
        )
        internal
        view
        returns (
            uint /* askDepositLimit */,
            uint /* bidDepositLimit */,
            uint /* askWithdrawalLimit */,
            uint /* bidWithdrawalLimit */
        )
    {
        require(
            _bid > 0/*,
            "bid amount should be larger than 0"*/
        );
        uint actualPrice = mul(_ask, tokenInfo.priceScale)/_bid;

        uint askDepositLimit;
        uint bidDepositLimit;
        uint askWithdrawLimit;
        uint bidWithdrawLimit;

        if (actualPrice >= bidPrice) {
            bidDepositLimit = mul((actualPrice - bidPrice), _bid)/bidPrice;
            if (bidDepositLimit > auctionInfo.maxBidAmountPerAddr) {
                bidDepositLimit = auctionInfo.maxBidAmountPerAddr;
            }

            askWithdrawLimit = mul((actualPrice - bidPrice), _bid)/tokenInfo.priceScale;
            if (askWithdrawLimit > auctionInfo.maxAskAmountPerAddr) {
                askWithdrawLimit = auctionInfo.maxAskAmountPerAddr;
            }
        } else {
            bidDepositLimit = 0;
            askWithdrawLimit = 0;
        }

        if (actualPrice <= askPrice) {
            askDepositLimit = mul((askPrice - actualPrice), _bid)/tokenInfo.priceScale;
            if (askDepositLimit > auctionInfo.maxAskAmountPerAddr) {
                askDepositLimit = auctionInfo.maxAskAmountPerAddr;
            }

            bidWithdrawLimit = mul((askPrice - actualPrice), _bid)/askPrice;
            if (bidWithdrawLimit > auctionInfo.maxBidAmountPerAddr) {
                bidWithdrawLimit = auctionInfo.maxBidAmountPerAddr;
            }
        } else {
            askDepositLimit = 0;
            bidWithdrawLimit = 0;
        }

        return(
            askDepositLimit,
            bidDepositLimit,
            askWithdrawLimit,
            bidWithdrawLimit
        );
    }

    function simulatePrice(uint dt)
        public
        view
        returns (
            uint /*askPrice*/,
            uint /*bidPrice*/,
            uint /*actualPrice*/,
            uint /*askPausedTime*/,
            uint /*bidPausedTime*/
        )
    {
        uint time = add(now, dt);
        require(
            time >= lastSynTime/*,
            "time should not be earlier than lastSynTime"*/
        );

        require(
            auctionState.actualPrice > 0/*,
            "actualPrice should not be 0"*/
        );

        if (time == lastSynTime) {
            return(
                auctionState.askPrice,
                auctionState.bidPrice,
                auctionState.actualPrice,
                askPausedTime,
                bidPausedTime
            );
        }

        uint askPrice;
        uint bidPrice;

        uint _askPausedTime = askPausedTime;
        uint _bidPausedTime = bidPausedTime;

        bool success;
        uint t1;
        uint t2;

        (success, t1) = ICurve(curve).calcInvAskPrice(auctionSettings.curveId, auctionState.actualPrice);
        // 曲线没有相交，askPrice按照时间变化
        if (!success ||
            t1 >= sub(time, constrainedTime + askPausedTime)
        ) {
            askPrice = calcAskPrice(sub(time, constrainedTime + askPausedTime));
        } else {
            // 曲线相交，askPrice设置为actualPrice
            askPrice = auctionState.actualPrice;
            _askPausedTime = sub(time, constrainedTime + t1);
        }

        (success, t2) = ICurve(curve).calcInvBidPrice(auctionSettings.curveId, auctionState.actualPrice);
        // 曲线没有相交，bidPrice按照时间变化
        if (!success ||
            t2 >= sub(now, constrainedTime + bidPausedTime)
        ) {
            bidPrice = calcBidPrice(sub(now, constrainedTime + bidPausedTime));
        } else {
            // 曲线相交，bidPrice设置为actualPrice
            bidPrice = auctionState.actualPrice;
            _bidPausedTime = sub(time, constrainedTime + t2);
        }

        return (askPrice, bidPrice, auctionState.actualPrice, _askPausedTime, _bidPausedTime);
    }

    function updatePrice()
        public
    {

        if (status == Status.STARTED&&
            block.timestamp >= auctionSettings.startedTimestamp + auctionInfo.delaySeconds
        ) {
            status = Status.OPEN;
            /*
            emit AuctionOpened (
                auctionSettings.creator,
                auctionSettings.auctionId,
                address(this),
                block.timestamp
            );
            */
            auctionEvents(2);
            oedax.logEvents(2);
        }

        if (status == Status.OPEN &&
            auctionState.actualPrice <= auctionInfo.P*auctionInfo.M &&
            auctionState.actualPrice >= auctionInfo.P/auctionInfo.M
        ) {
            status = Status.CONSTRAINED;
            constrainedTime = block.timestamp;
            auctionState.estimatedTTLSeconds = auctionInfo.T;
            /*
            emit AuctionConstrained(
                auctionSettings.creator,
                auctionSettings.auctionId,
                address(this),
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp
            );
            */
            auctionEvents(3);
            oedax.logEvents(3);
        }

        if (now == lastSynTime || status != Status.CONSTRAINED) {
            return;
        }

        (auctionState.askPrice, auctionState.bidPrice,  , askPausedTime, bidPausedTime) = simulatePrice(0);

        auctionState.estimatedTTLSeconds = getEstimatedTTL();
        lastSynTime = block.timestamp;

        if (auctionState.askPrice <= auctionState.bidPrice) {
            status = Status.CLOSED;
            /*
            emit AuctionClosed(
                auctionSettings.creator,
                auctionSettings.auctionId,
                address(this),
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                block.timestamp,
                true
            );
            */
            auctionEvents(4);
            oedax.logEvents(4);
        }
        updateLimits();
    }

    /// @dev Return the ask/bid deposit/withdrawal limits. Note that existing queued items should
    /// be considered in the calculations.
    function getLimits()
        public
        view
        returns (
            uint /* askDepositLimit */,
            uint /* bidDepositLimit */,
            uint /* askWithdrawalLimit */,
            uint /* bidWithdrawalLimit */
        )
    {

        if (status == Status.STARTED ||
            status >= Status.CLOSED
        ) {
            return (0,0,0,0);
        }

        if (status == Status.OPEN) {
            return (
                auctionInfo.maxAskAmountPerAddr,
                auctionInfo.maxBidAmountPerAddr,
                auctionInfo.maxAskAmountPerAddr,
                auctionInfo.maxBidAmountPerAddr
            );
        }

        require(
            auctionState.actualPrice > 0/*,
            "actualPrice should not be 0"*/
        );

        uint askPrice;
        uint bidPrice;

        (askPrice, bidPrice, ,  ,  ) = simulatePrice(0);

        uint ask = auctionState.totalAskAmount;
        uint bid = auctionState.totalBidAmount;

        uint askDepositLimit;
        uint bidDepositLimit;
        uint askWithdrawLimit;
        uint bidWithdrawLimit;

        (askDepositLimit, , ,bidWithdrawLimit) = getLimitsWithoutQueue(
            ask,
            bid + auctionState.queuedBidAmount,
            askPrice,
            bidPrice
        );

        ( ,bidDepositLimit, askWithdrawLimit, ) = getLimitsWithoutQueue(
            ask + auctionState.queuedAskAmount,
            bid,
            askPrice,
            bidPrice
        );

        return (
            askDepositLimit,
            bidDepositLimit,
            askWithdrawLimit,
            bidWithdrawLimit
        );
    }

    function getActualPrice()
        public
        view
        returns (uint)
    {
        uint price = auctionState.actualPrice;
        return price;
    }

    function calcActualTokens(address user)
        public
        view
        returns (
            uint,
            uint
        )
    {
        require(
            status >= Status.OPEN/*,
            "The auction is not open yet"*/
        );
        uint amountA = askAmount[user];
        uint amountB = bidAmount[user];
        if (totalTakerRateA > 0) {
            amountA = amountA - totalFeeBips() * amountA/10000 +
                auctionState.totalAskAmount * feeSettings.takerBips/10000 *
                takerRateA[user]/totalTakerRateA;

            //amountA += totalTakerAmountA*takerRateA[user]/totalTakerRateA;
        }
        if (totalTakerRateB > 0) {
            amountB = amountB - totalFeeBips() * amountB/10000 +
                auctionState.totalBidAmount * feeSettings.takerBips/10000 *
                takerRateB[user]/totalTakerRateB;
        }
        return (amountA, amountB);
    }

    function totalFeeBips()
        internal
        view
        returns (uint)
    {
        return feeSettings.creationFeeEth +
            feeSettings.protocolBips +
            feeSettings.takerBips;
    }

    function calcTakeRate()
        public
        view
        returns (uint rate)
    {
        if (status <= Status.OPEN) {
            return 100;
        }

        uint time = sub(now, constrainedTime);

        rate = time*100/auctionInfo.T;

        if (rate < 100) {
            rate = 100 - rate;
        } else {
            rate = 0;
        }
    }

    function getAuctionSettings()
        public
        view
        returns (
            AuctionSettings memory
        )
    {
        AuctionSettings memory aucSettings;
        aucSettings = auctionSettings;
        return aucSettings;
    }

    function getAuctionSettingsBytes()
        public
        view
        returns (bytes memory)
    {
        return auctionSettingsToBytes(getAuctionSettings());
    }

    function getAuctionStateBytes()
        public
        view
        returns (bytes memory)
    {
        return auctionStateToBytes(auctionState);
    }

    function getAuctionInfoBytes()
        public
        view
        returns (bytes memory)
    {
        return auctionInfoToBytes(auctionInfo);
    }

    function getTokenInfoBytes()
        public
        view
        returns (bytes memory)
    {
        return tokenInfoToBytes(tokenInfo);
    }

    function getFeeSettingsBytes()
        public
        view
        returns (bytes memory)
    {
        return feeSettingsToBytes(feeSettings);
    }

    function calcAskPrice(uint t)
        internal
        view
        returns (uint)
    {
        return ICurve(curve).calcAskPrice(auctionSettings.curveId, t);
    }

    function calcBidPrice(
        uint t
        )
        internal
        view
        returns (uint)
    {
        return ICurve(curve).calcBidPrice(auctionSettings.curveId, t);
    }

    /// @dev Return the estimated time to end
    function getEstimatedTTL()
        public
        view
        returns (uint)
    {
        uint period = auctionInfo.T;

        if (status <= Status.OPEN) {
            return period;
        }
        if (status > Status.CONSTRAINED) {
            return 0;
        }

        uint t1 = sub(now, constrainedTime + askPausedTime);
        uint t2 = sub(now, constrainedTime + bidPausedTime);

        return ICurve(curve).calcEstimatedTTL(auctionSettings.curveId, t1, t2);
    }

    function askDeposit(uint amount)
        public
        returns (uint)
    {
        return deposit(address(0x0), tokenInfo.askToken, amount);
    }

    function bidDeposit(uint amount)
        public
        returns (uint)
    {
        return deposit(address(0x0), tokenInfo.bidToken, amount);
    }
/*
    function askWithdraw(uint amount)
        public
        returns (
            uint
        )
    {
        return withdraw(tokenInfo.askToken, amount);
    }

    function bidWithdraw(uint amount)
        public
        returns (
            uint
        )
    {
        return withdraw(tokenInfo.bidToken, amount);
    }
*/

    /// @dev Make a deposit and returns the amount that has been successfully deposited into the
    /// auciton, the rest is put into the waiting list (queue).
    /// Set `wallet` to 0x0 will avoid paying wallet a fee. Note only deposit has fee.
    function deposit(
        address wallet,
        address token,
        uint    amount)
        public
        returns (uint /* amount */ )
    {
        require(
            token == tokenInfo.askToken ||
            token == tokenInfo.bidToken/*,
            "token not correct"*/
        );

        if (status == Status.STARTED&&
            block.timestamp >= auctionSettings.startedTimestamp + auctionInfo.delaySeconds
        ) {
            status = Status.OPEN;
            auctionEvents(2);
            oedax.logEvents(2);
        }

        require(
            status == Status.OPEN ||
            status == Status.CONSTRAINED/*,
            "deposit not allowed"*/
        );

        uint realAmount = amount;

        newParticipation(token, int(amount));

        if (status == Status.CONSTRAINED)
        {
            // 同步参数到now
            updatePrice();

            if (token == tokenInfo.askToken &&
                realAmount > auctionInfo.maxAskAmountPerAddr ||
                token == tokenInfo.bidToken &&
                realAmount > auctionInfo.maxBidAmountPerAddr
            )
            {
                return 0;
            }
        }

        // 从treasury提取token，手续费暂时不收取，在最后结算时收取
        // 无论放在队列中，或者交易中，都视作锁仓realAmount，其余部分交手续费
        treasury.auctionDeposit(
            msg.sender,
            token,
            amount  // must be greater than 0.
        );

        uint action;

        if (token == tokenInfo.askToken) {
            action = 1;
        }
        if (token == tokenInfo.bidToken) {
            action = 2;
        }

        // creationFeeEth       - 给creator，拍卖结束时整体分配
        // protocolBips         - 给recepient，拍卖结束时整体分配
        // walletBipts          - 給wallet或者recepient，拍卖中deposit时分配
        // takerBips            - 所有人共享，拍卖结束时参与者分配
        // withdrawalPenaltyBips- 给recepient, withdraw时分配

        uint fee;

        fee = amount*feeSettings.walletBipts/10000;

        if (wallet == address(0x0)) {
            treasury.sendFee(
                feeSettings.recepient,
                msg.sender,
                token,
                fee
            );
        } else {
            treasury.sendFee(
                wallet,
                msg.sender,
                token,
                fee
            );
        }

        recordTaker(
            msg.sender,
            token,
            amount-fee
        );

        updateAfterAction(action, amount - fee);

        return amount - fee;
    }

    function recordTaker(
        address user,
        address token,
        uint amount
        )
        internal
    {
        uint userTake = amount*calcTakeRate();
        if (token == tokenInfo.askToken) {
            takerRateA[user] += userTake;
            totalTakerRateA += userTake;
        }

        if (token == tokenInfo.bidToken) {
            takerRateB[user] += userTake;
            totalTakerRateB += userTake;
        }
    }

    // 不考虑waitinglist情况下的limit
    // action   1 - askDeposit 2 - bidDeposit 3 - askWithdraw 4 - bidWithdraw
    function getLimits(
        uint action
        )
        internal
        view
        returns (uint limit)
    {

        if (status == Status.STARTED ||
            status >= Status.CLOSED
        ) {
            return 0;
        }

        if (status == Status.OPEN) {
            if (action == 1 || action == 3) {
                return auctionInfo.maxAskAmountPerAddr;
            } else {
                return auctionInfo.maxBidAmountPerAddr;
            }
        }

        if (action == 1) {
            limit = mul(
                sub(auctionState.askPrice, auctionState.actualPrice),
                auctionState.totalBidAmount
                )/tokenInfo.priceScale;
        }

        if (action == 2) {
            limit = mul(
                sub(auctionState.actualPrice, auctionState.bidPrice),
                auctionState.totalBidAmount
                )/auctionState.bidPrice;
        }

        if (action == 3) {
            limit = mul(
                sub(auctionState.actualPrice, auctionState.bidPrice),
                auctionState.totalBidAmount
                )/tokenInfo.priceScale;
        }

        if (action == 4) {
            limit = mul(
                sub(auctionState.askPrice, auctionState.actualPrice),
                auctionState.totalBidAmount
                )/auctionState.askPrice;
        }
    }

    function tokenExchange(
        uint dir,
        uint amount
        )
        internal
        view
        returns (uint res)
    {
        res = amount;
        // input amountA, output amountB
        if (dir == 1) {
            res = mul(amount, tokenInfo.priceScale)/auctionState.actualPrice;
        }

        // input amountB, output amountA
        if (dir == 2) {
            res = mul(amount, auctionState.actualPrice)/tokenInfo.priceScale;
        }
    }

    // 仅处理等待队列里的记录，放入到ask/bidAmount中
    function releaseQueue(
        uint dir,
        uint amount
        )
        internal
    {
        require(
            dir == 1 && amount <= auctionState.queuedAskAmount ||
            dir == 2 && amount <= auctionState.queuedBidAmount/*,
            "amount not correct"*/
        );

        uint len;
        uint amountRes = amount;
        QueuedParticipation memory q;
        if (dir == 1) {
            len = askQueue.length;
            auctionState.totalAskAmount += amountRes;
            while(len > 0 && amountRes > 0) {
                q = askQueue[len - 1];
                if (amountRes >= q.amount) {
                    askAmount[q.user] += q.amount;
                    auctionState.queuedAskAmount -= q.amount;
                    amountRes -= q.amount;
                    askQueue[len - 1].amount = 0;
                }
                else {
                    askAmount[q.user] += amountRes;
                    auctionState.queuedAskAmount -= amountRes;
                    askQueue[len - 1].amount = q.amount - amountRes;
                    amountRes = 0;
                    break;
                }
                len--;
            }
            askQueue.length = len;
        }

        if (dir == 2) {
            len = bidQueue.length;
            auctionState.totalBidAmount += amountRes;
            while(len > 0 && amountRes > 0) {
                q = bidQueue[len - 1];
                if (amountRes >= q.amount) {
                    bidAmount[q.user] += q.amount;
                    auctionState.queuedBidAmount -= q.amount;
                    amountRes -= q.amount;
                    bidQueue[len - 1].amount = 0;
                }
                else {
                    bidAmount[q.user] += amountRes;
                    auctionState.queuedBidAmount -= amountRes;
                    bidQueue[len - 1].amount = q.amount - amountRes;
                    amountRes = 0;
                    break;
                }
                len--;
            }
            bidQueue.length = len;
        }
    }

    // deposit - 1. 加队列 2. 反向减队列
    // withdraw - 1. 减队列 2. 反向减队列
    // action   1 - askDeposit 2 - bidDeposit 3 - askWithdraw 4 - bidWithdraw
    // 合约内部调用，已保证只影响队列，不会改变价格
    function updateQueue(
        uint action,
        uint amount
        )
        internal
    {
        // TODO: Update the queue, put the amount into the pool

        uint askQ = tokenExchange(2, auctionState.queuedBidAmount);
        uint bidQ = tokenExchange(1, auctionState.queuedAskAmount);

        QueuedParticipation memory q;

        uint amountQ = amount;

        // 1 - askDeposit
        if (action == 1) {
            // 首先抵消Bid，然后追加Ask
            if (amountQ >= askQ) {
                releaseQueue(2, auctionState.queuedBidAmount);
                askAmount[msg.sender] += askQ;
                auctionState.totalAskAmount += askQ;
                amountQ -= askQ;
            } else {
                releaseQueue(2, tokenExchange(1, amountQ));
                askAmount[msg.sender] += amountQ;
                auctionState.totalAskAmount += amountQ;
                amountQ = 0;
            }

            // 还有多的放入等待序列
            if (amountQ > 0) {
                auctionState.queuedAskAmount += amountQ;
                q.user = msg.sender;
                q.amount = amountQ;
                q.timestamp = block.timestamp;
                askQueue.push(q);
            }

        }

        // 2 - bidDeposit
        if (action == 2) {
            // 首先抵消Ask，然后追加Bid
            if (amountQ >= bidQ) {
                releaseQueue(1, auctionState.queuedAskAmount);
                bidAmount[msg.sender] += bidQ;
                auctionState.totalBidAmount += bidQ;
                amountQ -= bidQ;
            } else {
                releaseQueue(1, tokenExchange(2, amountQ));
                bidAmount[msg.sender] += amountQ;
                auctionState.totalBidAmount += amountQ;
                amountQ = 0;
            }

            // 还有多的放入等待序列
            if (amountQ > 0) {
                auctionState.queuedBidAmount += amountQ;
                q.user = msg.sender;
                q.amount = amountQ;
                q.timestamp = block.timestamp;
                bidQueue.push(q);
            }

        }

        emit QueuesUpdated (
            auctionState.queuedAskAmount,
            auctionState.queuedBidAmount,
            block.timestamp
        );
    }

    // action   1 - askDeposit 2 - bidDeposit 3 - askWithdraw 4 - bidWithdraw
    function updateAfterAction(
        uint action,
        uint amount
        )
        internal
    {

        uint nonQueue;

        // 曲线到达暂停位置需要的值
        nonQueue = getLimits(action);

        uint askQueuedSup = 0;
        uint bidQueuedSup = 0;

        if (auctionState.queuedBidAmount > 0) {
            askQueuedSup = tokenExchange(2, auctionState.queuedBidAmount);
        }

        if (auctionState.queuedAskAmount > 0) {
            bidQueuedSup = tokenExchange(1, auctionState.queuedAskAmount);
        }

        // nonQueue表示不考虑queue情况下最大的存取值
        // askQueuedSup与bidQueuedSup表示可以“抵消掉”queue中的记录需要的值

        // 只有两种情况 1 - 没有WaitingList，多的部分会加到WaitingList中
        //            2 - 有WaitingList，必定有一个方向Pause，先改变价格，然后抵消Pause方向队列

        uint amountPrice = amount; // 用于更改价格的数量

        if (action == 1 && amountPrice > 0) {
            if (amountPrice <= nonQueue) {
                auctionState.totalAskAmount += amountPrice;
                askAmount[msg.sender] += amountPrice;
                updateActualPrice();
            } else {
                auctionState.totalAskAmount += nonQueue;
                askAmount[msg.sender] += nonQueue;
                updateActualPrice();
                updateQueue(action, amountPrice - nonQueue);
            }
        }

        // the addtional deposit will be inserted into the queue
        if (action == 2 && amountPrice > 0) {
            if (amountPrice <= nonQueue) {
                auctionState.totalBidAmount += amountPrice;
                bidAmount[msg.sender] += amountPrice;
                updateActualPrice();
            } else {
                auctionState.totalBidAmount += nonQueue;
                bidAmount[msg.sender] += nonQueue;
                updateActualPrice();
                updateQueue(action, amountPrice - nonQueue);
            }
        }

        if (action == 3) {
            require(
                auctionState.queuedAskAmount + nonQueue >= amount/*,
                "withdrawal amount beyond limit"*/
            );

            askAmount[msg.sender] -= amountPrice;

            if (amountPrice <= nonQueue) {
                auctionState.totalAskAmount -= amountPrice;
                updateActualPrice();
            } else {
                auctionState.totalAskAmount -= nonQueue;
                amountPrice -= nonQueue;
                updateActualPrice();

                // 先加后减
                releaseQueue(1,  amountPrice);
                emit QueuesUpdated (
                    auctionState.queuedAskAmount,
                    auctionState.queuedBidAmount,
                    block.timestamp
                );
                auctionState.totalAskAmount -= amountPrice;
            }

        }

        // the addtional withdraw will hedge the queue
        if (action == 4) {
            require(
                auctionState.queuedBidAmount + nonQueue >= amount/*,
                "withdrawal amount beyond limit"*/
            );

            bidAmount[msg.sender] -= amountPrice;

            if (amountPrice <= nonQueue) {
                auctionState.totalBidAmount -= amountPrice;
                updateActualPrice();
            } else {
                auctionState.totalBidAmount -= nonQueue;
                amountPrice -= nonQueue;
                updateActualPrice();

                // 先加后减
                releaseQueue(2, amountPrice - nonQueue);
                emit QueuesUpdated (
                    auctionState.queuedAskAmount,
                    auctionState.queuedBidAmount,
                    block.timestamp
                );
                auctionState.totalBidAmount -= amountPrice;
            }

        }

        updateLimits();

        triggerEvent(action, amount);
    }

    function updateLimits()
        internal
    {
        (auctionState.askDepositLimit,
            auctionState.bidDepositLimit,
            auctionState.askWithdrawalLimit,
            auctionState.bidWithdrawalLimit) = getLimits();
    }

    function updateActualPrice()
        internal
    {
        if (auctionState.totalBidAmount == 0) {
            return;
        }
        auctionState.actualPrice = mul(
            auctionState.totalAskAmount,
            tokenInfo.priceScale
        ) / auctionState.totalBidAmount;

        if (status == Status.OPEN &&
            auctionState.actualPrice <= auctionInfo.P*auctionInfo.M &&
            auctionState.actualPrice >= auctionInfo.P/auctionInfo.M
        ) {
            status = Status.CONSTRAINED;
            constrainedTime = block.timestamp;
            auctionState.estimatedTTLSeconds = auctionInfo.T;
            auctionEvents(3);
            oedax.logEvents(3);
        }

        //updateLimits();
    }

    /// @dev Request a withdrawal and returns the amount that has been /* successful */ly withdrawn from
    /// the auciton.
    function withdraw(
        address token,
        uint    amount)
        public
        returns (uint /* amount */)
    {

        require(
            auctionInfo.isWithdrawalAllowed/*,
            "withdraw is not allowed"*/
        );

        require(
            msg.sender != feeSettings.recepient/*,
            "recepient is not allowed"*/
        );

        require(
            status == Status.OPEN ||
            status == Status.CONSTRAINED/*,
            "withdraw not allowed"*/
        );

        require(
            amount > 0/*,
            "amount should not be 0"*/
        );

        require(
            token == tokenInfo.askToken ||
            token == tokenInfo.bidToken/*,
            "token not correct"*/
        );

        updatePrice();

        uint toWithdraw = amount;

        if (token == tokenInfo.askToken &&
            amount > min(askAmount[msg.sender], auctionState.askWithdrawalLimit)
        ) {
            toWithdraw = min(askAmount[msg.sender], auctionState.askWithdrawalLimit);
        }

        if (token == tokenInfo.bidToken &&
            amount > min(bidAmount[msg.sender], auctionState.bidWithdrawalLimit)
        ) {
            toWithdraw = min(bidAmount[msg.sender], auctionState.bidWithdrawalLimit);
        }

        // 成功取出的Token数量，录入新的参与记录
        newParticipation(token, -int(toWithdraw));

        uint penaltyBips = feeSettings.withdrawalPenaltyBips;
        uint realAmount = toWithdraw;

        if (penaltyBips > 0) {
            realAmount = realAmount - amount*penaltyBips/10000;
            treasury.sendFee(
                feeSettings.recepient,
                msg.sender,
                token,
                toWithdraw - realAmount
            );
        }

        treasury.auctionWithdraw(
            msg.sender,
            token,
            realAmount
        );

        uint action;
        if (token == tokenInfo.askToken) {
            action = 3;
        }
        if (token == tokenInfo.bidToken) {
            action = 4;
        }

        updateAfterAction(action, toWithdraw);

        return realAmount;
    }

    // function only works within a block
    function simulateDeposit(
        address user,
        address token,
        uint    amount)
        public
        view
        returns (
            uint /* amount */,
            AuctionState memory
        )
    {
        //TODO: simulate the price changes
    }

    /// @dev Simulate a withdrawal operation and returns the post-withdrawal state.
    function simulateWithdrawal(
        address user,
        address token,
        uint    amount)
        public
        view
        returns (
            uint /* amount */,
            AuctionState memory
        )
    {
        // TODO: simulate the price changes
    }

    function settle(address user)
        public
    {
        require(
            status >= Status.CLOSED &&
            !isSettled[user]/*,
            "the auction should be later than CLOSED status"*/
        );

        if (status == Status.CLOSED) {
            triggerSettle();
        }

        uint lockedA;
        uint lockedB;
        uint exchangedA;
        uint exchangedB;

        (lockedA, lockedB) = calcActualTokens(user);
        exchangedA = tokenExchange(2, lockedB);
        exchangedB = tokenExchange(1, lockedA);

        isSettled[user] = true;

        treasury.exchangeTokens(
            feeSettings.recepient,
            user,
            tokenInfo.askToken,
            tokenInfo.bidToken,
            exchangedA,
            exchangedB
        );
    }

    // 拍卖结束后提款
    function settle()
        external
    {
        settle(msg.sender);
    }

    // Try to settle the auction.
    // 用于返还等待序列中的Token
    // 分配手续费creationFee - creator， protocolFee - recepient
    // 其余手续费： walletFee - 用户deposit时收取
    // takerFee - 用户Settle时分配
    // withdrawalPenalty - 用户withdraw时收取
    function triggerSettle()
        public
        returns (bool success)
    {

        require(
            status == Status.CLOSED/*,
            "the auction should be later than CLOSED status"*/
        );
        // 第一步：清空askQueue与bidQueue
        uint len;
        QueuedParticipation memory q;

        len = askQueue.length;
        while(len > 0) {
            q = askQueue[len - 1];
            success = treasury.auctionWithdraw(
                q.user,
                tokenInfo.askToken,
                q.amount
            );
            auctionState.queuedAskAmount -= q.amount;
            len--;
        }
        askQueue.length = 0; // delete

        len = bidQueue.length;
        while(len > 0) {
            q = bidQueue[len - 1];
            success = treasury.auctionWithdraw(
                q.user,
                tokenInfo.bidToken,
                q.amount
            );
            auctionState.queuedBidAmount -= q.amount;
            len--;
        }
        bidQueue.length = 0; // delete

        // 第二步: 发放creationFee 与 protocolFee
        treasury.sendFeeAll(
            auctionSettings.creator,
            tokenInfo.askToken,
            auctionState.totalAskAmount*feeSettings.creationFeeEth
        );

        treasury.sendFeeAll(
            auctionSettings.creator,
            tokenInfo.bidToken,
            auctionState.totalBidAmount*feeSettings.creationFeeEth
        );

        treasury.sendFeeAll(
            feeSettings.recepient,
            tokenInfo.askToken,
            auctionState.totalAskAmount*feeSettings.protocolBips
        );

        treasury.sendFeeAll(
            feeSettings.recepient,
            tokenInfo.bidToken,
            auctionState.totalBidAmount*feeSettings.protocolBips
        );
        // 第三步： 更改拍卖状态并通知Oedax主合约
        status = Status.SETTLED;

        /*
        emit AuctionSettled (
            auctionSettings.creator,
            auctionSettings.auctionId,
            address(this),
            block.timestamp
        );
        */
        auctionEvents(5);
        oedax.logEvents(5);
    }

    /// @dev Get participations from a given address.
    function getUserParticipations(address user)
        external
        view
        returns (
            uint total,
            Participation[] memory p
        )
    {
        uint[] memory index = participationIndex[user];
        total = index.length;
        Participation[] memory p;
        p = new Participation[](total);

        for (uint i = 0; i < total; i++) {
            p[i] = (participations[index[i]]);
        }
    }

    /// @dev Returns a sub-sequence of participations.
    /// select result of length count after skip
    function getParticipations(
        uint skip,
        uint count
        )
        external
        view
        returns (
            uint  total,
            Participation[] memory p
        )
    {
        uint len1 = participations.length;
        uint total = count;
        require(
            len1 > skip/*,
            "params not correct"*/
        );
        if (len1 < add(skip, count)) {
            total = len1 - skip;
        }
        p = new Participation[](total);
        for (uint i = 0; i < total; i++) {
            p[i] = participations[skip + i];
        }
    }
}