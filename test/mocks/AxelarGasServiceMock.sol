// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IAxelarGasService } from "../../src/interfaces/IAxelarGasService.sol";

contract AxelarGasServiceMock is IAxelarGasService {
    function payNativeGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    )
        external
        payable
        override
    {
        // do nothing
    }
}
