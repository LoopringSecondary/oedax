pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;


import "../iface/ITreasury.sol";
import "./IAuctionData.sol";

contract IAuctionGenerator{



    
    function createAuction(
        address     curve,
        uint        curveId,
        uint        initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint        initialBidAmount,         // The initial amount of tokenB from the creator's account.
        IAuctionData.FeeSettings memory feeS,
        IAuctionData.TokenInfo   memory tokenInfo,
        IAuctionData.Info        memory info,
        uint        id,
        address     creator

    )
        public
        returns (
            address /* auction */
        );


}