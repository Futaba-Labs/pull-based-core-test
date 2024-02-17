// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";

import { Deposit } from "../src/Deposit.sol";

contract DepositTest is PRBTest, StdCheats {
    Deposit public deposit;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.
        deposit = new Deposit();
    }

    function test_Deposit() external {
        uint256 amount = 100;
        deposit.deposit{ value: amount }(amount);
        assertEq(deposit.balances(address(this)), amount);
    }

    function test_LzReceive() external {
        uint256 amount = 100;
        deposit.deposit{ value: amount }(amount);
        assertEq(deposit.balances(address(this)), amount);

        // Prepare the payload
        Deposit.DepositUpdateParam[] memory params = new Deposit.DepositUpdateParam[](1);
        params[0] = Deposit.DepositUpdateParam(address(this), amount);
        bytes memory payload = abi.encode(params);

        // Call the function
        deposit.lzReceive(0, bytes("0x"), 0, payload);

        // Assert the balance
        assertEq(deposit.balances(address(this)), 0);
    }
}
