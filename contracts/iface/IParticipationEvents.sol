pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

///@author Weikang Wang
///@title AuctionEvent - A contract for the events in auctions.
///@dev events to trigger in generated auctions


contract IParticipationEvents {

    event Deposited (
        address indexed user,
        bool            isAsk,
        uint            amount,
        uint            totalAskAmount,
        uint            totalBidAmount,
        uint            queuedAskAmount,
        uint            queuedBidAmount,
        uint            priceScale,
        uint            actualPrice,
        uint            timestamp
    );

    event Withdrawn (
        address indexed user,
        bool            isAsk,
        uint            amount,
        uint            totalAskAmount,
        uint            totalBidAmount,
        uint            queuedAskAmount,
        uint            queuedBidAmount,
        uint            priceScale,
        uint            actualPrice,
        uint            timestamp
    );

    event QueuesUpdated (
        uint            queuedAskAmount,
        uint            queuedBidAmount,
        uint            timestamp
    );

}