// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Withdraw } from "../src/Withdraw.sol";
import { ILayerZeroEndpoint } from "../src/interfaces/ILayerZeroEndpoint.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract SendMessage is BaseScript {
    Withdraw withdraw = Withdraw(0x6086cAa91C793aE55cA5864ef48371a55a681192);
    address lzEndpoint = 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3;
    uint16 dstChainId = 10_232; // Optimism Sepolia
    address to = 0xc92FE6Db0a49C339E1D56eB23ECF6a7251aac67C;
    uint256 amount = 0.01 ether;

    function run() public broadcast {
        // // estimate lz fee
        // uint256 lzFee = withdraw.estimateLzfeeTest();
        // // send message
        // withdraw.sendToL1{ value: lzFee }();

        // estimate staragte fee
        (uint256 fee, uint256 poolId) = withdraw.quoteStaragteFee(dstChainId, to);

        // exexute bridge
        withdraw.bridge{ value: fee + amount }(dstChainId, amount, to, fee);
    }
}
