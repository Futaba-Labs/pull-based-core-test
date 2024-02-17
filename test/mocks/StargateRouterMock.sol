// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IStargateRouter } from "../../src/interfaces/IStargateRouter.sol";

contract StargateRouterMock is IStargateRouter {
    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    )
        external
        view
        returns (uint256, uint256)
    {
        return (100, 1);
    }

    function swapETHAndCall(
        uint16 _dstChainId, // destination Stargate chainId
        address payable _refundAddress, // refund additional messageFee to this address
        bytes calldata _to, // the receiver of the destination ETH
        SwapAmount memory _swapAmount, // the amount and the minimum swap amount
        IStargateRouter.lzTxObj memory _lzTxParams, // the LZ tx params
        bytes calldata _payload // the payload to send to the destination
    )
        external
        payable
    { }
}
