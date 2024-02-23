// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Withdraw } from "../src/Withdraw.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployWithdraw is BaseScript {
    address constant deposit = 0x6086cAa91C793aE55cA5864ef48371a55a681192;
    address constant axelarGateway = 0xe432150cce91c13a887f7D836923d5597adD8E31;
    address constant axelarGasService = 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6;
    address constant stargateRouter = 0xb2d85b2484c910A6953D28De5D3B8d204f7DDf15;
    address constant futabaEndpoint = 0x00EF9F95500621f08C25587106d4D362b9db9225;
    address constant lightClient = 0x997ae35162766C4aF4623EEa4faB6F484bC4593c;

    function run() public broadcast returns (Withdraw withdraw) {
        withdraw = new Withdraw(axelarGateway, axelarGasService, futabaEndpoint, deposit, lightClient, stargateRouter);
    }
}
