pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

///@author Weikang Wang
///@title AuctionEvent - A contract for the events in auctions.
///@dev events to trigger in generated auctions


contract IAuctionEvents {

    event AuctionCreated(
        address indexed creator,
        uint256 indexed aucitionId,
        address indexed aucitionAddress,
        uint256         delaySeconds,
        uint256         targetPrice,
        uint256         priceScale,
        uint256         scaleFactor,
        uint256         shapeFactor,
        uint256         durationSeconds,
        bool            isWithdrawalAllowed
    );

    event AuctionOpened (
        address indexed creator,
        uint256 indexed aucitionId,
        address indexed aucitionAddress,
        uint256         openTime
    );

    event AuctionConstrained(
        address indexed creator,
        uint256 indexed aucitionId,
        address indexed aucitionAddress,
        uint256         totalAskAmount,
        uint256         totalBidAmount,
        uint256         priceScale,
        uint256         actualPrice,
        uint256         constrainedTime
    );

    event AuctionClosed(
        address indexed creator,
        uint256 indexed aucitionId,
        address indexed aucitionAddress,
        uint256         totalAskAmount,
        uint256         totalBidAmount,
        uint256         priceScale,
        uint256         closePrice,
        uint256         closeTime,
        bool            canSettle
    );

    event AuctionSettled (
        address indexed creator,
        uint256 indexed aucitionId,
        address indexed aucitionAddress,
        uint256         settleTime
    );
}