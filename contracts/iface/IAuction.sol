pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "./IData.sol";


contract IAuction is IData {
    struct Participation {
        uint    index;             // start from 0
        address user;
        address token;
        int     amount;            // >= 0: deposit, < 0: withdraw
        uint    timestamp;
    }

    struct Participant {
        address  user;
        uint     amountA;
        int      avgTokenAFeeBips;    // < 0 means rebate.
        uint     amountB;
        int      avgTokenBFeeBips;    // < 0 means rebate.
    }

    function deposit(
        address user,
        address wallet, // set this to 0x0 will avoid paying wallet fees. Note only deposit has fee.
        address token,
        uint    amount)
        public
        returns (
            bool successful
        );

    function withdraw(
        address user,
        address token,
        uint    amount)
        public
        returns (
            bool successful
        );

    function simulateDeposit(
        address user,
        address token,
        uint    amount)
        public
        view
        returns (
            bool successful,
            AuctionState memory state
        );

    function simulateWithdrawal(
        address user,
        address token,
        uint    amount)
        public
        view
        returns (
            bool successful,
            AuctionState memory state
        );

    // Try to settle the auction.
    function settle()
        external
        returns (
            bool successful
        );

    // Start a new aucton with the same parameters except the P and the delaySeconds parameter.
    // The new P parameter would be the settlement price of this auction.
    function clone(
        uint delaySeconds,
        uint initialAmountA, // The initial amount of tokenA from the creator's account.
        uint initialAmountB
    ) // The initial amount of tokenB from the creator's account.
        external
        returns (
            address auction,
            uint id
        );

    function getAuctionInfo()
        external
        view
        returns (
            AuctionInfo memory
        );

    // If this function is too hard/costy to do, we can remove it.
    function getParticipations(
        uint skip,
        uint count
    )
        external
        view
        returns (
            Participation[] memory participations,
            uint total
        );

    // If this function is too hard/costy to do, we can remove it.
    function getParticipants(
        uint skip,
        uint count
    )
        external
        view
        returns (
            Participant[] memory participants,
            uint total
        );
}
