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
pragma solidity 0.5.7;
pragma experimental ABIEncoderV2;

import "../lib/MathUint.sol";
import "../lib/ERC20.sol";
import "../helper/DataHelper.sol";
import "../iface/ICurve.sol";

contract Curve is ICurve, DataHelper {

    // REVIEW? 请使用MathUint(参考Auction)

    using MathUint for uint;

    function nameCheck(string memory s)
        internal
        pure
        returns (
            bytes32
        )
    {
        bytes memory sbyte = bytes(s);
        uint256 len = sbyte.length;

        require(len == 8, "length of name should be 8");

        for (uint i = 0; i < len; i++) {
            //Uppercase A-Z
            if (sbyte[i] > 0x40 && sbyte[i] < 0x5b) {
                // Convert to lowercase
                sbyte[i] = byte(uint8(sbyte[i]) + 32);
            } else {
                require
                    (
                    (sbyte[i] > 0x60 && sbyte[i] < 0x7b) ||
                    (sbyte[i] > 0x2f && sbyte[i] < 0x3a),
                    "string contains invalid characters"
                );
            }
        }

        bytes32 res;

        assembly {
            res := mload(add(sbyte, 32))
        }
        return res;
    }

    function getOriginCurveId(uint cid)
        public
        view
        returns (
            uint
        )
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        return cidByName[curveParams[cid - 1].curveName];
    }

    function cloneCurve(
        uint cid,
        uint T,
        uint P
        )
        external
        returns (
            uint  curveId
        )
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory newCurve = curveParams[cid - 1];
        newCurve.T = T;
        newCurve.P = P;
        curveParams.push(newCurve);
        curveId = curveParams.length;
    }

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
        )
    {
        bytes32 name = nameCheck(curveName);
        require(cidByName[name] == 0, "curve name already used");

        require(T >= 100 && T <= 100000, "Duraton of auction should be between 100s and 100000s");
        require(M >= 2 && M <= 100, "M should be between 2 and 100");
        require(S >= 10 && S <= 100 * M, "S should be between 10 and 100*M");

        uint    askDecimals = ERC20(askToken).decimals();
        uint    bidDecimals = ERC20(bidToken).decimals();
        uint    priceScale;
        require(askDecimals <= bidDecimals && askDecimals + 18 > bidDecimals, "decimals not correct");

        // TODO(daniel): figure out this
        priceScale = MathUint.pow(10, 18 + askDecimals - bidDecimals);

        uint cid;
        CurveParams memory cP;

        cP.M = M;

        cP.S = S;
        cP.a = MathUint.mul(1e18, 100);
        cP.b = MathUint.mul(1e18, S.mul(M)) / M.sub(1);
        cP.c = MathUint.mul(1e18, S.add(100));
        cP.d = MathUint.mul(1e18, S) / M.sub(1);

        cP.askToken = askToken;
        cP.bidToken = bidToken;
        cP.T = T;
        cP.P = P;
        cP.priceScale = priceScale;
        cP.curveName = name;

        curveParams.push(cP);

        cid = curveParams.length;

        cidByName[name] = cid;

        return (true, cid);
    }

    /// @dev Get Curve info From id
    /// @param cid Curve id
    function getCurveById(
        uint cid
        )
        public
        view
        returns (ICurveData.CurveParams memory)
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        return curveParams[cid - 1];
    }

    /// @dev Get Curve info From id
    /// @param cid Curve id
    function getCurveBytes(
        uint cid
        )
        external
        view
        returns (bytes memory)
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        cP = curveParams[cid - 1];
        bytes memory bC;
        bC = curveParamsToBytes(cP);
        return bC;
    }

    /// @dev Get Curve info From curve name
    /// @param curveName Curve name
    function getCurveByName(
        string memory curveName
        )
        public
        view
        returns (ICurveData.CurveParams memory)
    {
        bytes32 name = nameCheck(curveName);
        require(cidByName[name] > 0, "curve does not exist");
        return curveParams[cidByName[name] - 1];
    }

    /// @dev Calculate ask/sell price on price curve
    /// @param cid curve id
    /// @param t Point in price curve
    function calcAskPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint)
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        uint p;
        CurveParams memory cP;
        cP = curveParams[cid - 1];
        //p=P*(at+bT)/(ct+dT)
        // p = mul(cP.P, add(mul(t, cP.a), mul(cP.T, cP.b))) / add(mul(t, cP.c), mul(cP.T, cP.d));
        p = t.mul(cP.a).add(cP.T.mul(cP.b)).mul(cP.P) / t.mul(cP.c).add(cP.T.mul(cP.d));
        return p;
    }

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
            uint)
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        cP = curveParams[cid - 1];
        if (p > cP.P * cP.M || p <= cP.P * cP.a / cP.c) {
            return (false, 0);
        }

        uint t;
        // t = mul(cP.T, sub(mul(cP.b, cP.P),mul(cP.d, p))) / sub(mul(cP.c, p), mul(cP.a, cP.P));
        t = cP.b.mul(cP.P).sub(cP.d.mul(p)).mul(cP.T) / cP.c.mul(p).sub(cP.a.mul(cP.P));

        return (true, t);
    }

    /// @dev Calculate bid/buy price on price curve
    /// @param cid curve id
    /// @param t Point in price curve
    function calcBidPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint p)
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        cP = curveParams[cid - 1];

        // p = mul(cP.P, add(mul(t, cP.c), mul(cP.T, cP.d))) / add(mul(t, cP.a), mul(cP.T, cP.b));
        p = t.mul(cP.c).add(cP.T.mul(cP.d)).mul(cP.P) / t.mul(cP.a).add(cP.T.mul(cP.b));
    }

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
            uint)
    {
        require(cid > 0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        cP = curveParams[cid - 1];

        if (p < cP.P / cP.M || p >= cP.P.mul(cP.c) / cP.a) {
            return (false, 0);
        }
        uint t;
        // t = mul(cP.T, sub(mul(cP.b, p), mul(cP.d, cP.P))) / sub(mul(cP.c, cP.P), mul(cP.a, p));
        t = cP.b.mul(p).sub(cP.d.mul(cP.P)).mul(cP.T) / cP.c.mul(cP.P).sub(cP.a.mul(p));
        return (true, t);
    }

    function isClosed(
        uint cid,
        uint t1,
        uint t2
        )
        internal
        view
        returns (
            bool
        )
    {
        uint p1 = calcAskPrice(cid, t1);
        uint p2 = calcBidPrice(cid, t2);
        return p1 <= p2;
    }

    function calcEstimatedTTL(
        uint cid,
        uint t1,
        uint t2
        )
        public
        view
        returns (
            uint /* ttlSeconds */
        )
    {

        require(cid > 0 && cid <= curveParams.length, "curve does not exist");

        uint period = curveParams[cid - 1].T;

        uint dt1;
        uint dt2;

        if (isClosed(cid, t1, t2)) {
            return 0;
        }

        uint dt = period / 100;

        if (t1.add(t2) < period.mul(2).sub(dt.mul(2))) {
            dt1 = period.mul(2).sub(t1).sub(t2) / 2;
        } else {
            dt1 = dt;
        }

        while (dt1 >= dt && isClosed(cid, t1.add(dt1), t2.add(dt1))) {
            dt1 = dt1.sub(dt);
        }

        while (!isClosed(cid, t1.add(dt1).add(dt), t2.add(dt1).add(dt))) {
            dt1 = dt1.add(dt);
        }

        dt2 = dt1.add(dt);

        // now the point is between dt1 and dt2
        while (
            dt2.sub(dt1) > 1 &&
            isClosed(cid, t1.add(dt2), t2.add(dt2))
        ) {
            uint dt3 = dt1.add(dt2) / 2;
            if (isClosed(cid, t1.add(dt3), t2.add(dt3))) {
                dt2 = dt3;
            } else {
                dt1 = dt3;
            }
        }

        return dt2;
    }

}
