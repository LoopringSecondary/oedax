pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IAuction.sol";
import "../iface/ITreasury.sol";
import "../iface/IOedax.sol";
import "../lib/MathLib.sol";
import "../iface/ICurve.sol";

contract ImplAuction is IAuction, MathLib{


    mapping(address => uint[])   private participationIndex;  // user address => index of Participation[]

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
        
    
        
        uint askDepositLimit = 0;
        uint bidDepositLimit = 0;
        uint askWithdrawLimit = 0;
        uint bidWithdrawLimit = 0;
        
        if (actualPrice >= bidPrice){
            bidDepositLimit = mul((actualPrice - bidPrice), _bid)/bidPrice;
            askWithdrawLimit = mul((actualPrice - bidPrice), _bid);
        }

        if (actualPrice <= askPrice){
            askDepositLimit = mul((askPrice - actualPrice), _bid);
            bidWithdrawLimit = mul((askPrice - actualPrice), _bid)/askPrice;
        }

        return (
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
            uint askPrice,
            uint bidPrice,
            uint actualPrice
        )
    {
        require(
            time >= lastSynTime,
            "time should not be earlier than lastSynTime"
        );

        // TODO: simulate curve price to now

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
        (askPrice, bidPrice, actualPrice) = simulatePrice(now);

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
            ask,
            bid + auctionState.queuedBidAmount,
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



    /// @dev Make a deposit and returns the amount that has been /* successful */ly deposited into the
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
        success = treasury.auctionDeposit(
            msg.sender,
            token,
            amount  // must be greater than 0.
        );
        if (success && feeBips>0){
            treasury.sendFee(
                auctionSettings.feeSettings.recepient,
                msg.sender,
                token,
                amount - realAmount
            );
        }
        
        // TODO: update price & waiting list in auction contract

        return realAmount;
    
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
            amount > 0,
            "amount should not be 0"
        );

        require(
            token == auctionSettings.tokenInfo.askToken ||
            token == auctionSettings.tokenInfo.bidToken,
            "token not correct"
        );

        

        // TODO: check whether the user can withdraw
        

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

        // TODO: update price

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