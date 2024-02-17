// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ILayerZeroEndpoint } from "../../src/interfaces/ILayerZeroEndpoint.sol";

contract LayerZeroEndpointMock is ILayerZeroEndpoint {
    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    )
        external
        payable
    { }
}
