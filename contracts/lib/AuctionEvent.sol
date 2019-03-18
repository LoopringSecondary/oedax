pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

///@author Weikang Wang
///@title AuctionEvent - A contract for the events in auctions.
///@dev events to trigger in generated auctions


contract AuctionEvent{
    
    event AskDeposited(
        address indexed user,
        uint256         askAmount,
        uint256         totalAsk,
        uint256         totalBid,
        uint256         actualPrice,
        uint256         timestamp
    );

    event BidDeposited(
        address indexed user,
        uint256         bidAmount,
        uint256         totalAsk,
        uint256         totalBid,
        uint256         actualPrice,
        uint256         timestamp
    );



    event AskWithdrawn(
        address indexed user,
        uint256         askAmount,
        uint256         totalAsk,
        uint256         totalBid,
        uint256         actualPrice,
        uint256         timestamp
    );

    event BidWithdrawn(
        address indexed user,
        uint256         bidAmount,
        uint256         totalAsk,
        uint256         totalBid,
        uint256         actualPrice,
        uint256         timestamp
    );

    event UpdateWaitingList(
        uint256 totalAsk,
        uint256 totalBid,
        uint256 timestamp
    );


    event AuctionStarted(
        address indexed owner,
        uint256         createTime,
        uint256         openTime,
        uint256         targetPrice,
        uint256         priceScale,
        uint256         scaleFactor,
        uint256         shapeFactor,
        uint256         durationSeconds,
        bool            isWithdrawnalAllowed
    );

    event AuctionConstrained(
        uint256 constrainedTime,
        uint256 estimateEndTime
    );

    event AuctionClosed(
        uint256 endTime,
        uint256 finalPrice
    );

    event AuctionSettled(
        uint256 timestamp
    );


}