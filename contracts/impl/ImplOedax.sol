pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IOedax.sol";
import "../iface/ITreasury.sol";
import "../lib/Ownable.sol";
import "../impl/ImplAuction.sol";
import "../lib/ERC20.sol";
import "../lib/MathLib.sol";

contract ImplOedax is IOedax, Ownable, MathLib {

    ITreasury   public  treasury;
    ICurve      public  curve;
    
    FeeSettings public  feeSettings;
    
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
    constructor(
        address _treasury,
        address _curve,
        address _recepient
    )
        public
    {
        treasury = ITreasury(_treasury);
        curve = ICurve(_curve);
        feeSettings.recepient = _recepient;
        feeSettings.creationFeeEth = 0;
        feeSettings.protocolBips = 5;
        feeSettings.walletBipts = 5;
        feeSettings.takerBips = 25;
        feeSettings.withdrawalPenaltyBips = 250;
    }
    
    
    
        // Initiate an auction
    function createAuction(
        uint        curveId,
        uint        initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint        initialBidAmount,         // The initial amount of tokenB from the creator's account.
        FeeSettings memory feeS,
        TokenInfo   memory tokenInfo,
        Info        memory info

    )
        internal
        returns (
            address /* auction */,
            uint    /* id */
        )
    {
        uint    id = treasury.getNextAuctionID();

        ImplAuction auction = new ImplAuction(
            address(this),
            address(treasury), 
            address(curve),
            curveId,
            initialAskAmount,
            initialBidAmount,
            feeS,
            tokenInfo,
            info,
            id,
            msg.sender
        );

        bool success;
        (success, id) = treasury.registerAuction(address(auction), msg.sender);
        return (address(auction), id);

    }

    // Initiate an auction
    function createAuction(
        uint    delaySeconds,
        uint    curveId,
        address askToken,
        address bidToken,
        uint    P,  // target price
        uint    M,  // prixce factor
        uint    T,  // duration
        uint    initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint    initialBidAmount,         // The initial amount of tokenB from the creator's account.
        uint    maxAskAmountPerAddr,      // The max amount of tokenA per address, 0 for unlimited.
        uint    maxBidAmountPerAddr,      // The max amount of tokenB per address, 0 for unlimited.
        bool    isWithdrawalAllowed,
        bool    isTakerFeeDisabled      // Disable using takerBips
    )
        external
        returns (
            address /* auction */,
            uint    /* id */
        )
    {
        uint    id = treasury.auctionAmount() + 1;
        uint    askDecimals = ERC20(askToken).decimals();
        uint    bidDecimals = ERC20(bidToken).decimals();
        uint    priceScale;
        require(askDecimals <= bidDecimals && askDecimals + 18 > bidDecimals, "decimals not correct");
        priceScale = pow(10, 18 + askDecimals - bidDecimals);
        
        ICurve.CurveParams memory cp;
        cp = curve.getCurveByID(curveId);   

        require(
            cp.T == T &&
            cp.basicParams.M == M &&
            cp.P == P &&
            cp.priceScale == priceScale,
            "curve does not match the auction parameters"
        );     
  

        require(
            true == treasury.auctionWithdraw(
                msg.sender,
                askToken,
                initialAskAmount 
            ),
            "Not enough tokens!" 
        );

        require(
            true == treasury.auctionWithdraw(
                msg.sender,
                bidToken,
                initialBidAmount 
            ),
            "Not enough tokens!" 
        );

        FeeSettings memory feeS;
        TokenInfo   memory tokenInfo;
        Info        memory info;
        
        feeS = feeSettings;
        
        tokenInfo = TokenInfo(
            askToken,
            bidToken,
            askDecimals,
            bidDecimals,
            priceScale
        );
 
        info = Info(
            P,
            M,
            T,
            now,
            delaySeconds,
            maxAskAmountPerAddr,
            maxBidAmountPerAddr,
            isWithdrawalAllowed,
            isTakerFeeDisabled
        );

        address addressAuction;
        (addressAuction, id) = createAuction(
            curveId,
            initialAskAmount,         // The initial amount of tokenA from the creator's account.
            initialBidAmount,         // The initial amount of tokenB from the creator's account.
            feeS,
            tokenInfo,
            info
        );

        return (addressAuction, id);

    }


    function getAuctionInfo(uint id)
        external
        view
        returns (
            uint,
            AuctionSettings memory,
            AuctionState    memory
        )
    {
        address auctionAddr;
        auctionAddr = treasury.auctionIdMap(id);
        uint    lastSynTime = IAuction(auctionAddr).lastSynTime();
        AuctionSettings memory aucInfo = IAuction(auctionAddr).getAuctionSettings(); 
        AuctionState memory aucState = IAuction(auctionAddr).getAuctionState();
        return (lastSynTime, aucInfo, aucState); 
    }

    
    
    function getAuctionsAll(
        address creator
    )
        public
        view
        returns (
            uint /*  count */, 
            uint[] memory /* auction index */
        )
    {

        uint[] memory index = treasury.getAuctionIndex(creator);
        
        uint len = index.length;

        return (len, index);        

    }

    
    function getAuctions(
        address creator,
        Status status
    )
        external
        view
        returns (
            uint /*  count */, 
            uint[] memory /* auction index */
        )
    {

        uint len;
        uint[] memory index;
        (len,index) = getAuctionsAll(creator);
        
        address auctionAddr;

        uint count = 0;

        for (uint i = 0; i < len; i++){
            auctionAddr = treasury.auctionIdMap(index[i]);
            if (IAuction(auctionAddr).status() == status){
                count++;
            }
        }

        uint[] memory res = new uint[](count);

        count = 0;
        for (uint i = 0; i < len; i++){
            auctionAddr = treasury.auctionIdMap(index[i]);
            if (IAuction(auctionAddr).status() == status){
                res[count] = index[i];
                count++;
            }
        }

        return (count, res);        

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
            uint[] memory /* auction index */
        )
    {

        uint len;
        uint[] memory index;
        (len,index) = getAuctionsAll(creator);
        
        address auctionAddr;

        uint cnt = 0;

        for (uint i = 0; i < len; i++){
            auctionAddr = treasury.auctionIdMap(index[i]);
            if (
                index[i] > skip &&
                index[i] <= add(skip, count) &&
                IAuction(auctionAddr).status() == status
            )
            {
                cnt++;
            }
        }

        uint[] memory res = new uint[](count);

        if (cnt>0){
            cnt = 0;
            for (uint i = 0; i < len; i++){
                auctionAddr = treasury.auctionIdMap(index[i]);
                if (
                    index[i] > skip &&
                    index[i] <= add(skip, count) &&
                    IAuction(auctionAddr).status() == status
                ){
                    res[cnt] = index[i];
                    cnt++;
                }
            }
        }   

        return res;     
    }

    // /@dev clone an auction from existing auction using its id
    function cloneAuction(
        uint auctionID,
        uint delaySeconds,
        uint initialAskAmount,
        uint initialBidAmount
        )
        public
        returns(
            address /* auction */,
            uint    /* id */,
            bool    /* successful */
        )
    {
        address auctionAddr;
        auctionAddr = treasury.auctionIdMap(auctionID);
        require(
            auctionAddr != address(0x0),
            "auction not correct!"    
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
        returns(
            address /* auction */,
            uint    /* id */,
            bool    /* successful */
        )
    {
        require(
            now - IAuction(auctionAddr).lastSynTime() <= 7 days,
            "auction should be closed less than 7 days ago"
        );    
        require(
            IAuction(auctionAddr).status() >= Status.CLOSED,
            "only closed auction can be cloned!" 
        );

        AuctionSettings memory auctionSettings = IAuction(auctionAddr).getAuctionSettings();

        auctionSettings.info.startedTimestamp = now;
        auctionSettings.info.delaySeconds = delaySeconds;
        auctionSettings.info.P = IAuction(auctionAddr).getActualPrice();
        
        uint id;
        address addressAuction;
        (addressAuction, id) = createAuction(
            auctionSettings.curveID,
            initialAskAmount,         // The initial amount of tokenA from the creator's account.
            initialBidAmount,         // The initial amount of tokenB from the creator's account.
            auctionSettings.feeSettings,
            auctionSettings.tokenInfo,
            auctionSettings.info
        );

        return (addressAuction, id, true);

    }





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
        external
        onlyOwner
    {
        feeSettings.recepient = recepient;
        feeSettings.creationFeeEth = creationFeeEth;
        feeSettings.protocolBips = protocolBips;
        feeSettings.walletBipts = walletBipts;
        feeSettings.takerBips = takerBips;
        feeSettings.withdrawalPenaltyBips = withdrawalPenaltyBips;
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
        revert();
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
        revert();
    }

    function getCurves(
        )
        external
        view
        returns (
            address[] memory /* curves */
        )
    {
        revert();
    }
    
        
}