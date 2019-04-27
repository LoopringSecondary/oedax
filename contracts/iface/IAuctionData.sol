/*

  Copyright 2017 Loopring Project Ltd (Loopring Foundation).

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/
pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

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

    //sub-structs to prevent deep stack
    struct TokenInfo {
        address askToken;           // The ask (sell) token
        address bidToken;           // The bid (buy) token
        uint    askDecimals;        // Decimals of tokenA, should be read from their smart contract,
                                    // not supplied manually.
        uint    bidDecimals;        // Decimals of tokenB, should be read from their smart contract,
                                    // not supplied manually.
        uint    priceScale;         // A scaling factor to convert prices to double values,
                                    // including targetPrice, askPrice, bidPrice.
    }

    struct FeeSettings {
        address recepient;
        uint    creationFeeEth;
        uint    protocolBips;
        uint    walletBipts;
        uint    takerBips;
        uint    withdrawalPenaltyBips;
    }
    struct AuctionInfo {
        uint    P;                  // `P/priceScale` the target price
        uint    M;                  // The price scale factor
        uint    S;                  // ShapeFacor
        uint    T;                  // Duration in seconds
        uint    delaySeconds;       // The delay for open participation.
        uint    maxAskAmountPerAddr;
        uint    maxBidAmountPerAddr;
        bool    isWithdrawalAllowed;
        bool    isTakerFeeDisabled;
    }

    // The following are constant setups that never change.

    struct AuctionSettings {

        address creator;
        uint    auctionId;
        uint    curveId;
        uint    startedTimestamp;   // Timestamp when this auction is started.
    }
}
