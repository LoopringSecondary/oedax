pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IOedax.sol";
import "../iface/ITreasury.sol";
import "../lib/Ownable.sol";
import "../lib/ERC20.sol";
import "../lib/MathLib.sol";
import "../iface/IAuctionGenerator.sol";
import "../iface/IAuction.sol";
import "../helper/DataHelper.sol";

contract ImplOedax is IOedax, Ownable, MathLib, DataHelper, IAuctionEvents, IOedaxEvents {

    ITreasury           public  treasury;
    ICurve              public  curve;
    FeeSettings         public  feeSettings;
    IAuctionGenerator   public  auctionGenerator;
    
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
        address _auctionGenerator,
        address _recepient
    )
        public
    {
        treasury = ITreasury(_treasury);
        curve = ICurve(_curve);
        auctionGenerator = IAuctionGenerator(_auctionGenerator);
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
        AuctionInfo memory info
    )
        internal
        returns (
            address /* auction */,
            uint    /* id */
        )
    {
        uint    id = treasury.getNextAuctionID();

        address auctionAddr;

        bytes memory bF;
        bytes memory bT;
        bytes memory bA;
        bF = feeSettingsToBytes(feeS);
        bT = tokenInfoToBytes(tokenInfo);
        bA = auctionInfoToBytes(info);

        auctionAddr = auctionGenerator.createAuction(
            address(curve),
            curveId,
            initialAskAmount,
            initialBidAmount,
            bF,
            bT,
            bA,
            id,
            msg.sender
        );

        bool success;
        //(success, id) = treasury.registerAuction(address(auction), msg.sender);
        (success, id) = treasury.registerAuction(auctionAddr, msg.sender);
        return (auctionAddr, id);

    }

    function checkTokenInfo(
        uint    curveId,
        address askToken,
        address bidToken,
        AuctionInfo    memory  info 
    )
        internal
        view
        returns(
            TokenInfo memory
        )
    {
        uint    askDecimals = ERC20(askToken).decimals();
        uint    bidDecimals = ERC20(bidToken).decimals();
        uint    priceScale;
        require(askDecimals <= bidDecimals && askDecimals + 18 > bidDecimals, "decimals not correct");
        priceScale = pow(10, 18 + askDecimals - bidDecimals);

        ICurve.CurveParams memory cp;

        cp = bytesToCurveParams(
            curve.getCurveBytes(curveId)
        );  

        require(
            cp.T == info.T &&
            cp.M == info.M &&
            cp.P == info.P &&
            cp.priceScale == priceScale,
            "curve does not match the auction parameters"
        ); 
                
        TokenInfo   memory _tokenInfo;

        _tokenInfo = TokenInfo(
            askToken,
            bidToken,
            askDecimals,
            bidDecimals,
            priceScale
        );  

        return _tokenInfo;
        
    }


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
        )
    {
        uint    id = treasury.auctionAmount() + 1;


        require(
            initialAskAmount == 0 ||
            true == treasury.auctionDeposit(
                msg.sender,
                askToken,
                initialAskAmount 
            ),
            "Not enough tokens!" 
        );

        require(
            initialBidAmount == 0 ||
            true == treasury.auctionDeposit(
                msg.sender,
                bidToken,
                initialBidAmount 
            ),
            "Not enough tokens!" 
        );

        FeeSettings memory feeS;
        TokenInfo   memory tokenInfo;
        
        feeS = feeSettings;
        
        tokenInfo = checkTokenInfo(
            curveId,
            askToken,
            bidToken,
            info 
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
        AuctionSettings memory _auctionSettings = bytesToAuctionSettings(
            IAuction(auctionAddr).getAuctionSettingsBytes()
        );
        AuctionState memory _auctionState = bytesToAuctionState(
            IAuction(auctionAddr).getAuctionStateBytes()
        );
        return (lastSynTime, _auctionSettings, _auctionState); 
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

        AuctionSettings memory auctionSettings = bytesToAuctionSettings(
            IAuction(auctionAddr).getAuctionSettingsBytes()
        );
        AuctionInfo memory auctionInfo = bytesToAuctionInfo(
            IAuction(auctionAddr).getAuctionInfoBytes()
        );
        TokenInfo memory tokenInfo = bytesToTokenInfo(
            IAuction(auctionAddr).getTokenInfoBytes()
        );
        FeeSettings memory feeSettings = bytesToFeeSettings(
            IAuction(auctionAddr).getFeeSettingsBytes()
        );


        auctionSettings.startedTimestamp = now;
        auctionInfo.delaySeconds = delaySeconds;
        auctionInfo.P = IAuction(auctionAddr).getActualPrice();
        
        require(
            initialAskAmount == 0 ||
            true == treasury.auctionWithdraw(
                msg.sender,
                tokenInfo.askToken,
                initialAskAmount 
            ),
            "Not enough tokens!" 
        );

        require(
            initialBidAmount == 0 ||
            true == treasury.auctionWithdraw(
                msg.sender,
                tokenInfo.bidToken,
                initialBidAmount 
            ),
            "Not enough tokens!" 
        );

        uint id;
        address addressAuction;
        (addressAuction, id) = createAuction(
            auctionSettings.curveID,
            initialAskAmount,         // The initial amount of tokenA from the creator's account.
            initialBidAmount,         // The initial amount of tokenB from the creator's account.
            feeSettings,
            tokenInfo,
            auctionInfo
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