pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

///@author Weikang Wang
///@title OedaxEvent - A contract for the events in Oedax contract.
///@dev events to trigger in Oedax contract.


contract OedaxEvent{
    
    event AuctionCreated(
        address indexed creator,
        uint256 indexed aucitionID,
        address indexed aucitionAddress,
        uint256         openTime,
        uint256         targetPrice,
        uint256         priceScale,
        uint256         scaleFactor,
        uint256         shapeFactor,
        uint256         durationSeconds,
        bool            isWithdrawalAllowed
    );

    event AuctionConstrained(
        address indexed creator,
        uint256 indexed aucitionID,
        address indexed aucitionAddress,
        uint256         constrainedTime,
        uint256         estimateEndTime
    );

    event AuctionClosed(
        address indexed creator,
        uint256 indexed aucitionID,
        address indexed aucitionAddress,
        uint256         closeTime,
        uint256         finalPrice
    );

    event AuctionFeeUpdated(
        address indexed recepient,
        uint256         creationFeeEth,
        uint256         protocolBips,
        uint256         walletBipts,
        uint256         takerBips,
        uint256         withdrawalPenaltyBips,
        uint256         timestamp
    );


}