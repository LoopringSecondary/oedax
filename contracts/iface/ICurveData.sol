pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;


contract ICurveData {  
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
}