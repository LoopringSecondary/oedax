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

import "./IAuctionData.sol";
//import "./IAuctionEvents.sol";
import "./IParticipationEvents.sol";

contract IAuction is IAuctionData {
    struct Participation {
        uint    index;             // start from 0
        address user;
        address token;
        int     amount;            // >= 0: deposit, < 0: withdraw
        uint    timestamp;
    }

    Participation[] public participations;        // used for recording

    address[] public users; // users participating in the auction

    mapping(address => bool) public userParticipated;

    // 拍卖过程中交互的逻辑：
    // 1. 用户Deposit时，一部分作为takerFee，剩下的参与拍卖
    // 2. 拍卖过程中withdraw，一部分作为penalty，剩下的返回钱包
    // 3. 拍卖全部结束，有效的总TokenA与TokenB作为兑换价格依据

    // userTotalBalances = userAvailableBalances + ∑userLockedBalances 需要始终满足
    // 简化逻辑，拍卖过程中的fee结算，仅在auction合约中记录，拍卖结束后整体进行结算
    // 只有10%的固定Fee在Deposit时直接入账recepient
    // 25%的takerFee暂存至auction合约中，结束后进行再分配
    // 合约结束后，用户lock的部分根据auction合约计算，在tokenA与tokenB中结算
    // 中途退出时，takeFee不退还，但是takerRateA按比例扣除
    // totalAskAmount = ∑askAmount + totalTakerAmountA

    mapping(address => uint256) public askAmount; // the amount of tokenA
    mapping(address => uint256) public bidAmount; // the amount of tokenB

    mapping(address => uint256) public takerRateA;
    mapping(address => uint256) public takerRateB;

    // clear to sync with oedax/treasury

    uint public totalTakerRateA;
    uint public totalTakerRateB;

    //uint public totalTakerAmountA;
    //uint public totalTakerAmountB;

    mapping(address => bool) public isSettled;

    //mapping(address => uint256) public oedaxLockedA;
    //mapping(address => uint256) public oedaxLockedB;

    uint public totalRecipientAmountA;
    uint public totalRecipientAmountB;

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
    AuctionInfo     public auctionInfo;
    TokenInfo       public tokenInfo;
    FeeSettings     public feeSettings;

    function simulatePrice(uint time)
        public
        view
        returns (
            uint askPrice,
            uint bidPrice,
            uint actualPrice,
            uint askPausedTime,
            uint bidPausedTime
        );

    function updatePrice() public;

    /*
    // 0 - no queue
    // 1 - ask queue
    // 2 - bid queue
    // 3 - impossible
    function getQueueStatus()
        public
        view
        returns (
            uint queueStatus,
            uint amount
        );
*/
    function getActualPrice()
        public
        view
        returns (
            uint price
        );

    // 结算包括Taker奖励后的Token数量
    function calcActualTokens(address user)
        public
        view
        returns (
            uint,
            uint
        );

    // taker指数，随时间减少
    function calcTakeRate()
        public
        view
        returns (
            uint /* rate */
        );

    function getAuctionSettingsBytes()
        public
        view
        returns (
            bytes memory
        );

    function getAuctionStateBytes()
        public
        view
        returns (
            bytes memory
        );

    function getAuctionInfoBytes()
        public
        view
        returns (
            bytes memory
        );

    function getTokenInfoBytes()
        public
        view
        returns (
            bytes memory
        );

    function getFeeSettingsBytes()
        public
        view
        returns (
            bytes memory
        );

    /// @dev Return the ask/bid deposit/withdrawal limits. Note that existing queued items should
    /// be considered in the calculations.
    function getLimits()
        public
        view
        returns (
            uint /* askDepositLimit */,
            uint /* bidDepositLimit */,
            uint /* askWithdrawalLimit */,
            uint /* bidWithdrawalLimit */
        );

    /// @dev Return the estimated time to end
    function getEstimatedTTL()
        public
        view
        returns (
            uint /* ttlSeconds */
        );

    function askDeposit(uint amount)
        public
        returns (
            uint
        );

    function bidDeposit(uint amount)
        public
        returns (
            uint
        );

/*

    function askWithdraw(uint amount
        )
        public
        returns (
            uint
        );

    function bidWithdraw(uint amount
        )
        public
        returns (
            uint
        );

*/

    /// @dev Make a deposit and returns the amount that has been /* successful */ly deposited into the
    /// auciton, the rest is put into the waiting list (queue).
    /// Set `wallet` to 0x0 will avoid paying wallet a fee. Note only deposit has fee.
    function deposit(
        //address user,
        address wallet,
        address token,
        uint    amount
        )
        public
        returns (
            uint /* amount */
        );

    /// @dev Request a withdrawal and returns the amount that has been /* successful */ly withdrawn from
    /// the auciton.
    function withdraw(
        //address user,
        address token,
        uint    amount
        )
        public
        returns (
            uint /* amount */
        );

    // function only works within a block
    function simulateDeposit(
        address user,
        address token,
        uint    amount
        )
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
        uint    amount
        )
        public
        view
        returns (
            uint /* amount */,
            AuctionState memory
        );

    // 拍卖结束后提款
    function settle()
        external;

    // Try to settle the auction.
    function triggerSettle()
        external
        returns (bool success);

    /// @dev Get participations from a given address.
    function getUserParticipations(address user)
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
