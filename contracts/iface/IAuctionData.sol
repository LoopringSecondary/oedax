pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "./ICurve.sol";

contract IAuctionData {
    
    // Two possible paths:
    // 1):STARTED -> CONSTRAINED -> CLOSED
    // 2):STARTED -> CONSTRAINED -> CLOSED -> SETTLED
    // 3):SCHEDULED -> STARTED -> CONSTRAINED -> CLOSED
    // 4):SCHEDULED -> STARTED -> CONSTRAINED -> CLOSED -> SETTLED
    // It is also possible for the auction to jump right into the CONSTRAINED status from
    // STARTED.
    // When we say an auction is active or ongoing, it means the auction's status
    // is either STARTED or CONSTRAINED.
    enum Status {
        STARTED,        // Started but not ready for participation.
        OPEN,           // Started with actual price out of bid/ask curves
        CONSTRAINED,    // Actual price in between bid/ask curves
        CLOSED,         // Ended without settlement
        SETTLED         // Ended with settlement
    }
    
    struct AuctionState {
        // The following are state information that changes while the auction is still active.
        Status  status;

        uint    askPrice;           // The current ask/sell price curve value
        uint    bidPrice;           // The current bid/buy price curve value
        uint    actualPrice;        // Calculated according to asks and bids
        uint    totalAskAmount;     // the total asks or tokenA
        uint    totalBidAmount;     // The total bids or tokenB
        uint    estimatedTTLSeconds;// Estimated time in seconds that this auction will end.

        // The actual price should be cauclated using tokenB as the quote token.
        // actualPrice = (asks / pow(10, decimalsA) ) / (bids/ pow(10, decimalsB) )
        // If bids == 0, returns -1(?) in indicate infinite or undefined.

        // Waiting list. Note at most one of the following can be non-zero.
        uint    queuedAskAmount;        // The total amount of asks in the waiting list.
        uint    queuedBidAmount;        // the total amount of bids in the waiting list.

        // Deposit & Withdrawal limits. Withdrawal limit should be 0 if withdrawal is disabled;
        // deposit limit should put waiting list in consideration.
        uint    askDepositLimit;
        uint    bidDepositLimit;
        uint    askWithdrawalLimit;
        uint    bidWithdrawalLimit;
    }

    struct AuctionSettings {
        // Fee settings copied from IOedax
        uint    creationFeeEth;
        uint    protocolBips;
        uint    walletBipts;
        uint    rebateBips;
        uint    withdrawalPenaltyBips;

        // The following are constant setups that never change.
        int64   id;                 // 0-based ever increasing id
        uint    startedTimestamp;   // Timestamp when this auction is started.
        uint    delaySeconds;       // The delay for open participation.
        address creator;            // The one crated this auction.
        address askToken;           // The ask (sell) token
        address bidToken;           // The bid (buy) token
        uint    askDecimals;        // Decimals of tokenA, should be read from their smart contract,
                                    // not supplied manually.
        uint    bidDecimals;        // Decimals of tokenB, should be read from their smart contract,
                                    // not supplied manually.
        uint    priceScale;         // A scaling factor to convert prices to double values,
                                    // including targetPrice, askPrice, bidPrice.
        uint    P;                  // `P/priceScale` the target price
        uint    M;                  // The price scale factor
        uint    T;                  // Duration in seconds

        uint    maxAskAmountPerAddr;
        uint    maxBidAmountPerAddr;

        bool    isWithdrawalAllowed;
        bool    isTakerFeeDisabled;

        // selected curve, the curve does not change
        // all the infos above decides the curve
        ICurve  curve;
    }
}
