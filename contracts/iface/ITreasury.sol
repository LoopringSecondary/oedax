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

contract ITreasury {
    // user => (token => amount)
    mapping (address => mapping (address => uint)) public userTotalBalances;

    // user => (token => amount)
    mapping (address => mapping (address => uint)) public userAvailableBalances;

    // user => (auction_id => （token => amount))
    mapping (address => mapping (uint => mapping (address => uint))) public userLockedBalances;

    mapping (uint => address) public auctionIdMap;
    mapping (address => uint) public auctionAddressMap;
    mapping (address => uint[]) public auctionFactoryMap; // for the need of getAuctions() in Oedax contract

    uint  public  auctionAmount;

    // auction => token => amount
    // treasury中的token交易需要总量不变，数量变化都有来源
    // contractLockedBalances用于存储总量，不代表可以提币数量
    mapping (address => mapping(address => uint)) public contractLockedBalances;

    // 用于记录用户存有资产的Token, 以便查询功能
    mapping (address => address[]) public userTokenList;

    // 用于记录用户是否存有资产 user=>token=>bool
    mapping (address => mapping(address=>bool)) public userTokens;

    // 获得用户创建的Auction的Index数组
    function getAuctionIndex(address creator)
        public
        view
        returns (
            uint[] memory
        );

    // auctionId递增，用于创建拍卖时获得Id
    function getNextAuctionId()
        public
        view
        returns (uint);

    // 拍卖结束时统一结算用户应得的Token数量，由于操作较为复杂
    // 结算在子拍卖合约中进行，函数要求合约地址才可以调用
    function exchangeTokens(
        address recepient,
        address user,
        address tokenA,
        address tokenB,
        uint    amountA,
        uint    amountB
        )
        external;

    // 用于结算deposit时的手续费
    function sendFee(
        address recepient,
        address user,
        address token,
        uint    amount
        )
        external;

    function initDeposit(
        address user,
        address auctionAddr,
        address token,
        uint    amount  // must be greater than 0.
        )
        external
        returns (
            bool /* successful */
        );

    // 拍卖合约调用，属于Oedax内部“转账”
    // between treasury contract and auction contract
    function auctionDeposit(
        address user,
        address token,
        uint    amount  // must be greater than 0.
        )
        external;

    // between treasury contract and auction contract
    function auctionWithdraw(
        address user,
        address token,
        uint    amount  // specify 0 to withdrawl as much as possible.
        )
        external;

    // treasuy合约与Token合约之间的转账
    // between treasury contract and token contract
    function deposit(
        address token,
        uint    amount  // must be greater than 0.
        )
        external
        returns (bool successful);

    // between treasury contract and token contract
    function withdraw(
        address token,
        uint    amount  // specify 0 to withdrawl as much as possible.
        )
        external
        returns (bool successful);

    // 获取用户实时余额
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

    // 获取用户实时余额
    function getAvailableBalance(
        address user,
        address token
        )
        external
        view
        returns (uint);

    // 新增接口，用于查询用户授权的转账量
    // treasury合约的转账只能由用户调用时生效
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
        returns (uint auctionId);

    // In case of a high-risk bug, the admin can return all tokens, including those locked in
    // active auctions, to their original owners.
    // If this function is called, all invocation from any on-going auctions will fail, but all
    // users' asset will be safe.
    // This method can only be called once.
    function terminate()
        external;

    // 合约中用户参与的拍卖Id以及有余额的Token较为复杂
    // 暂时决定方案时，紧急情况下用户可以提走自己所有的余额
    // token列表可查询，也可自己给出
    function withdrawWhenTerminated(address[] calldata tokens)
        external;

    function isTerminated()
        external
        view
        returns (
            bool /* terminated */
        );
}
