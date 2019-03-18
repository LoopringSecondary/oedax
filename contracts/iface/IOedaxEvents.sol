pragma solidity 0.5.5;
pragma experimental ABIEncoderV2;

///@author Weikang Wang
///@title OedaxEvent - A contract for the events in Oedax contract.
///@dev events to trigger in Oedax contract.


contract IOedaxEvents {
    event FeeSettingsUpdated (
        address indexed recepient,
        uint            creationFeeEth,
        uint            protocolBips,
        uint            walletBipts,
        uint            rebateBips,
        uint            withdrawalPenaltyBips,
        uint            timestamp
    );
}