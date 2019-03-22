pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IAuction.sol";


contract ImplAuction is IAuction {

    mapping(address => int[])   private participationIndex;  // user address => index of Participation[]

    uint private askPausedTime;//time on askCurve = now-contrainedTime-askPausedTime
    uint private bidPausedTime;//time on bidCurve = now-contrainedTime-bidPausedTime

    

    /// @dev Return the ask/bid deposit/withdrawal limits. Note that existing queued items should
    /// be considered in the calculations.
    function getLimits()
        public
        view
        returns(
            uint /* askDepositLimit */,
            uint /* bidDepositLimit */,
            uint /* askWithdrawalLimit */,
            uint /* bidWithdrawalLimit */
        );

    /// @dev Return the estimated time to end
    function getEstimatedTTL()
        public
        view
        returns(
            uint /* ttlSeconds */
        );



    /// @dev Make a deposit and returns the amount that has been /* successful */ly deposited into the
    /// auciton, the rest is put into the waiting list (queue).
    /// Set `wallet` to 0x0 will avoid paying wallet a fee. Note only deposit has fee.
    function deposit(
        address user,
        address wallet,
        address token,
        uint    amount)
        public
        returns (
            uint /* amount */
        );

    /// @dev Request a withdrawal and returns the amount that has been /* successful */ly withdrawn from
    /// the auciton.
    function withdraw(
        address user,
        address token,
        uint    amount)
        public
        returns (
            uint /* amount */
        );

    // function only works within a block
    function simulateDeposit(
        address user,
        address token,
        uint    amount)
        public
        view
        returns (
            uint /* amount */,
            AuctionState memory
        );

    /// @dev Simulate a withdrawal operation and returns the post-withdrawal state.
    function simulateWithdrawal(
        address user,
        address token,
        uint    amount)
        public
        view
        returns (
            uint /* amount */,
            AuctionState memory
        );

    // Try to settle the auction.
    function triggerSettle()
        external
        returns (
            bool /* settled */
        );

    // Start a new aucton with the same parameters except the P and the delaySeconds parameter.
    // The new P parameter would be the settlement price of this auction.
    // Function should be only called from Oedax main contract, as an interface
    function clone(
        uint delaySeconds,
        uint initialAskAmount, // The initial amount of tokenA from the creator's account.
        uint initialBidAmount
    ) // The initial amount of tokenB from the creator's account.
        external
        returns (
            address /* auction */,
            uint /* id */
        );

    /// @dev Get participations from a given address.
    function getUserParticipations(
        address user
    )
        external
        view
        returns (
            uint /* total */,
            Participation[] memory
        );

    /// @dev Returns a sub-sequence of participations.
    function getParticipations(
        uint skip,
        uint count
    )
        external
        view
        returns (
            uint /* total */,
            Participation[] memory
        );
}