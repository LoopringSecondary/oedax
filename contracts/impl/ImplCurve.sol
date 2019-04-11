pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../iface/IAuction.sol";
import "../lib/MathLib.sol";
import "../lib/ERC20.sol";

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

        require(T>=100 && T<=100000, "Duraton of auction should be between 100s and 100000s");
        require(M>=2 && M<=100, "M should be between 2 and 100");
        require(S>=10 && S<=100*M, "S should be between 10 and 100*M");

        uint    askDecimals = ERC20(askToken).decimals();
        uint    bidDecimals = ERC20(bidToken).decimals();
        uint    priceScale;
        require(askDecimals <= bidDecimals && askDecimals + 18 > bidDecimals, "decimals not correct");
        priceScale = pow(10, 18 + askDecimals - bidDecimals);

        uint cid;
        CurveParams memory cP;
        BasicParams memory bP;
        

        bP.M = M;
        bP.S = S;
        bP.a = 1e18*100;
        bP.b = 1e18*S*M/(M-1);
        bP.c = 1e18*(100+S);
        bP.d = 1e18*S/(M-1);

        cP.askToken = askToken;
        cP.bidToken = bidToken;
        cP.T = T;
        cP.P = P;
        cP.priceScale = priceScale;
        cP.curveName = name;
        cP.basicParams = bP;

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

    /// @dev Get Curve info From curve name
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
        BasicParams memory bP;
        cP = curveParams[cid-1];
        bP = cP.basicParams;
        //p=P*(at+bT)/(ct+dT)
        p = mul(cP.P, add(mul(t, bP.a), mul(cP.T, bP.b)))/add(mul(t, bP.c), mul(cP.T, bP.d));
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
        returns (
            bool,
            uint)
    {
        require(cid>0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        BasicParams memory bP;
        cP = curveParams[cid-1];
        bP = cP.basicParams;
        if (p > cP.P*bP.M || p <= cP.P*bP.a/bP.c){
            return (false, 0);
        }

        uint t;
        t = mul(cP.T, sub(mul(bP.b,cP.P),mul(bP.d,p)))/sub(mul(bP.c,p),mul(bP.a,cP.P));

        return (true, t);

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
        BasicParams memory bP;
        cP = curveParams[cid-1];
        bP = cP.basicParams;
        p = mul(cP.P, add(mul(t, bP.c), mul(cP.T, bP.d)))/add(mul(t, bP.a), mul(cP.T, bP.b));
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
        returns (
            bool,
            uint)
    {
        require(cid>0 && cid <= curveParams.length, "curve does not exist");
        CurveParams memory cP;
        BasicParams memory bP;
        cP = curveParams[cid-1];
        bP = cP.basicParams;
        if (p < cP.P/bP.M || p >= cP.P*bP.c/bP.a){
            return (false, 0);
        }
        uint t;
        t = mul(cP.T, sub(mul(bP.b,p),mul(bP.d,cP.P)))/sub(mul(bP.c,cP.P),mul(bP.a,p));
        return (true, t);

    }

}
