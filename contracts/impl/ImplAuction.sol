pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IAuction.sol";
import "../iface/ITreasury.sol";
import "../iface/IOedax.sol";
import "../lib/MathLib.sol";
import "../iface/ICurve.sol";

contract ImplAuction is IAuction, MathLib{


    mapping(address => uint[]) private participationIndex;  // user address => index of Participation[]

    uint private askPausedTime;//time on askCurve = now-contrainedTime-askPausedTime
    uint private bidPausedTime;//time on bidCurve = now-contrainedTime-bidPausedTime

    IOedax public oedax;
    ITreasury public treasury;
    ICurve public curve;

    modifier isStatus(Status stat){
        require(status == stat, "Status not correct");
        _;
    }

    modifier onlyCreator(){
        require(
            msg.sender == auctionSettings.creator,
            "the address is not creator"
        );
        _;
    }

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

        FeeSettings memory feeSettings,
        TokenInfo   memory tokenInfo,
        Info        memory info,

        uint    id,
        address creator
    ) 
        public
    {
        
        oedax = IOedax(_oedax);
        treasury = ITreasury(_treasury);
        curve = ICurve(_curve);

        auctionSettings.creator = creator;
        auctionSettings.auctionID = id; //given by Oedax contract
        auctionSettings.curveID = _curveID;

        auctionSettings.info = info;
        auctionSettings.feeSettings = feeSettings;
        auctionSettings.tokenInfo = tokenInfo;
        

        status = Status.STARTED;
        //transfer complete in Oedax contract
        auctionState.totalAskAmount = initialAskAmount;
        auctionState.totalBidAmount = initialBidAmount;
        auctionState.estimatedTTLSeconds = info.delaySeconds + info.T;
        if (initialAskAmount != 0){
            auctionState.actualPrice = mul(auctionSettings.tokenInfo.priceScale, initialAskAmount)/initialBidAmount;
        }

    }



    // 初始总量为_ask, _bid
    // price = _ask/_bid * priceScale
    // ask越多 价格越高 
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
        uint actualPrice = mul(_ask, auctionSettings.tokenInfo.priceScale)/_bid; 
        
        if (status == Status.OPEN){
            return (
                auctionSettings.info.maxAskAmountPerAddr,
                auctionSettings.info.maxBidAmountPerAddr,
                auctionSettings.info.maxAskAmountPerAddr,
                auctionSettings.info.maxBidAmountPerAddr
            );
        }

        if (status == Status.STARTED ||
            status >= Status.CLOSED
        )
        {
            return (0,0,0,0);
        }

        uint askDepositLimit;
        uint bidDepositLimit;
        uint askWithdrawLimit;
        uint bidWithdrawLimit;
        
        if (actualPrice >= bidPrice){
            bidDepositLimit = mul((actualPrice - bidPrice), _bid)/bidPrice;
            if (bidDepositLimit > auctionSettings.info.maxBidAmountPerAddr){
                bidDepositLimit = auctionSettings.info.maxBidAmountPerAddr;
            }

            askWithdrawLimit = mul((actualPrice - bidPrice), _bid);
            if (askWithdrawLimit > auctionSettings.info.maxAskAmountPerAddr){
                askWithdrawLimit = auctionSettings.info.maxAskAmountPerAddr;
            }
        }
        else{
            bidDepositLimit = 0;
            askWithdrawLimit = 0;
        }

        if (actualPrice <= askPrice){
            askDepositLimit = mul((askPrice - actualPrice), _bid);
            if (askDepositLimit > auctionSettings.info.maxAskAmountPerAddr){
                askDepositLimit = auctionSettings.info.maxAskAmountPerAddr;
            }
              
            bidWithdrawLimit = mul((askPrice - actualPrice), _bid)/askPrice;
            if (bidWithdrawLimit > auctionSettings.info.maxBidAmountPerAddr){
                bidWithdrawLimit = auctionSettings.info.maxBidAmountPerAddr;
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

    function simulatePrice(uint time)
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
        require(
            time >= lastSynTime,
            "time should not be earlier than lastSynTime"
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
 
        (success, t1) = curve.calcInvAskPrice(auctionSettings.curveID, auctionState.actualPrice);
        //曲线没有相交
        if (!success ||
            t1 >= sub(time, constrainedTime + askPausedTime)
        )
        {
            askPrice = calcAskPrice(sub(time, constrainedTime + askPausedTime));
        }
        else
        {
            askPrice = auctionState.actualPrice;
            _askPausedTime = sub(time, constrainedTime + t1);
        }
        
        (success, t2) = curve.calcInvBidPrice(auctionSettings.curveID, auctionState.actualPrice);
        if (!success ||
            t2 >= sub(now, constrainedTime + bidPausedTime)
        )
        {
            bidPrice = calcBidPrice(sub(now, constrainedTime + bidPausedTime));
        }
        else
        {
            bidPrice = auctionState.actualPrice;
            _bidPausedTime = sub(time, constrainedTime + t2);
        }

        return (askPrice, bidPrice, auctionState.actualPrice, _askPausedTime, _bidPausedTime);

    }


    function updatePrice()
        internal
    {
        if (now == lastSynTime){
            return;
        }
        uint askPrice;
        uint bidPrice;
        uint _askPausedTime = askPausedTime;
        uint _bidPausedTime = bidPausedTime;
        (askPrice, bidPrice,  , _askPausedTime, _bidPausedTime) = simulatePrice(now);
        auctionState.askPrice = askPrice;
        auctionState.bidPrice = bidPrice;
        askPausedTime = _askPausedTime;
        bidPausedTime = _bidPausedTime;
        lastSynTime = now;
        //结束
        if (askPrice <= bidPrice){
            status = Status.CLOSED;
        }
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
        uint askPrice;
        uint bidPrice;
        uint actualPrice;
        (askPrice, bidPrice, actualPrice,  ,  ) = simulatePrice(now);

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
        uint takerAmountA = totalTakerAmountA*takerRateA[user]/totalTakerRateA;
        uint takerAmountB = totalTakerAmountA*takerRateB[user]/totalTakerRateB;
        amountA += takerAmountA;
        amountB += takerAmountB;
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
        require(
            status >= Status.OPEN,
            "The auction is not open yet"
        );

        uint time = sub(now, auctionSettings.info.startedTimestamp + auctionSettings.info.delaySeconds);
        // rate drops when time goes on

        rate = time*100/auctionSettings.info.T;

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



    function calcAskPrice(
        uint t
    )
        internal
        view
        returns(
            uint
        )
    {
        uint p = curve.calcAskPrice(auctionSettings.curveID, t);
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
        uint p = curve.calcBidPrice(auctionSettings.curveID, t);
        return p;
    }

    function isClosed(
        uint t1,
        uint t2
    )
        internal
        view
        returns(
            bool
        )
    {   
        uint p1 = curve.calcAskPrice(auctionSettings.curveID, t1);
        uint p2 = curve.calcBidPrice(auctionSettings.curveID, t2);
        return p1<=p2;
    }

    /// @dev Return the estimated time to end
    function getEstimatedTTL()
        public
        view
        returns(
            uint /* ttlSeconds */
        )
    {
        uint period = auctionSettings.info.T;
        
        if (status <= Status.OPEN){
            return period;
        }
        if (status > Status.CONSTRAINED){
            return 0;
        }

        uint t1 = sub(now, constrainedTime + askPausedTime);
        uint t2 = sub(now, constrainedTime + bidPausedTime);
        uint dt1;
        uint dt2;

        if (isClosed(t1,t2)){
            return 0;
        }

        uint dt = period/100;

        if (t1+t2 < period*2 - dt*2){
            dt1 = sub(period*2, t1+t2)/2;
        } 
        else{
            dt1 = dt;
        }


        while (dt1 >= dt && isClosed(t1+dt1, t2+dt1)){
            dt1 = sub(dt1, dt);
        }

        while (!isClosed(t1+dt1+dt, t2+dt1+dt)){
            dt1 = add(dt1, dt);
        }

        dt2 = add(dt1, dt);

        // now the point is between dt1 and dt2
        while (
            dt2-dt1>1 && 
            isClosed(t1+dt2, t2+dt2)
        )
        {
            uint dt3 = (dt1+dt2)/2;
            if (isClosed(t1+dt3, t2+dt3)){
                dt2 = dt3;
            }
            else{
                dt1 = dt3;
            }
        }

        return dt2;
        
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
            token == auctionSettings.tokenInfo.askToken ||
            token == auctionSettings.tokenInfo.bidToken,
            "token not correct"
        );

        if (status == Status.STARTED&&
            now >= auctionSettings.info.startedTimestamp + auctionSettings.info.delaySeconds
        )
        {
            status = Status.OPEN;
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
            feeBips = auctionSettings.feeSettings.protocolBips + auctionSettings.feeSettings.walletBipts;
        }
        realAmount = amount*(10000-feeBips)/10000;

        // 同步参数到now
        updatePrice();
        
        uint askDepositLimit;
        uint bidDepositLimit;
        uint askWithdrawLimit;
        uint bidWithdrawLimit;

        // 算上Queue的
        (askDepositLimit, bidDepositLimit, askWithdrawLimit, bidWithdrawLimit) = getLimits();

        if (token == auctionSettings.tokenInfo.askToken &&
            realAmount > askDepositLimit ||
            token == auctionSettings.tokenInfo.bidToken &&
            realAmount > bidDepositLimit
        )
        {
            return 0;
        }

        // 从treasury提取token，手续费暂时不收取，在最后结算时收取
        // 无论放在队列中，或者交易中，都视作锁仓realAmount，其余部分交手续费
        success = treasury.auctionDeposit(
            msg.sender,
            token,
            amount  // must be greater than 0.
        );

        
        // deposit时的手续费，若结束时单独收取，需要区分每一笔deposit的wallet情况
        // 对于actualPrice的计算，手续费也参与了价格的计算，可能会导致价格计算不准确
        // 针对流拍等情况，若要分离影响，需要增加数组记录手续费的情况
        /*
        if (success && feeBips>0){
            treasury.sendFee( 
                auctionSettings.feeSettings.recepient,
                msg.sender,
                token,
                amount - realAmount
            );
        }
        */

        // TODO: 处理等待队列和实际价格的变化
        


        //return amount;
        return realAmount;
    
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
        uint limit = 0;

        if (action == 1){
            limit = mul(
                sub(auctionState.askPrice, auctionState.actualPrice), 
                auctionState.totalBidAmount
                )/auctionSettings.tokenInfo.priceScale;
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
                )/auctionSettings.tokenInfo.priceScale;
        }
        
        if (action == 4){
            limit = mul(
                sub(auctionState.askPrice, auctionState.actualPrice), 
                auctionState.totalBidAmount
                )/auctionState.askPrice;
        }

        return limit;
    }

    
    function queueExchange(
        uint action,
        uint amount
    )
        internal
        returns(
            uint
        )
    {
        uint res = amount;
        // tokenA exchange queueB
        if (action == 1){
            res = mul(amount, auctionSettings.tokenInfo.priceScale)/auctionState.actualPrice;
        }
        
        // tokenB exchange queueA
        if (action == 2){
            res = mul(amount, auctionState.actualPrice)/auctionSettings.tokenInfo.priceScale;
        }

        return res;

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

        uint askQ;
        uint bidQ;

        QueuedParticipation memory q;
        

        // 1 - askDeposit
        if (action == 1){
            if (auctionState.queuedBidAmount == 0)
            {
                q.user = msg.sender;
                q.amount = amount;
                q.timestamp = now;
                askQueue.push(q);
            }
            else{
                // 要从队列中拿出的
                bidQ = mul(amount, auctionSettings.tokenInfo.priceScale)/auctionState.actualPrice;
                if (auctionState.queuedBidAmount == bidQ){
                    // 清空
                    uint len = askQueue.length;
                    while(len > 0){
                        q = bidQueue[len -1];
                        bidAmount[q.user] += q.amount;
                        len--;
                    }

                    // 双双加入

                }
                else
                {
                    //拿出部分

                    // 双双加入

                }

            }
            
            
        }

        // 2 - bidDeposit
        if (action == 2){

            if (auctionState.queuedAskAmount == 0)
            {
                q.user = msg.sender;
                q.amount = amount;
                q.timestamp = now;
                bidQueue.push(q);
            }
            else{
                // 要从队列中拿出的
                askQ = mul(amount, auctionState.actualPrice)/auctionSettings.tokenInfo.priceScale;
                if (auctionState.queuedAskAmount == askQ){
                    // 清空

                    // 双双加入

                }
                else
                {
                    //拿出部分

                    // 双双加入

                }

            }
            
        }


        // 3 - askWithdraw
        if (action == 3){
            
        }

        // 4 - bidWithdraw
        if (action == 4){
            
        }
        
    }
    
    // action   1 - askDeposit 2 - bidDeposit 3 - askWithdraw 4 - bidWithdraw
    function updateAfterAction(
        uint action,
        uint amount
    )
        internal
    {
        uint nonQueue;

        nonQueue = getLimits(action);

        uint askQueuedSup = 0;
        uint bidQueuedSup = 0;
        
        if (auctionState.queuedBidAmount > 0){
            askQueuedSup = mul(auctionState.queuedBidAmount, auctionState.actualPrice)/
                auctionSettings.tokenInfo.priceScale;
        }
        
        if (auctionState.queuedAskAmount > 0){
            bidQueuedSup = mul(auctionState.queuedAskAmount, auctionSettings.tokenInfo.priceScale)/
                auctionState.actualPrice;
        }

        // nonQueue表示不考虑queue情况下最大的存取值
        // askQueuedSup与bidQueuedSup表示“抵消掉”queue中的记录需要的值

        // 只有两种情况 1 - 没有WaitingList，多的部分会加到WaitingList中
        //            2 - 有WaitingList，必定有一个方向Pause，先抵消Pause方向队列，然后变动价格
        
        // the addtional deposit will be inserted into the queue
        uint amountQueue; // 用于更改Queue的数量
        uint amountPrice = amount; // 用于更改价格的数量
        if (action == 1){
            // 1. askQueue有，直接askQueue增加
            // 2. bidQueue有，先抵消bid，如果有剩余的进入3
            // 3. 没有排队
            // updateQueue()只处理队列的增加、减少，不改变价格

            if (auctionState.queuedAskAmount > 0){
                updateQueue(action, amount);
                amountQueue = amount;
                amountPrice = 0;
            }
            else{
                if (auctionState.queuedBidAmount > 0){
                    if (amount <= askQueuedSup){
                        updateQueue(action, amount);
                        amountQueue = amount;
                        amountPrice = 0;
                    }
                    else{
                        updateQueue(action, askQueuedSup);
                        amountQueue = askQueuedSup;
                        amountPrice = amount - askQueuedSup;
                    }
                }
            }

            if (amountPrice > 0){
                if (amountPrice <= nonQueue){
                    auctionState.totalAskAmount += amountPrice;
                    updateActualPrice();
                }
                else{
                    auctionState.totalAskAmount += nonQueue;
                    updateActualPrice();
                    updateQueue(action, amountPrice - nonQueue);
                }

            }

            
        }
        
        // the addtional deposit will be inserted into the queue
        if (action == 2){
            
            if (auctionState.queuedBidAmount > 0){
                updateQueue(action, amount);
                amountQueue = amount;
                amountPrice = 0;
            }
            else{
                if (auctionState.queuedAskAmount > 0){
                    if (amount <= bidQueuedSup){
                        updateQueue(action, amount);
                        amountQueue = amount;
                        amountPrice = 0;
                    }
                    else{
                        updateQueue(action, bidQueuedSup);
                        amountQueue = bidQueuedSup;
                        amountPrice = amount - bidQueuedSup;
                    }
                }
            }

            if (amountPrice > 0){
                if (amountPrice <= nonQueue){
                    auctionState.totalBidAmount += amountPrice;
                    updateActualPrice();
                }
                else{
                    auctionState.totalBidAmount += nonQueue;
                    updateActualPrice();
                    updateQueue(action, amountPrice - nonQueue);
                }
            }
        }

        // the addtional withdraw will hedge the queue
        // 如果bid有队列，不能取款
        // 如果ask有队列，先去ask，然后调整价格

        if (action == 3){
            if (auctionState.queuedAskAmount > 0){
                if (amount <= auctionState.queuedAskAmount){
                    updateQueue(action, amount);
                    amountQueue = amount;
                    amountPrice = 0;
                }
                else{
                    updateQueue(action, auctionState.queuedAskAmount);
                    amountQueue = auctionState.queuedAskAmount;
                    amountPrice = amount - auctionState.queuedAskAmount;
                }   
            }
            
            if (amountPrice > 0){

                // amountPrice肯定在价格限制内
                auctionState.totalAskAmount -= amountPrice;
                updateActualPrice();

            }         
        }

        // the addtional withdraw will hedge the queue
        if (action == 4){
            
            if (auctionState.queuedBidAmount > 0){
                if (amount <= auctionState.queuedBidAmount){
                    updateQueue(action, amount);
                    amountQueue = amount;
                    amountPrice = 0;
                }
                else{
                    updateQueue(action, auctionState.queuedBidAmount);
                    amountQueue = auctionState.queuedBidAmount;
                    amountPrice = amount - auctionState.queuedBidAmount;
                }   
            }
            
            if (amountPrice > 0){

                // amountPrice肯定在价格限制内
                auctionState.totalBidAmount -= amountPrice;
                updateActualPrice();

            }   
        }

    }

    function updateActualPrice()
        internal
    {
        auctionState.actualPrice = mul(
            auctionState.totalAskAmount,
            auctionState.totalBidAmount
        )/auctionSettings.tokenInfo.priceScale; 
        if (status == Status.OPEN &&
            auctionState.actualPrice <= auctionSettings.info.P*auctionSettings.info.M &&
            auctionState.actualPrice >= auctionSettings.info.P/auctionSettings.info.M
        )
        {
            status == Status.CONSTRAINED;
        }
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
            auctionSettings.info.isWithdrawalAllowed,
            "withdraw is not allowed"
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
            token == auctionSettings.tokenInfo.askToken ||
            token == auctionSettings.tokenInfo.bidToken,
            "token not correct"
        );

        
        updatePrice();
        
        uint askDepositLimit;
        uint bidDepositLimit;
        uint askWithdrawLimit;
        uint bidWithdrawLimit;

        (askDepositLimit, bidDepositLimit, askWithdrawLimit, bidWithdrawLimit) = getLimits();

        if (token == auctionSettings.tokenInfo.askToken &&
            amount > askWithdrawLimit ||
            token == auctionSettings.tokenInfo.bidToken &&
            amount > bidWithdrawLimit
        )
        {
            return 0;
        }

        // 以上检查了是否可以取款

        uint penaltyBips = auctionSettings.feeSettings.withdrawalPenaltyBips;
        uint realAmount = amount; 
        
        bool success;

        if (penaltyBips > 0){
            realAmount = realAmount - amount*penaltyBips/10000;
            treasury.sendFee(
                auctionSettings.feeSettings.recepient,
                msg.sender,
                token,
                amount - realAmount
            );
        }

        success = treasury.auctionWithdraw(
            msg.sender,
            token,
            realAmount  // must be greater than 0.
        );

        // TODO: 处理等待队列和实际价格的变化

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
        //TODO: simulate the price changes

    }

    // Try to settle the auction.
    function triggerSettle()
        external
        returns (
            bool /* settled */
        )
    {
        // TODO: settle
        return true;
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