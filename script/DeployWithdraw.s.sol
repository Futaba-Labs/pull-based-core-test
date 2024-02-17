// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Withdraw } from "../src/Withdraw.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployWithdraw is BaseScript {
    address constant deposit = 0xFf598258cFeafDcA634b24b5C4194c9F38a1d816;
    address constant lzEndpoint = 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3;
    address constant stargateRouter = 0xb2d85b2484c910A6953D28De5D3B8d204f7DDf15;
    address constant futabaEndpoint = 0x00EF9F95500621f08C25587106d4D362b9db9225;
    address constant lightClient = 0x997ae35162766C4aF4623EEa4faB6F484bC4593c;

    function run() public broadcast returns (Withdraw withdraw) {
        withdraw = new Withdraw(lzEndpoint, futabaEndpoint, deposit, lightClient, stargateRouter);
    }
}
