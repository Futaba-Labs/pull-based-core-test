// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IAxelarGateway } from "../../src/interfaces/IAxelarGateway.sol";

contract AxelarGatewayMock is IAxelarGateway {
    function callContract(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    )
        external
        override
    {
        // do nothing
    }
}
