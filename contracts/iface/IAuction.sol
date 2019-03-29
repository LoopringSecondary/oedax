pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "./IAuctionData.sol";
import "./IAuctionEvents.sol";
import "./IParticipationEvents.sol";


contract IAuction is IAuctionData, IAuctionEvents, IParticipationEvents {
    struct Participation {
        uint    index;             // start from 0
        address user;
        address token;
        int     amount;            // >= 0: deposit, < 0: withdraw
        uint    timestamp;
    }

    Participation[] public participations;        // used for recording

    address[] public users; // users participating in the auction


    // 拍卖过程中交互的逻辑：
    // 1. 用户Deposit X个 tokenA
    // 2. X中，一部分作为固定的fee给recepient，一部分作为takerFee，剩下的参与
    // 3. 拍卖过程中提取，一部分作为penalty，剩下的返回钱包
    // 4. 拍卖全部结束，有效的总TokenA与TokenB作为兑换价格依据
    // 过程中要求，TokenA与TokenB与实际兑换时总量一致
    // 紧急terminate时，可以全部提出Token，仅扣除给recepient的，takerFee从简结算

    // userTotalBalances = userAvailableBalances + ∑userLockedBalances 需要始终满足
    // 简化逻辑，拍卖过程中的fee结算，仅在auction合约中记录，拍卖结束后整体进行结算
    // 只有10%的固定Fee在Deposit时直接入账recepient
    // 25%的takerFee暂存至auction合约中，结束后进行再分配
    // 合约结束后，用户lock的部分根据auction合约计算，在tokenA与tokenB中结算
    // 中途退出时，takeFee不退还，但是takerRateA按比例扣除

    // totalAskAmount = ∑askAmount + totalTakerAmountA
    // totalRecipientAmountA 在 Deposit 时扣除，放入recipient账户

    mapping(address => uint256) public askAmount; // the amount of tokenA
    mapping(address => uint256) public bidAmount; // the amount of tokenB

  
    mapping(address => uint256) public takerRateA;
    mapping(address => uint256) public takerRateB;

    // clear to sync with oedax/treasury
    mapping(address => uint256) public oedaxLockedA;
    mapping(address => uint256) public oedaxLockedB;

    mapping(address => bool) public isSettled;

    uint public totalRecipientAmountA;
    uint public totalRecipientAmountB;

    uint public totalTakerRateA;
    uint public totalTakerRateB;

    uint public totalTakerAmountA;
    uint public totalTakerAmountB;


    
    
    struct QueuedParticipation {
        //uint    index;      // start from 0, queue会实时清空，index没有必要
        address user;       // user address
        uint    amount;     // amount of tokenA or tokenB
        uint    timestamp;  // time when joining the list
    }

    // At most only one waiting list (queue) can be non-empty.
    QueuedParticipation[] public askQueue;
    QueuedParticipation[] public bidQueue;


    Status  public  status;
    uint    public  constrainedTime;// time when entering constrained period
    uint    public  lastSynTime;// same as that in auctionState

    AuctionState    public auctionState; // mutable state
    AuctionSettings public auctionSettings;  // immutable settings

    
    function calcActualTokens(address user)
        public
        view
        returns(
            uint,
            uint
        );


    function calcTakeRate()
        public
        view
        returns(
            uint /* rate */
        );


    function getAuctionSettings()
        public
        view
        returns(
            AuctionSettings memory
        );
    
    function getAuctionState()
        public
        view
        returns(
            AuctionState memory
        );

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
        //address user,
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
        //address user,
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
    
    // cannot clone itself
    /*
    function clone(
        uint delaySeconds,
        uint initialAskAmount, // The initial amount of tokenA from the creator's account.
        uint initialBidAmount
    ) // The initial amount of tokenB from the creator's account.
        external
        returns (
            address,
            uint
        );
    */

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
