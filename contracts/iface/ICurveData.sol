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

contract ICurveData {
    struct CurveParams {
        address askToken;
        address bidToken;
        uint    T; // integer(100-100000)
        uint    P; // decimal(P*priceScale)
        uint    priceScale;    // priceScale
        //BasicParams basicParams; // common part which can be cloned

        uint    M; // integer(2-100)
        uint    S; // integer(10-100*M),precision=0.01,K=1+0.01*S
        uint    a; // a=P => a=1*P
        uint    b; // b=(K-1)*M*P*T/(M-1) => b=(K-1)*M/(M-1) *P*T
        uint    c; // c=K
        uint    d; // d=(K-1)*T/(M-1) => d=(K-1)/(M-1) *T

        bytes32 curveName;  // curve name
    }
}