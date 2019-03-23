pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IAuction.sol";
import "../lib/MathLib.sol";


contract ImplCurve is ICurve, MathLib{

    function nameCheck(string memory s)
        internal 
        pure 
        returns(
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
    
    
    /// @dev Init parameters of price curves
    /// @param T Time to reach P (second)
    /// @param M Price scale
    /// @param P Target price
    /// @param S Curve shape parameter
    /// @param PriceScale precision of price,10^18
    /// @param curveName 32bytes, strictly 8 alphabets/numbers
    function createCurve(
        uint T,
        uint M,
        uint P,
        uint S,
        uint PriceScale,
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

        require(T>=100 && T<=100000, "Duraton of auction should be between 100s and 100000s");
        require(M>=2 && M<=100, "M should be between 2 and 100");
        require(S>=10 && S<=100*M, "M should be between 10 and 100*M");

        uint cid;
        CurveParams memory cP;
        
        cP.T = T;
        cP.M = M;
        cP.P = P;
        cP.S = S;
        cP.a = PriceScale*100;
        cP.b = PriceScale*S*M/(M-1);
        cP.c = PriceScale*(100+S);
        cP.d = PriceScale*S/(M-1);
        cP.priceScale = PriceScale;
        cP.curveName = name;

        curveParams.push(cP);
         
        cid = curveParams.length;
        
        cidByName[name] = cid;

        return (true, cid);     
        

    }


    /// @dev Get Curve info From id
    /// @param cid Curve id
    function getCurveByID(
        uint cid
        )
        public
        view
        returns (CurveParams memory)
    {
        require(cid>0 && cid <= curveParams.length, "curve does not exist");
        return curveParams[cid-1];
    }

    /// @dev Get Curve info From id
    /// @param curveName Curve name
    function getCurveByName(
        string memory curveName
        )
        public
        view
        returns (CurveParams memory)
    {
        bytes32 name = nameCheck(curveName);
        require(cidByName[name] > 0, "curve does not exist");
        return curveParams[cidByName[name]-1];
    }

    /// @dev Calculate ask/sell price on price curve
    /// @param cid curve ID    
    /// @param t Point in price curve
    function calcAskPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint)
    {
        require(cid>0 && cid <= curveParams.length, "curve does not exist");
        uint p;
        CurveParams memory cP;
        cP = curveParams[cid-1];
        //p=P*(at+bT)/(ct+dT)
        p = mul(cP.P, add(mul(t, cP.a), mul(cP.T, cP.b)))/add(mul(t, cP.c), mul(cP.T, cP.d));
        return p; 
    }

    /// @dev Calculate inverse ask/sell price on price curve
    /// @param cid curve ID
    /// @param p Price in price curve
    function calcInvAskPrice(
        uint cid,
        uint p
        )
        public
        view
        returns (uint)
    {
        require(cid>0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        cP = curveParams[cid-1];
        require(p <= cP.P*cP.M && p > cP.P*cP.a/cP.c, "p is not correct");
        uint t;
        t = mul(cP.T, sub(mul(cP.b,cP.P),mul(cP.d,p)))/sub(mul(cP.c,p),mul(cP.a,cP.P));

        return t;

    }


    /// @dev Calculate bid/buy price on price curve
    /// @param cid curve ID
    /// @param t Point in price curve
    function calcBidPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint)
    {
        require(cid>0 && cid <= curveParams.length, "curve does not exist");
        uint p;
        CurveParams memory cP;
        cP = curveParams[cid-1];
        p = mul(cP.P, add(mul(t, cP.c), mul(cP.T, cP.d))/add(mul(t, cP.a), mul(cP.T, cP.b)));
        return p; 
    }

    /// @dev Calculate inverse bid/buy price on price curve
    /// @param cid curve ID
    /// @param p Price in price curve
    function calcInvBidPrice(
        uint cid,
        uint p
        )
        public
        view
        returns (uint)
    {
        require(cid>0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        cP = curveParams[cid-1];
        require(p >= cP.P/cP.M && p < cP.P*cP.c/cP.a, "p is not correct");
        uint t;
        t = mul(cP.T, sub(mul(cP.b,p),mul(cP.d,cP.P)))/sub(mul(cP.c,cP.P),mul(cP.a,p));
        return t;

    }

}