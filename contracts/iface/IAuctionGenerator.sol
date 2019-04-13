pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;


import "./IAuctionData.sol";

contract IAuctionGenerator is IAuctionData{



    
    function createAuction(
        address     curve,
        uint        curveId,
        uint        initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint        initialBidAmount,         // The initial amount of tokenB from the creator's account.
        bytes   memory feeS,
        bytes   memory tokenInfo,
        bytes   memory info,
        uint        id,
        address     creator

    )
        public
        returns (
            address /* auction */
        );


}