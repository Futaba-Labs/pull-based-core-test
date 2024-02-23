// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IAxelarGasService {
    function payNativeGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    )
        external
        payable;
}
