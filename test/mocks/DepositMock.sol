// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Deposit } from "../../src/Deposit.sol";

contract DepositMock is Deposit {
    constructor(address _gateway) Deposit(_gateway) { }

    function execute(string calldata sourceChain_, string calldata sourceAddress_, bytes calldata payload_) external {
        _execute(sourceChain_, sourceAddress_, payload_);
    }
}
