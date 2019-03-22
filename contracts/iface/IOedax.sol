pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "./IAuctionData.sol";
import "./IAuctionEvents.sol";
import "./IOedaxEvents.sol";

contract IOedax is IAuctionData, IAuctionEvents, IOedaxEvents{


    // Initiate an auction
    function createAuction(
        uint    delaySeconds,
        uint    curveId,
        address askToken,
        address bidToken,
        uint    askDecimals,
        uint    bidDecimals,
        uint    priceScale,
        uint    P,  // target price
        uint    M,  // prixce factor
        uint    T,  // duration
        uint    initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint    initialBidAmount,         // The initial amount of tokenB from the creator's account.
        uint    maxAskAmountPerAddr,      // The max amount of tokenA per address, 0 for unlimited.
        uint    maxBidAmountPerAddr,      // The max amount of tokenB per address, 0 for unlimited.
        bool    isWithdrawalAllowed,
        bool    isTakerFeeDisabled      // Disable using takerBips
    )
        external
        returns (
            address /* auction */,
            uint    /* id */
        );

    function getAuctionInfo(uint id)
        external
        view
        returns (
            AuctionSettings memory,
            AuctionState    memory
        );

    function getAuctions(
        uint    skip,
        uint    count,
        address creator,
        Status  status
    )
        external
        view
        returns (
            uint[] memory /* auction index */
        );

    // /@dev clone an auction from existing auction using its id
    function cloneAuction(
        uint auctionID,
        uint initialAskAmount,
        uint initialBidAmount
        )
        public
        returns(
            address /* auction */,
            uint    /* id */,
            bool    /* successful */
        );

    // /@dev clone an auction using its address
    function cloneAuction(
        address auctionAddr,
        uint    initialAskAmount,
        uint    initialBidAmount
        )
        public
        returns(
            address /* auction */,
            uint    /* id */,
            bool    /* successful */
        );



    // All fee settings will only apply to future auctions, but not exxisting auctions.
    // One basis point is equivalent to 0.01%.
    // We suggest the followign values:
    // creationFeeEth           = 0 ETH
    // protocolBips             = 5   (0.05%)
    // walletBips               = 5   (0.05%)
    // takerBips                = 25  (0.25%)
    // withdrawalPenaltyBips    = 250 (2.50%)
    // The earliest maker will earn 25-5-5=15 bips (0.15%) rebate, the latest taker will pay
    // 25+5+5=35 bips (0.35) fee. All user combinedly pay 5+5=10 bips (0.1%) fee out of their
    // purchased tokens.
    function setFeeSettings(
        address recepient,
        uint    creationFeeEth,     // the required Ether fee from auction creators. We may need to
                                    // increase this if there are too many small auctions.
        uint    protocolBips,       // the fee paid to Oedax protocol
        uint    walletBipts,        // the fee paid to wallet or tools that help create the deposit
                                    // transactions, note that withdrawal doen't imply a fee.
        uint    takerBips,          // the max bips takers pays makers.
        uint    withdrawalPenaltyBips  // the percentage of withdrawal amount to pay the protocol.
                                       // Note that wallet and makers won't get part of the penalty.
    )
        external;

    function getFeeSettings(
    )
        external
        view
        returns (
            address recepient,
            uint    creationFeeEth,
            uint    protocolBips,
            uint    walletBipts,
            uint    takerBips,
            uint    withdrawalPenaltyBips
        );

    // the sub-contract should only be used as "cloning" a curve
    // cloning an auction is the same as cloning a curve
    // register a curve sub-contract.
    // The first curve should have id 1, not 0.
    function registerCurve(
        address ICurve
    )
        external
        returns (
            uint /* curveId */
        );

    // unregister a curve sub-contract
    function unregisterCurve(
        uint curveId
    )
        external
        returns (
            address /* curve */
        );

    function getCurves(
        )
        external
        view
        returns (
            address[] memory /* curves */
        );
}
