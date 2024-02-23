// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { IAxelarGateway } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import { DepositMock } from "./mocks/DepositMock.sol";
import { Deposit } from "../src/Deposit.sol";

contract DepositTest is PRBTest, StdCheats {
    address constant gateway = 0xe432150cce91c13a887f7D836923d5597adD8E31;
    DepositMock public deposit;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.
        deposit = new DepositMock(gateway);
    }

    function test_Deposit() external {
        uint256 amount = 100;
        deposit.deposit{ value: amount }(amount);
        assertEq(deposit.balances(address(this)), amount);
    }

    function test_Execute() external {
        uint256 amount = 100;
        deposit.deposit{ value: amount }(amount);
        assertEq(deposit.balances(address(this)), amount);

        // Prepare the payload
        Deposit.DepositUpdateParam[] memory params = new Deposit.DepositUpdateParam[](1);
        params[0] = Deposit.DepositUpdateParam(address(this), amount);
        bytes memory payload = abi.encode(params);

        // Call the function
        deposit.execute("sourceChain", "sourceAddress", payload);

        // Assert the balance
        assertEq(deposit.balances(address(this)), 0);
    }
}
