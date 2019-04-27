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

/// @author Weikang Wang
/// @title ICurve - A contract calculating price curve.
/// @dev Inverse Propostional Model applied, para:T,M,P,K
/// Ask/sell price curve: P(t)=(at+b)/(ct+d)*P,
/// alternatively: P(t)=(at+b*T)/(ct+d*T)*P, M and S(K) decide the trend
/// or use P(t)/P to demonstrate the curve, it would be universal
/// let r=(K-1)/(M-1), where a=P, b=rMPT, c=K, d=rT
/// range of K is (1,inf), K is decided with S from 10 to inf
/// K=1+0.01*S min(K)=1.1 is to prevent curve from dropping too rapidly

import "./ICurveData.sol";

contract ICurve is ICurveData {

    function calcEstimatedTTL(
        uint cid,
        uint t1,
        uint t2
        )
        public
        view
        returns (
            uint /* ttlSeconds */
        );

    CurveParams[] public curveParams;
    mapping(bytes32 => uint) public cidByName;

    function getOriginCurveId(uint cid)
        public
        view
        returns (
            uint
        );

    /// @dev Clone a curve with different parameters
    /// @param cid The id of curve to be cloned
    /// @param T The duration of new curve
    /// @param P The target price of new curve
    function cloneCurve(
        uint cid,
        uint T,
        uint P
    )
        external
        returns (
            uint curveId
        );

    /// @dev Init parameters of price curves
    /// @param T Time to reach P (second)
    /// @param M Price scale
    /// @param P Target price
    /// @param S Curve shape parameter
    /// @param curveName 32bytes, strictly 8 alphabets/numbers
    function createCurve(
        address askToken,
        address bidToken,
        uint T,
        uint M,
        uint P,
        uint S,
        string memory curveName
        )
        public
        returns (
            bool /* success */,
            uint /* cid */
        );

    /// @dev Get Curve info From id
    /// @param cid Curve id
    function getCurveBytes(
        uint cid
        )
        external
        view
        returns (bytes memory);

    /// @dev Get Curve info From id
    /// @param cid Curve id
    function getCurveById(
        uint cid
        )
        public
        view
        returns (CurveParams memory);

    /// @dev Get Curve info From curve name
    /// @param curveName Curve name
    function getCurveByName(
        string memory curveName
        )
        public
        view
        returns (CurveParams memory);

    /// @dev Calculate ask/sell price on price curve
    /// @param cid curve id
    /// @param t Point in price curve
    function calcAskPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint);

    /// @dev Calculate inverse ask/sell price on price curve
    /// @param cid curve id
    /// @param p Price in price curve
    function calcInvAskPrice(
        uint cid,
        uint p
        )
        public
        view
        returns (
            bool,
            uint
        );

    /// @dev Calculate bid/buy price on price curve
    /// @param cid curve id
    /// @param t Point in price curve
    function calcBidPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint);

    /// @dev Calculate inverse bid/buy price on price curve
    /// @param cid curve id
    /// @param p Price in price curve
    function calcInvBidPrice(
        uint cid,
        uint p
        )
        public
        view
        returns (
            bool,
            uint
        );
}