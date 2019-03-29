pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;


contract ITreasury {


    
    
    // user => (token => amount)
    mapping (address => mapping (address => uint)) userTotalBalances;

    // user => (token => amount)
    mapping (address => mapping (address => uint)) userAvailableBalances;

    // user => (auction_id => （token => amount))
    mapping (address => mapping (uint => mapping (address => uint))) userLockedBalances;


    mapping (uint => address) public auctionIdMap;
    mapping (address => uint) public auctionAddressMap;
    mapping (address => uint[]) public auctionCreatorMap; // for the need of getAuctions() in Oedax contract

    uint  public  auctionAmount;

    // auction => token => amount
    // treasury中的token交易需要总量不变，数量变化都有来源
    // contractLockedBalances用于存储总量，不代表可以提币数量
    mapping (address => mapping(address => uint)) public contractLockedBalances;

    function getAuctionIndex(
        address creator
    )
        public
        view
        returns (
            uint[] memory
        );

    function getNextAuctionID()
        public
        returns (
            uint /* auctionID */
        );



    function exchangeTokens(
        address recepient,
        address user,
        address tokenA,
        address tokenB,
        uint    amountA,
        uint    amountB
    )
        external
        returns(
            bool
        );

    function sendFee(
        address recepient,
        address user,
        address token,
        uint    amount
    )
        external
        returns(
            bool
        );

    //between treasury contract and auction contract
    function auctionDeposit(
        address user,
        address token,
        uint    amount  // must be greater than 0.
    )
        external
        returns (
            bool /* successful */
        );

    //between treasury contract and auction contract
    function auctionWithdraw(
        address user,
        address token,
        uint    amount  // specify 0 to withdrawl as much as possible.
    )
        external
        returns (
            bool /* successful */
        );

    //between treasury contract and token contract
    function deposit(
        address token,
        uint    amount  // must be greater than 0.
    )
        external
        returns (
            bool /* successful */
        );

    //between treasury contract and token contract
    function withdraw(
        address token,
        uint    amount  // specify 0 to withdrawl as much as possible.
    )
        external
        returns (
            bool /* successful */
        );

    function getBalance(
        address user,
        address token
    )
        external
        view
        returns (
            uint /* total */,
            uint /* available */,
            uint /* locked */
        );

    function getApproval(
        address user,
        address token
    )
        public
        view
        returns (
            uint /* balance */,
            uint /* approval */
        );

    // id increases automatically
    function registerAuction(
        address auction,
        address creator
    )
        external
        returns (
            bool /* successful */,
            uint /*   id      */
        );


    // In case of a high-risk bug, the admin can return all tokens, including those locked in
    // active auctions, to their original owners.
    // If this function is called, all invocation from any on-going auctions will fail, but all
    // users' asset will be safe.
    // This method can only be called once.
    function terminate() external;


    function withdrawWhenTerminated(
        address[] calldata tokens
    )
        external;

    function isTerminated()
        external
        returns (
            bool /* terminated */
        );
}
