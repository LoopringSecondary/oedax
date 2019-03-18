pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "./IAuctionData.sol";
import "./IAuctionEvents.sol";
import "./ICurve.sol";
import "./IParticipationEvents.sol";


contract IAuction is IAuctionData, ICurve, IAuctionEvents, IParticipationEvents {
    struct Participation {
        uint    index;             // start from 0
        address user;
        address token;
        int     amount;            // >= 0: deposit, < 0: withdraw
        uint    timestamp;
    }

    Participation[] public participations;        // used for recording

    address[] public users; // users participating in the auction

    // TODO(): move participationIndex into implementation
    mapping(address => int[])   private participationIndex;  // user address => index of Participation[]

    mapping(address => uint256) public totalAskAmount; // the amount of tokenA
    mapping(address => uint256) public totalBidAmount; // the amount of tokenB

    struct QueuedParticipation {
        uint    index;      // start from 0
        address user;       // user address
        uint    amount;     // amount of tokenA or tokenB
        uint    timestamp;  // time when joining the list
    }

    // At most only one waiting list (queue) can be non-empty.
    QueuedParticipation[] public askQueue;
    QueuedParticipation[] public bidQueue;

    // TODO(): 下面的5个变量我没太懂，可以聊聊，但感觉不应放到接口里面。
    // uint public indexAskWait;   // the index where the queued ask waiting list starts
    // uint public indexBidWait;   // the index where the queued bid waiting list starts

    // // 当价格曲线停在某个值P时，可以根据这个值计算出价格曲线中对应的时间点
    // // 这个时间点的计算可能存在误差，误差在precision以内
    // // 求出的时间点满足 P(t)<=P<P(t+1)，价格曲线暂停在P点.

    // uint public nPointBid;  // Actual point in price curve
    // uint public nPointAsk;  // Actual point in price curve

    // uint public lastSynTime;// same as that in auctionState

    AuctionState    public auctionState; // mutable state
    AuctionSettings public auctionInfo;  // immutable settings

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

    // TODO(): 这个方法不需要，只需要调用simulate方法就好了。
    // /// @dev Function to check whether amount of bid/ask is available
    // /// price should be "updated"(getAuctionState()) before the calculation
    // function canParticipate(
    //     int amountAsk,
    //     int amountBid
    //     )
    //     public
    //     view
    //     returns(
    //         bool /* successful */
    //     );

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
