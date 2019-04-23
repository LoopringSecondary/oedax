pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IAuction.sol";
import "../iface/ITreasury.sol";
import "../iface/IOedax.sol";
import "../lib/MathLib.sol";
import "../iface/ICurve.sol";
import "../helper/DataHelper.sol";

contract ImplAuction is IAuction, MathLib, DataHelper, IAuctionEvents, IParticipationEvents{


    mapping(address => uint[]) private participationIndex;  // user address => index of Participation[]

    uint private askPausedTime;//time on askCurve = now-contrainedTime-askPausedTime
    uint private bidPausedTime;//time on bidCurve = now-contrainedTime-bidPausedTime

    IOedax public oedax;
    ITreasury public treasury;
    address public curve;


    modifier isOedax(){
        require(
            msg.sender == address(oedax),
            "the address is not creator"
        );
        _;
    }


    constructor(
        address _oedax,
        address _treasury, 
        address _curve,
        uint    _curveID,
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
        auctionSettings.auctionID = id; 
        auctionSettings.curveID = _curveID;
        auctionSettings.startedTimestamp = now;
        

        auctionInfo = _auctionInfo;
        feeSettings = _feeSettings;
        tokenInfo = _tokenInfo;
        
        lastSynTime = now;
        auctionState.askPrice = auctionInfo.P*auctionInfo.M;
        auctionState.bidPrice = auctionInfo.P/auctionInfo.M;

        status = Status.STARTED;
        //transfer complete in Oedax contract
        if (initialAskAmount > 0){
            askAmount[creator] += initialAskAmount;
            auctionState.totalAskAmount += initialAskAmount;
        }

        if (initialBidAmount > 0){
            bidAmount[creator] += initialBidAmount;
            auctionState.totalBidAmount += initialBidAmount;
        }
        
        auctionState.estimatedTTLSeconds = _auctionInfo.T;
        
        if (initialBidAmount != 0){
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

        //oedax.receiveEvents(1);

        if (auctionInfo.delaySeconds == 0){
            status = Status.OPEN;
            
            /*
            emit AuctionOpened (
                creator,
                auctionSettings.auctionID,
                address(this),
                now
            );
            */
            // 此处event在oedax合约中完成
            //oedax.receiveEvents(2);
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
        P.timestamp = now;
        participations.push(P);
        participationIndex[msg.sender].push(P.index);
        if (!userParticipated[msg.sender]){
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
        if (action%2 == 1){
            isAsk = true;
        }
        
        if (action <= 2){
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
                now
            );
        } 
        else{
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
                now
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
        returns(
            uint /* askDepositLimit */,
            uint /* bidDepositLimit */,
            uint /* askWithdrawalLimit */,
            uint /* bidWithdrawalLimit */
            )
    {
        require(
            _bid > 0,
            "bid amount should be larger than 0"
        );
        uint actualPrice = mul(_ask, tokenInfo.priceScale)/_bid; 
        
        uint askDepositLimit;
        uint bidDepositLimit;
        uint askWithdrawLimit;
        uint bidWithdrawLimit;
        
        if (actualPrice >= bidPrice){
            bidDepositLimit = mul((actualPrice - bidPrice), _bid)/bidPrice;
            if (bidDepositLimit > auctionInfo.maxBidAmountPerAddr){
                bidDepositLimit = auctionInfo.maxBidAmountPerAddr;
            }

            askWithdrawLimit = mul((actualPrice - bidPrice), _bid)/tokenInfo.priceScale;
            if (askWithdrawLimit > auctionInfo.maxAskAmountPerAddr){
                askWithdrawLimit = auctionInfo.maxAskAmountPerAddr;
            }
        }
        else{
            bidDepositLimit = 0;
            askWithdrawLimit = 0;
        }

        if (actualPrice <= askPrice){
            askDepositLimit = mul((askPrice - actualPrice), _bid)/tokenInfo.priceScale;
            if (askDepositLimit > auctionInfo.maxAskAmountPerAddr){
                askDepositLimit = auctionInfo.maxAskAmountPerAddr;
            }
              
            bidWithdrawLimit = mul((askPrice - actualPrice), _bid)/askPrice;
            if (bidWithdrawLimit > auctionInfo.maxBidAmountPerAddr){
                bidWithdrawLimit = auctionInfo.maxBidAmountPerAddr;
            }
        }
        else{
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
        returns(
            uint /*askPrice*/,
            uint /*bidPrice*/,
            uint /*actualPrice*/,
            uint /*askPausedTime*/,
            uint /*bidPausedTime*/
        )
    {
        uint time = add(now, dt);
        require(
            time >= lastSynTime,
            "time should not be earlier than lastSynTime"
        );

        require(
            auctionState.actualPrice > 0,
            "actualPrice should not be 0"
        );

        if (time == lastSynTime){
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
 
        (success, t1) = ICurve(curve).calcInvAskPrice(auctionSettings.curveID, auctionState.actualPrice);
        // 曲线没有相交，askPrice按照时间变化
        if (!success ||
            t1 >= sub(time, constrainedTime + askPausedTime)
        )
        {
            askPrice = calcAskPrice(sub(time, constrainedTime + askPausedTime));
        }
        else
        {
            // 曲线相交，askPrice设置为actualPrice
            askPrice = auctionState.actualPrice;
            _askPausedTime = sub(time, constrainedTime + t1);
        }
        
        
        (success, t2) = ICurve(curve).calcInvBidPrice(auctionSettings.curveID, auctionState.actualPrice);
        // 曲线没有相交，bidPrice按照时间变化
        if (!success ||
            t2 >= sub(now, constrainedTime + bidPausedTime)
        )
        {
            bidPrice = calcBidPrice(sub(now, constrainedTime + bidPausedTime));
        }
        else
        {
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
            now >= auctionSettings.startedTimestamp + auctionInfo.delaySeconds
        )
        {
            status = Status.OPEN;
            /*
            emit AuctionOpened (
                auctionSettings.creator,
                auctionSettings.auctionID,
                address(this),
                now
            );
            */
            oedax.receiveEvents(2);
        }

        if (status == Status.OPEN &&
            auctionState.actualPrice <= auctionInfo.P*auctionInfo.M &&
            auctionState.actualPrice >= auctionInfo.P/auctionInfo.M
        )
        {
            status = Status.CONSTRAINED;
            constrainedTime = now;
            auctionState.estimatedTTLSeconds = auctionInfo.T;
            /*
            emit AuctionConstrained(
                auctionSettings.creator,
                auctionSettings.auctionID,
                address(this),
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                now
            );
            */
            oedax.receiveEvents(3);
        }

        if (now == lastSynTime || status != Status.CONSTRAINED){
            return;
        }
        uint askPrice;
        uint bidPrice;
        uint _askPausedTime = askPausedTime;
        uint _bidPausedTime = bidPausedTime;
        (askPrice, bidPrice,  , _askPausedTime, _bidPausedTime) = simulatePrice(0);
        auctionState.askPrice = askPrice;
        auctionState.bidPrice = bidPrice;
        askPausedTime = _askPausedTime;
        bidPausedTime = _bidPausedTime;
        auctionState.estimatedTTLSeconds = getEstimatedTTL();
        lastSynTime = now;
        
        if (askPrice <= bidPrice){
            status = Status.CLOSED;
            /*
            emit AuctionClosed(
                auctionSettings.creator,
                auctionSettings.auctionID,
                address(this),
                auctionState.totalAskAmount,
                auctionState.totalBidAmount,
                tokenInfo.priceScale,
                auctionState.actualPrice,
                now,
                true
            );
            */
            oedax.receiveEvents(4);
        }
        updateLimits();
    }
    
    /// @dev Return the ask/bid deposit/withdrawal limits. Note that existing queued items should
    /// be considered in the calculations.
    function getLimits()
        public
        view
        returns(
            uint /* askDepositLimit */,
            uint /* bidDepositLimit */,
            uint /* askWithdrawalLimit */,
            uint /* bidWithdrawalLimit */
        )
    {
        
        if (status == Status.STARTED ||
            status >= Status.CLOSED
        )
        {
            return (0,0,0,0);
        }

       
        if (status == Status.OPEN){
            return (
                auctionInfo.maxAskAmountPerAddr,
                auctionInfo.maxBidAmountPerAddr,
                auctionInfo.maxAskAmountPerAddr,
                auctionInfo.maxBidAmountPerAddr
            );
        }

        require(
            auctionState.actualPrice > 0,
            "actualPrice should not be 0"
        );

        uint askPrice;
        uint bidPrice;
        uint actualPrice;
        (askPrice, bidPrice, actualPrice,  ,  ) = simulatePrice(0);

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


    
    function getQueueStatus()
        public
        view
        returns(
            uint,
            uint
        )
    {
        uint s = 0;
        uint amount = 0;
        if (askQueue.length > 0){
            s += 1;
            amount = auctionState.queuedAskAmount;
        }
        
        if (bidQueue.length > 0){
            s += 2;
            amount = auctionState.queuedBidAmount;
        }
        return (s, amount);

    }


    function getActualPrice()
        public
        view
        returns(
            uint
        )
    {
        uint price = auctionState.actualPrice;
        return price;    
    }


    function calcActualTokens(address user)
        public
        view
        returns(
            uint,
            uint
        )
    {
        require(
            status >= Status.OPEN,
            "The auction is not open yet"
        );
        uint amountA = askAmount[user];
        uint amountB = bidAmount[user];
        if (totalTakerRateA > 0){
            amountA += totalTakerAmountA*takerRateA[user]/totalTakerRateA;
        }
        if (totalTakerRateB > 0){         
            amountB += totalTakerAmountB*takerRateB[user]/totalTakerRateB;  
        }
        return (amountA, amountB); 
    }
    
    function calcTakeRate()
        public
        view
        returns(
            uint /* rate */
        )
    {
        uint rate;
        if (status <= Status.OPEN){
            return 100;
        }

        //uint time = sub(now, auctionSettings.startedTimestamp + auctionInfo.delaySeconds);
        uint time = sub(now, constrainedTime);
        // rate drops when time goes on

        rate = time*100/auctionInfo.T;

        if (rate < 100){
            rate = 100 - rate;
        }
        else{
            rate = 0;
        }

        return rate;
    }


    function getAuctionSettings()
        public
        view
        returns(
            AuctionSettings memory
        )
    {
        AuctionSettings memory aucSettings;
        aucSettings = auctionSettings;
        return aucSettings;
    }
    

    function getAuctionInfo()
        public
        view
        returns(
            AuctionInfo memory
        )
    {
        AuctionInfo memory _auctionInfo;
        _auctionInfo = auctionInfo;
        return _auctionInfo;
    }


    function getTokenInfo()
        public
        view
        returns(
            TokenInfo memory
        )
    {
        TokenInfo memory _tokenInfo;
        _tokenInfo = tokenInfo;
        return _tokenInfo;
    }

    function getFeeSettings()
        public
        view
        returns(
            FeeSettings memory
        )
    {
        FeeSettings memory _feeSettings;
        _feeSettings = feeSettings;
        return _feeSettings;
    }


    function getAuctionState()
        public
        view
        returns(
            AuctionState memory
        )
    {
        AuctionState memory aucState;
        aucState = auctionState;
        return aucState;
    }


    function getAuctionSettingsBytes()
        public
        view
        returns(
            bytes memory
        )
    {
        AuctionSettings memory S;
        bytes memory b;
        S = getAuctionSettings();
        b = auctionSettingsToBytes(S);
        return b;
    }
    
    function getAuctionStateBytes()
        public
        view
        returns(
            bytes memory
        )
    {
        AuctionState memory S;
        bytes memory b;
        S = getAuctionState();
        b = auctionStateToBytes(S);
        return b;
    }

    function getAuctionInfoBytes()
        public
        view
        returns(
            bytes memory
        )
    {
        AuctionInfo memory S;
        bytes memory b;
        S = getAuctionInfo();
        b = auctionInfoToBytes(S);
        return b;
    }

    function getTokenInfoBytes()
        public
        view
        returns(
            bytes memory
        )
    {
        TokenInfo memory S;
        bytes memory b;
        S = getTokenInfo();
        b = tokenInfoToBytes(S);
        return b;
    }

    function getFeeSettingsBytes()
        public
        view
        returns(
            bytes memory
        )
    {
        FeeSettings memory S;
        bytes memory b;
        S = getFeeSettings();
        b = feeSettingsToBytes(S);
        return b;
    }

    function calcAskPrice(
        uint t
    )
        internal
        view
        returns(
            uint
        )
    {
        uint p = ICurve(curve).calcAskPrice(auctionSettings.curveID, t);
        return p;
    }

    function calcBidPrice(
        uint t
    )
        internal
        view
        returns(
            uint
        )
    {
        uint p = ICurve(curve).calcBidPrice(auctionSettings.curveID, t);
        return p;
    }



    /// @dev Return the estimated time to end
    function getEstimatedTTL()
        public
        view
        returns(
            uint /* ttlSeconds */
        )
    {
        uint period = auctionInfo.T;
        
        if (status <= Status.OPEN){
            return period;
        }
        if (status > Status.CONSTRAINED){
            return 0;
        }

        uint t1 = sub(now, constrainedTime + askPausedTime);
        uint t2 = sub(now, constrainedTime + bidPausedTime);
  
        return ICurve(curve).calcEstimatedTTL(auctionSettings.curveID, t1, t2);
        
    }


    function askDeposit(uint amount)
        public
        returns (
            uint /* amount */
        )
    {
        return deposit(tokenInfo.askToken, amount);
    }

    function bidDeposit(uint amount)
        public
        returns (
            uint /* amount */
        )
    {
        return deposit(tokenInfo.bidToken, amount);
    }

    function askWithdraw(uint amount)
        public
        returns (
            uint /* amount */
        )
    {
        return withdraw(tokenInfo.askToken, amount);
    }

    function bidWithdraw(uint amount)
        public
        returns (
            uint /* amount */
        )
    {
        return withdraw(tokenInfo.bidToken, amount);
    }


    function deposit(
        address token,
        uint    amount)
        public
        returns (
            uint /* amount */
        )
    {
        return deposit(address(0x0), token, amount);
    }

    /// @dev Make a deposit and returns the amount that has been successfully deposited into the
    /// auciton, the rest is put into the waiting list (queue).
    /// Set `wallet` to 0x0 will avoid paying wallet a fee. Note only deposit has fee.
    function deposit(
        address wallet,
        address token,
        uint    amount)
        public
        returns (
            uint /* amount */
        )
    {
        require(
            token == tokenInfo.askToken ||
            token == tokenInfo.bidToken,
            "token not correct"
        );

        require(
            msg.sender != feeSettings.recepient,
            "recepient is not allowed"
        );

        if (status == Status.STARTED&&
            now >= auctionSettings.startedTimestamp + auctionInfo.delaySeconds
        )
        {
            status = Status.OPEN;
            oedax.receiveEvents(2);
        }

        require(
            status == Status.OPEN ||
            status == Status.CONSTRAINED,
            "deposit not allowed"
        );

        bool success;
        uint feeBips;
        uint realAmount;

        if (wallet == address(0x0)){
            feeBips = 0;
        }
        else{
            feeBips = feeSettings.protocolBips + feeSettings.walletBipts;
        }
        realAmount = amount*(10000-feeBips)/10000;

        
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
        success = treasury.auctionDeposit(
            msg.sender,
            token,
            amount  // must be greater than 0.
        );


        uint action;
        if (token == tokenInfo.askToken){
            action = 1;
        }
        if (token == tokenInfo.bidToken){
            action = 2;
        }

        updateAfterAction(action,amount);




        return amount;
    
    }

    
    // 不考虑waitinglist情况下的limit
    // action   1 - askDeposit 2 - bidDeposit 3 - askWithdraw 4 - bidWithdraw 
    function getLimits(
        uint action
    )
        internal
        view
        returns(
            uint
        )
    {
                
        if (status == Status.STARTED ||
            status >= Status.CLOSED
        )
        {
            return 0;
        }

        if (status == Status.OPEN){
            if (action == 1 || action == 3){
                return auctionInfo.maxAskAmountPerAddr;
            }
            else{
                return auctionInfo.maxBidAmountPerAddr;
            }
        }

        
        uint limit = 0;

        if (action == 1){
            limit = mul(
                sub(auctionState.askPrice, auctionState.actualPrice), 
                auctionState.totalBidAmount
                )/tokenInfo.priceScale;
        }
        
        if (action == 2){
            limit = mul(
                sub(auctionState.actualPrice, auctionState.bidPrice), 
                auctionState.totalBidAmount
                )/auctionState.bidPrice;
        }
        
        if (action == 3){
            limit = mul(
                sub(auctionState.actualPrice, auctionState.bidPrice), 
                auctionState.totalBidAmount
                )/tokenInfo.priceScale;
        }
        
        if (action == 4){
            limit = mul(
                sub(auctionState.askPrice, auctionState.actualPrice), 
                auctionState.totalBidAmount
                )/auctionState.askPrice;
        }

        return limit;
    }

    
    function tokenExchange(
        uint dir,
        uint amount
    )
        internal
        view
        returns(
            uint
        )
    {
        uint res = amount;
        // input amountA, output amountB
        if (dir == 1){
            res = mul(amount, tokenInfo.priceScale)/auctionState.actualPrice;
        }
        
        // input amountB, output amountA
        if (dir == 2){
            res = mul(amount, auctionState.actualPrice)/tokenInfo.priceScale;
        }

        return res;

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
            dir == 2 && amount <= auctionState.queuedBidAmount,
            "amount not correct"
        );
        
        uint len;
        uint amountRes = amount;
        QueuedParticipation memory q;
        if (dir == 1){
            len = askQueue.length;
            auctionState.totalAskAmount += amountRes;
            while(len > 0 && amountRes > 0){
                q = askQueue[len - 1];
                if (amountRes >= q.amount){
                    askAmount[q.user] += q.amount;
                    auctionState.queuedAskAmount -= q.amount;
                    amountRes -= q.amount;
                    askQueue[len - 1].amount = 0;
                }
                else{
                    askAmount[q.user] += amountRes;
                    auctionState.queuedAskAmount -= amountRes;
                    askQueue[len - 1].amount = q.amount - amountRes;
                    amountRes -= amountRes;
                    break;
                }
                len--;
            }
            askQueue.length = len;
        }

        if (dir == 2){
            len = bidQueue.length;
            auctionState.totalBidAmount += amountRes;
            while(len > 0 && amountRes > 0){
                q = bidQueue[len - 1];
                if (amountRes >= q.amount){
                    bidAmount[q.user] += q.amount;
                    auctionState.queuedBidAmount -= q.amount;
                    amountRes -= q.amount;
                    bidQueue[len - 1].amount = 0;
                }
                else{
                    bidAmount[q.user] += amountRes;
                    auctionState.queuedBidAmount -= amountRes;
                    bidQueue[len - 1].amount = q.amount - amountRes;
                    amountRes -= amountRes;
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
        if (action == 1){
            // 首先抵消Bid，然后追加Ask
            if (amountQ >= askQ){
                releaseQueue(2, auctionState.queuedBidAmount); 
                askAmount[msg.sender] += askQ;
                auctionState.totalAskAmount += askQ;
                amountQ -= askQ;
            }
            else{
                releaseQueue(2, tokenExchange(1, amountQ)); 
                askAmount[msg.sender] += amountQ;
                auctionState.totalAskAmount += amountQ;
                amountQ = 0;  
            }


            // 还有多的放入等待序列
            if (amountQ > 0){
                auctionState.queuedAskAmount += amountQ;
                q.user = msg.sender;
                q.amount = amountQ;
                q.timestamp = now;
                askQueue.push(q);
            }

        }

        // 2 - bidDeposit
        if (action == 2){
            // 首先抵消Ask，然后追加Bid
            if (amountQ >= bidQ){
                releaseQueue(1, auctionState.queuedAskAmount); 
                bidAmount[msg.sender] += bidQ;
                auctionState.totalBidAmount += bidQ;
                amountQ -= bidQ;
            }
            else{
                releaseQueue(1, tokenExchange(2, amountQ)); 
                bidAmount[msg.sender] += amountQ;
                auctionState.totalBidAmount += amountQ;
                amountQ = 0;  
            }

            // 还有多的放入等待序列
            if (amountQ > 0){
                auctionState.queuedBidAmount += amountQ;
                q.user = msg.sender;
                q.amount = amountQ;
                q.timestamp = now;
                bidQueue.push(q);
            }

        }

        emit QueuesUpdated (
            auctionState.queuedAskAmount,
            auctionState.queuedBidAmount,
            now
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
        
        if (auctionState.queuedBidAmount > 0){
            askQueuedSup = tokenExchange(2, auctionState.queuedBidAmount);
        }
        
        if (auctionState.queuedAskAmount > 0){
            bidQueuedSup = tokenExchange(1, auctionState.queuedAskAmount);
        }

        // nonQueue表示不考虑queue情况下最大的存取值
        // askQueuedSup与bidQueuedSup表示可以“抵消掉”queue中的记录需要的值

        // 只有两种情况 1 - 没有WaitingList，多的部分会加到WaitingList中
        //            2 - 有WaitingList，必定有一个方向Pause，先改变价格，然后抵消Pause方向队列


        uint amountPrice = amount; // 用于更改价格的数量
        
        if (action == 1){
            if (amountPrice > 0){
                if (amountPrice <= nonQueue){
                    auctionState.totalAskAmount += amountPrice;
                    askAmount[msg.sender] += amountPrice;
                    updateActualPrice();
                }
                else{
                    auctionState.totalAskAmount += nonQueue;
                    askAmount[msg.sender] += nonQueue;       
                    updateActualPrice();
                    updateQueue(action, amountPrice - nonQueue);
                } 
            }  
        }
        
        // the addtional deposit will be inserted into the queue
        if (action == 2){
            if (amountPrice > 0){
                if (amountPrice <= nonQueue){
                    auctionState.totalBidAmount += amountPrice;
                    bidAmount[msg.sender] += amountPrice;
                    updateActualPrice();
                }
                else{
                    auctionState.totalBidAmount += nonQueue;
                    bidAmount[msg.sender] += nonQueue;
                    updateActualPrice();
                    updateQueue(action, amountPrice - nonQueue);
                }
            }
        }



        if (action == 3){
            require(
                auctionState.queuedAskAmount + nonQueue >= amount,
                "withdrawal amount beyond limit"
            );

            askAmount[msg.sender] -= amountPrice;
            
            if (amountPrice <= nonQueue){
                auctionState.totalAskAmount -= amountPrice;
                updateActualPrice();
            }
            else{
                auctionState.totalAskAmount -= nonQueue;
                amountPrice -= nonQueue;
                updateActualPrice();
                
                // 先加后减
                releaseQueue(1,  amountPrice);
                emit QueuesUpdated (
                    auctionState.queuedAskAmount,
                    auctionState.queuedBidAmount,
                    now
                );
                auctionState.totalAskAmount -= amountPrice;
            } 
     
        }

        // the addtional withdraw will hedge the queue
        if (action == 4){
            require(
                auctionState.queuedBidAmount + nonQueue >= amount,
                "withdrawal amount beyond limit"
            );

            bidAmount[msg.sender] -= amountPrice;

            if (amountPrice <= nonQueue){
                auctionState.totalBidAmount -= amountPrice;    
                updateActualPrice();
            }
            else{
                auctionState.totalBidAmount -= nonQueue;   
                amountPrice -= nonQueue;  
                updateActualPrice();
                
                // 先加后减
                releaseQueue(2, amountPrice - nonQueue);
                emit QueuesUpdated (
                    auctionState.queuedAskAmount,
                    auctionState.queuedBidAmount,
                    now
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
            auctionState.bidWithdrawalLimit)=getLimits();
    }

    function updateActualPrice()
        internal
    {
        if (auctionState.totalBidAmount == 0){
            return;
        }
        auctionState.actualPrice = mul(
            auctionState.totalAskAmount,
            tokenInfo.priceScale
        )/auctionState.totalBidAmount;
         
        
        if (status == Status.OPEN &&
            auctionState.actualPrice <= auctionInfo.P*auctionInfo.M &&
            auctionState.actualPrice >= auctionInfo.P/auctionInfo.M
        )
        {
            status = Status.CONSTRAINED;
            constrainedTime = now;
            auctionState.estimatedTTLSeconds = auctionInfo.T;
            oedax.receiveEvents(3);
        }
        
        //updateLimits();

    }

    /// @dev Request a withdrawal and returns the amount that has been /* successful */ly withdrawn from
    /// the auciton.
    function withdraw(
        address token,
        uint    amount)
        public
        returns (
            uint /* amount */
        )
    {


        require(
            auctionInfo.isWithdrawalAllowed,
            "withdraw is not allowed"
        );
        
        require(
            msg.sender != feeSettings.recepient,
            "recepient is not allowed"
        );

        require(
            status == Status.OPEN ||
            status == Status.CONSTRAINED,
            "withdraw not allowed"
        );

        require(
            amount > 0,
            "amount should not be 0"
        );

        require(
            token == tokenInfo.askToken ||
            token == tokenInfo.bidToken,
            "token not correct"
        );

        
        updatePrice();
        

        uint toWithdraw = amount;


        if (token == tokenInfo.askToken &&
            amount > min(askAmount[msg.sender], auctionState.askWithdrawalLimit)
        )
        {
            toWithdraw = min(askAmount[msg.sender], auctionState.askWithdrawalLimit);
        }

        if (token == tokenInfo.bidToken &&
            amount > min(bidAmount[msg.sender], auctionState.bidWithdrawalLimit)
        )
        {
            toWithdraw = min(bidAmount[msg.sender], auctionState.bidWithdrawalLimit);
        }
        
        // 成功取出的Token数量，录入新的参与记录
        newParticipation(token, -int(toWithdraw));

        uint penaltyBips = feeSettings.withdrawalPenaltyBips;         
        uint realAmount = toWithdraw;         
        bool success;

        if (penaltyBips > 0){
            realAmount = realAmount - amount*penaltyBips/10000;
            treasury.sendFee(
                feeSettings.recepient,
                msg.sender,
                token,
                toWithdraw - realAmount
            );
        }

        success = treasury.auctionWithdraw(
            msg.sender,
            token,
            realAmount
        );

        
        uint action;
        if (token == tokenInfo.askToken){
            action = 3;
        }
        if (token == tokenInfo.bidToken){
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

    // 拍卖结束后提款
    function settle()
        external
        returns (
            bool /* settled */
        )
    {
        require(
            status >= Status.CLOSED &&
            !isSettled[msg.sender],
            "the auction should be later than CLOSED status"
        );
        
        if (status == Status.CLOSED){
            triggerSettle();
            //status = Status.SETTLED;
        }

        uint lockedA;
        uint lockedB;
        uint exchangedA; 
        uint exchangedB;

        (lockedA, lockedB) = calcActualTokens(msg.sender); 
        exchangedA = tokenExchange(2, lockedB);
        exchangedB = tokenExchange(1, lockedA);

        isSettled[msg.sender] = true;

        treasury.exchangeTokens(
            feeSettings.recepient,
            msg.sender,
            tokenInfo.askToken,
            tokenInfo.bidToken,
            exchangedA,
            exchangedB
        );
   
    } 

    // Try to settle the auction.
    // 用于返还等待序列中的Token
    function triggerSettle()
        public
        returns (
            bool /* settled */
        )
    {

        require(
            status == Status.CLOSED,
            "the auction should be later than CLOSED status"
        );
        // TODO: settle
        uint len;
        bool success;
        QueuedParticipation memory q;

        len = askQueue.length;
        while(len > 0){
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
        while(len > 0){
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

        status = Status.SETTLED;

        /*
        emit AuctionSettled (
            auctionSettings.creator,
            auctionSettings.auctionID,
            address(this),
            now
        );
        */
        oedax.receiveEvents(5);    
        return success;
    }


    /// @dev Get participations from a given address.
    function getUserParticipations(
        address user
    )
        external
        view
        returns (
            uint /* total */,
            Participation[] memory
        )
    {
        uint[] memory index = participationIndex[user];
        uint len = index.length;
        Participation[] memory p;
        p = new Participation[](len);
        
        for (uint i = 0; i < len; i++){
            p[i] = (participations[index[i]]);
        } 
        return (len, p);

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
            uint /* total */,
            Participation[] memory
        )
    {
        uint len1 = participations.length;
        uint len2 = count;
        require(
            len1 > skip,
            "params not correct"
        );
        if (len1 < add(skip,count)) {
            len2 = len1 - skip;
        }
        Participation[] memory p;
        p = new Participation[](len2);
        for (uint i = 0; i < len2; i++){
            p[i] = participations[skip+i];
        }
        return (len2, p);
    }
    
}