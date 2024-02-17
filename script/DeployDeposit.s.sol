// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Deposit } from "../src/Deposit.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployDeposit is BaseScript {
    function run() public broadcast returns (Deposit deposit) {
        deposit = new Deposit();
    }
}
