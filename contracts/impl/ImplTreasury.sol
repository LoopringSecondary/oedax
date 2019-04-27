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

import "../iface/ITreasury.sol";
import "../iface/IAuction.sol";
import "../lib/Ownable.sol";
import "../lib/ERC20SafeTransfer.sol";
import "../lib/MathLib.sol";
import "../lib/ERC20.sol";

contract ImplTreasury is ITreasury, Ownable, MathLib {

    using ERC20SafeTransfer for address;

    address public oedax;

    bool    public terminated;

    modifier whenRunning() {
        require(terminated == false, "already terminated!");
        _;
    }

    modifier isAuction() {
        require(
            auctionAddressMap[msg.sender] != 0 ||
            msg.sender == oedax,
            "The address is not oedax auction contract!"
        );
        _;
    }

    modifier onlyOedax() {
        require(
            msg.sender == oedax,
            "The address should be oedax contract"
        );
        _;
    }

    constructor()
        public
    {
        oedax = address(0x0);
        auctionAmount = 0;
    }

    function setOedax(address _oedax)
        public
        onlyOwner
    {
        require(
            oedax == address(0x0),
            "Oedax could only be set once!"
        );
        oedax = _oedax;
    }

    function getAuctionIndex(address creator)
        public
        view
        returns (
            uint[] memory
        )
    {
        return auctionFactoryMap[creator];
    }

    function getNextAuctionId()
        public
        view
        returns (uint)
    {
        return auctionAmount + 1;  // REVIEW? auctionAmount + 1 ???
    }

    // 把两个Token的锁仓全部换成新的amount
    function exchangeTokens(
        address recepient,
        address user,
        address tokenA,
        address tokenB,
        uint    amountA,
        uint    amountB
        )
        external
        isAuction
        whenRunning
    {
        uint id = auctionAddressMap[msg.sender];
        require(
            id > 0,
            "address not correct"
        );

        uint lockedA = userLockedBalances[user][id][tokenA];
        uint lockedB = userLockedBalances[user][id][tokenB];

        // clear locked in userLockedBalances
        userLockedBalances[user][id][tokenA] = 0;
        userLockedBalances[user][id][tokenB] = 0;

        // clear locked in userTotalBalances
        userTotalBalances[user][tokenA] = sub(userTotalBalances[user][tokenA], lockedA);
        userTotalBalances[user][tokenB] = sub(userTotalBalances[user][tokenB], lockedB);

        // update contractLockedBalances
        contractLockedBalances[msg.sender][tokenA] = sub(contractLockedBalances[msg.sender][tokenA], amountA);
        contractLockedBalances[msg.sender][tokenB] = sub(contractLockedBalances[msg.sender][tokenB], amountB);

        // finish exchange
        userTotalBalances[user][tokenA] = add(userTotalBalances[user][tokenA], amountA);
        userTotalBalances[user][tokenB] = add(userTotalBalances[user][tokenB], amountB);
        userAvailableBalances[user][tokenA] = add(userAvailableBalances[user][tokenA], amountA);
        userAvailableBalances[user][tokenB] = add(userAvailableBalances[user][tokenB], amountB);
    }

    /// Auction合约直接在user和recepient之间完成“转账”，保证所有变量总额不变
    /// recepient获得相应的抽成（在拍卖结束后提取）
    /// 用于用户绑定的fee收取
    function sendFee(
        address recepient,
        address user,
        address token,
        uint    amount
        )
        external
        isAuction
        whenRunning
    {

        uint id = auctionAddressMap[msg.sender];
        require(
            id > 0,
            "address not correct"
        );

        userLockedBalances[user][id][token] = sub(userLockedBalances[user][id][token], amount);
        userTotalBalances[user][token] = sub(userTotalBalances[user][token], amount);

        contractLockedBalances[msg.sender][token] = sub(contractLockedBalances[msg.sender][token], amount);

        //userLockedBalances[recepient][id][token] = add(userLockedBalances[recepient][id][token], amount);
        userAvailableBalances[recepient][token] = add(userAvailableBalances[recepient][token], amount);

        userTotalBalances[recepient][token] = add(userTotalBalances[recepient][token], amount);
    }

    /// 在拍卖结束后，由auction分配
    /// recepient获得相应的抽成，与单个用户无关，整体计算金额

    // REVIEW? This method is missing from the ITreasury interface definition
    function sendFeeAll(
        address recepient,
        address token,
        uint    amount
        )
        external
        isAuction
        whenRunning
    {

        uint id = auctionAddressMap[msg.sender];
        require(
            id > 0,
            "address not correct"
        );

        contractLockedBalances[msg.sender][token] = sub(contractLockedBalances[msg.sender][token], amount);

        userAvailableBalances[recepient][token] = add(userAvailableBalances[recepient][token], amount);

        userTotalBalances[recepient][token] = add(userTotalBalances[recepient][token], amount);
    }

    //between treasury contract and auction contract
    function auctionDeposit(
        address user,
        address token,
        uint    amount  // must be greater than 0.
        )
        external
        isAuction
        whenRunning
    {
        require(
            amount <= userAvailableBalances[user][token],
            "not enough token"
        );

        uint id = auctionAddressMap[msg.sender];

        userAvailableBalances[user][token] = sub(userAvailableBalances[user][token], amount);
        userLockedBalances[user][id][token] = add(userLockedBalances[user][id][token], amount);
        contractLockedBalances[msg.sender][token] = add(contractLockedBalances[msg.sender][token], amount);
    }

    function initDeposit(
        address user,
        address auctionAddr,
        address token,
        uint    amount  // must be greater than 0.
        )
        external
        onlyOedax
        whenRunning
    {
        require(
            amount <= userAvailableBalances[user][token],
            "not enough token"
        );

        uint id = auctionAddressMap[auctionAddr];
        //REVIEW? 如果auctionAddr不是一个合法的地址是不是就不应该转账？也就是需要判断id是不是为0。

        userAvailableBalances[user][token] = sub(userAvailableBalances[user][token], amount);
        userLockedBalances[user][id][token] = add(userLockedBalances[user][id][token], amount);
        contractLockedBalances[auctionAddr][token] = add(contractLockedBalances[auctionAddr][token], amount);
    }

    //between treasury contract and auction contract
    function auctionWithdraw(
        address user,
        address token,
        uint    amount  // specify 0 to withdrawl as much as possible.
        )
        external
        isAuction
        whenRunning
    {
        require(
            amount <= userLockedBalances[user][auctionAddressMap[msg.sender]][token],
            "not enough token"
        );
        uint id = auctionAddressMap[msg.sender];
        userAvailableBalances[user][token] = add(userAvailableBalances[user][token], amount);
        userLockedBalances[user][id][token] = sub(userLockedBalances[user][id][token], amount);
        contractLockedBalances[msg.sender][token] = sub(contractLockedBalances[msg.sender][token], amount);
    }

    //between treasury contract and token contract
    function deposit(
        address token,
        uint    amount  // must be greater than 0.
        )
        external
        whenRunning
        returns (bool successful)
    {
        successful = token.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (successful) {
            userAvailableBalances[msg.sender][token] = add(userAvailableBalances[msg.sender][token], amount);
            userTotalBalances[msg.sender][token] = add(userTotalBalances[msg.sender][token], amount);
        }
        if (!userTokens[msg.sender][token]) {
            userTokens[msg.sender][token] = true;
            userTokenList[msg.sender].push(token);
        }
    }

    //between treasury contract and token contract
    function withdraw(
        address token,
        uint    amount  // specify 0 to withdrawl as much as possible.
        )
        external
        whenRunning
        returns (bool successful)
    {
        require(
            amount <= userAvailableBalances[msg.sender][token],
            "Not enough token!"
        );
        successful = token.safeTransfer(
            msg.sender,
            amount
        );
        if (successful) {
            userAvailableBalances[msg.sender][token] = sub(userAvailableBalances[msg.sender][token], amount);
            userTotalBalances[msg.sender][token] = sub(userTotalBalances[msg.sender][token], amount);
        }
    }

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
        )
    {
        uint total;
        uint available;
        uint locked;
        total = userTotalBalances[user][token];
        available = userAvailableBalances[user][token];
        locked = sub(total, available);
        return (total, available, locked);
    }

    function getAvailableBalance(
        address user,
        address token
        )
        external
        view
        returns (uint)
    {
        return userAvailableBalances[user][token];
    }

    function getApproval(
        address user,
        address token
        )
        public
        view
        returns (
            uint balance,
            uint approval
        )
    {
        balance = ERC20(token).balanceOf(user);
        approval = ERC20(token).allowance(user, address(this));
    }

    function registerAuction(
        address auction,
        address creator
        )
        external
        whenRunning
        onlyOedax
        returns (uint auctionId)
    {
        auctionId = getNextAuctionId();
        auctionAddressMap[auction] = auctionId;
        auctionIdMap[auctionId] = auction;
        auctionFactoryMap[creator].push(auctionId);
        auctionAmount += 1;
    }

    // In case of an high-risk bug, the admin can return all tokens, including those locked in
    // active auctions, to their original owners.
    // If this function is called, all invocation from any on-going auctions will fail, but all
    // users' asset will be safe.
    // This method can only be called once.
    function terminate()
        external
        onlyOwner
        whenRunning
    {
        terminated = true;
        //TODO: give back all the balances
    }

    /// Auction 在未完成状态时，userTotalBalances - userAvailableBalances 即为锁仓数量
    /// 锁仓数量为扣除 walletFee与protocolFee的 实际参与拍卖的Token数量
    /// 锁仓数量为实际参与拍卖总量（包括Taker与合约内锁仓的Token）
    /// taker数量换算成Token，拍卖结束时按比例返还并兑换成另一个币种

    function withdrawWhenTerminated(
        address[] calldata tokens
        )
        external
    {
        require(
            terminated == true,
            "contract should be terminated!"
        );
        address token;
        for (uint i = 0; i < tokens.length; i++) {
            token = tokens[i];
            if (userTotalBalances[msg.sender][token] > 0 &&
                token.safeTransfer(
                    msg.sender,
                    userTotalBalances[msg.sender][token]
                )
            )
            {
                userTotalBalances[msg.sender][token] = 0;
                userAvailableBalances[msg.sender][token] = 0;
            }
        }
    }

    function isTerminated()
        external
        view
        returns (bool)
    {
        return terminated;
    }
}