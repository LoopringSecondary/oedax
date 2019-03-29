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

    struct BasicParams {
        uint M; // integer(2-100)
        uint S; // integer(10-100*M),precision=0.01,K=1+0.01*S
        uint a; // a=P => a=1*P
        uint b; // b=(K-1)*M*P*T/(M-1) => b=(K-1)*M/(M-1) *P*T
        uint c; // c=K
        uint d; // d=(K-1)*T/(M-1) => d=(K-1)/(M-1) *T
    }

    struct CurveParams {
        uint T; // integer(100-100000)
        uint P; // decimal(P*priceScale)
        uint priceScale;    // priceScale
        BasicParams basicParams; // common part which can be cloned
        bytes32 curveName;  // curve name
    }


    CurveParams[] public curveParams;
    mapping(bytes32 => uint) public cidByName;

    /// @dev Init parameters of price curves
    /// @param T Time to reach P (second)
    /// @param M Price scale
    /// @param P Target price
    /// @param S Curve shape parameter
    /// @param PriceScale precision of price
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
        );


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
        returns (uint);


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
        returns (uint);

}