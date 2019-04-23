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

contract ICurve{

    // 此处一是为了简洁表示，而是T与P的影响从表达式中分离
    // BasicParams可以表示一类倍数下降的曲线，因此是可扩展的
    /*
    struct BasicParams {
        uint M; // integer(2-100)
        uint S; // integer(10-100*M),precision=0.01,K=1+0.01*S
        uint a; // a=P => a=1*P
        uint b; // b=(K-1)*M*P*T/(M-1) => b=(K-1)*M/(M-1) *P*T
        uint c; // c=K
        uint d; // d=(K-1)*T/(M-1) => d=(K-1)/(M-1) *T
    }
    */

    // 此处优化priceScale含义，定义na/nb*priceScale为实际价格乘以1e18
    struct CurveParams {
        address askToken;
        address bidToken;
        uint T; // integer(100-100000)
        uint P; // decimal(P*priceScale)
        uint priceScale;    // priceScale
        //BasicParams basicParams; // common part which can be cloned

        uint M; // integer(2-100)
        uint S; // integer(10-100*M),precision=0.01,K=1+0.01*S
        uint a; // a=P => a=1*P
        uint b; // b=(K-1)*M*P*T/(M-1) => b=(K-1)*M/(M-1) *P*T
        uint c; // c=K
        uint d; // d=(K-1)*T/(M-1) => d=(K-1)/(M-1) *T

        bytes32 curveName;  // curve name
        
    }

    function calcEstimatedTTL(
        uint cid,
        uint t1,
        uint t2
        )
        public
        view
        returns(
            uint /* ttlSeconds */
        );


    CurveParams[] public curveParams;
    mapping(bytes32 => uint) public cidByName;

    
    function getOriginCurveID(uint cid)
        public
        view
        returns(
            uint
        );


    function getNextCurveID()
        public
        view
        returns(
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
        public
        returns(
            bool /* success */,
            uint /* cid */     
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
        public
        view
        returns (bytes memory);

    /// @dev Get Curve info From id
    /// @param cid Curve id
    function getCurveByID(
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
    /// @param cid curve ID
    /// @param t Point in price curve
    function calcAskPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint);

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
            uint
        );


    /// @dev Calculate bid/buy price on price curve
    /// @param cid curve ID
    /// @param t Point in price curve
    function calcBidPrice(
        uint cid,
        uint t
        )
        public
        view
        returns (uint);

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
            uint
        );

}