pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

import "../impl/ImplAuction.sol";
import "../iface/IAuctionGenerator.sol";
import "../lib/Ownable.sol";
import "../helper/DataHelper.sol";

contract ImplAuctionGenerator is Ownable, DataHelper{

    address public  oedax;
    address public  treasury;

    modifier isOedax(){
        require(
            msg.sender == oedax,
            "The address should be oedax contract"
        );
        _;
    }
    


    constructor(
        address _treasury
    )
        public
    {
        oedax = address(0x0);
        treasury = _treasury;
    }

    
    function setOedax(
        address _oedax
        )
        public
        onlyOwner
    {
        require(
            oedax == address(0x0), 
            "Oedax could only be set once!"
        );
        oedax = _oedax;
    } 


    
    function createAuction(
        address     curve,
        uint        curveId,
        uint        initialAskAmount,         // The initial amount of tokenA from the creator's account.
        uint        initialBidAmount,         // The initial amount of tokenB from the creator's account.
        bytes  memory   bFeeS,
        bytes  memory   bTokenInfo,
        bytes  memory   bAuctionInfo,
        uint        id,
        address     creator

    )
        public
        isOedax
        returns (
            address /* auction */
        )
    {


        ImplAuction auction = new ImplAuction(
            oedax,
            treasury, 
            curve,
            curveId,
            initialAskAmount,
            initialBidAmount,
            bytesToFeeSettings(bFeeS),
            bytesToTokenInfo(bTokenInfo),
            bytesToAuctionInfo(bAuctionInfo),
            id,
            creator
        );




        return address(auction);

    }


}