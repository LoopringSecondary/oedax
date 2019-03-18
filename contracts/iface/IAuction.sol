pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "./IData.sol";
import "./ICurve.sol";

contract IAuction is IData, ICurve {
    struct Participation {
        uint    index;             // start from 0
        address user;
        address token;
        int     amount;            // >= 0: deposit, < 0: withdraw
        uint    timestamp;
    }



    Participation[] public participations;      // used for recording
    
    address[] public users; // users participating in the auction

    mapping(address=>int[]) public indexP;      // index of user participation, user address => index of Participation[]
    
    mapping(address=>uint256) public askWallet; // the amount of tokenA
    mapping(address=>uint256) public bidWallet; // the amount of tokenB

    struct QueuedParticipation {
        uint    index;      // start from 0
        address user;       // user address
        uint    amount;     // amount of tokens
        uint    timestamp;  // time when joining the list
    }
    
    QueuedParticipation[] public askWaitingList;    // record the ask waiting list 
    QueuedParticipation[] public bidWaitingList;    // record the bid waiting list 
    uint public indexAskWait;   // the index where the pending ask waiting list starts 
    uint public indexBidWait;   // the index where the pending bid waiting list starts

    // 当价格曲线停在某个值P时，可以根据这个值计算出价格曲线中对应的时间点
    // 这个时间点的计算可能存在误差，误差在precision以内
    // 求出的时间点满足P(t)<=P<P(t+1)，价格曲线暂停在P点
    uint public nPointBid;  // Actual point in price curve
    uint public nPointAsk;  // Actual point in price curve
    
    uint public lastSynTime;// same as that in auctionState

    AuctionState public auctionState; // price read/update in this struct
    
    AuctionInfo public auctionInfo; // static info of the auction

    /// @dev Update actual pricce and ask/bid price from synTime
    function updatePrice() internal;

    /// @dev Add bid to waiting list
    function addBidWailtingList(
        address user,
        uint amount
        )
        internal
        returns(
            bool successful
        );

    /// @dev Add ask to waiting list
    function addAskWailtingList(
        address user,
        uint amount
        )
        internal
        returns(
            bool successful
        );

    /// @dev Remove objects in waiting list and add to the pool
    function clearWaitingList(
        uint indexAsk,
        uint indexBid
        )
        internal;

    /// @dev Calculate Limits of asking/biding
    function calLimit() 
        public
        view
        returns(
            uint   asksDepositLimit,
            uint   bidsDepositLimit,
            uint   asksWithdrawalLimit,
            uint   bidsWithdrawalLimit   
        );

    /// @dev Calculate estimated time to end
    function calEstimatedTTL() 
        public
        view
        returns(
            uint estimatedTTLSecond
        );


    /// @dev Function to check whether amount of bid/ask is available
    /// price should be "updated"(getAuctionState()) before the calculation
    function canParticipate(
        int amountAsk,
        int amountBid
        )
        public
        view
        returns(
            bool successful
        );

    function askDeposit(
        uint    amount,
        address wallet // compatible with 0x0
        )
        public
        returns (
            bool successful
        );


    function bidDeposit(
        uint    amount,
        address wallet // compatible with 0x0
        )
        public
        returns (
            bool successful
        );



    function askWithdraw(
        uint    amount)
        public
        returns (
            bool successful
        );


    function bidWithdraw(
        uint    amount)
        public
        returns (
            bool successful
        );


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

    // function only works within a block
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

    // function only works within a block
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
    // Function should be only called from Oedax main contract, as an interface
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

    // Auction states updates continuously, auction info is static
    // It would be better to seperate them
    function getAuctionInfo()
        external
        view
        returns (
            AuctionInfo memory
        );

    /// @dev Get Auction State（simulated & updated）
    function getAuctionState()
        external
        view
        returns (
            AuctionState memory
        );

    /// @dev Get Participations from an address
    function getParticipations(
        address user
    )
        external
        view
        returns (
            Participation[] memory participations,
            uint total
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


}
