pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

///@author Weikang Wang
///@title ICurve - A contract calculating price curve.
///@dev Inverse Propostional Model Applied, para:T,M,P,K
///Ask/sell price curve: P(t)=(at+b)/(ct+d)
///let r=(K-1)/(M-1), where a=P, b=rMPT, c=M, d=rT
///range of K is (1,inf), K is decided with S from 0 to 100
///According to simulation, K=(11000+(M-1)*(S+10)*(S+10))/10000
///min(K)=1.1 is to prevent curve from dropping too rapidly

contract ICurve{

    
    struct CurvePara{
        uint a;//a=P
        uint b;//b=(K-1)*M*P*nT/(M-1)
        uint c;//c=M
        uint d;//d=(K-1)*nT/(M-1)
        uint precision;//points per second
    }
    
    //According to the designed interfaces in Oedax.sol
    //it is nessasary to store the init infomation
    struct InitPara{
        uint T;
        uint M;
        uint P;
        uint S;
        uint Precision;
    }

    CurvePara public curvePara;
    InitPara public initPara;

    ///@dev Init parameters of price curves
    //init a,b,c,d,precison according to the parameters
    //if T=10000s, Precision=1000, then the point 
    //reach P on curves is nT=T*Precision=1e7
    ///@param T Time to reach P (second)
    ///@param M Price scale
    ///@param P Target price
    ///@param S Curve shape parameter, from 1 to 100
    ///@param Precision points per second
    function initCurve(
        uint T,
        uint M,
        uint P,
        uint S,
        uint Precision
        )
        internal
        returns (bool success);
 

    ///@dev Calculate ask/sell price on price curve
    ///@param nT Point in price curve
    function calAskPrice(
        uint nT
        )
        internal
        view
        returns (uint price);

    ///@dev Calculate inverse ask/sell price on price curve
    ///@param P Price in price curve
    function calInvAskPrice(
        uint P
        )
        internal
        view
        returns (uint point);


    ///@dev Calculate bid/buy price on price curve
    ///@param nT Point in price curve
    function calBidPrice(
        uint nT
        )
        internal
        view
        returns (uint price);

    ///@dev Calculate inverse bid/buy price on price curve
    ///@param P Price in price curve
    function calInvBidPrice(
        uint P
        )
        internal
        view
        returns (uint nT);
    
}