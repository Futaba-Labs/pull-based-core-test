// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { AxelarExecutable } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";

contract Deposit is AxelarExecutable {
    mapping(address user => uint256 balance) public balances;

    struct DepositUpdateParam {
        address user;
        uint256 amount;
    }

    event DepositUpdate(DepositUpdateParam param);
    event Deposited(address indexed user, uint256 amount);

    constructor(address gateway_) AxelarExecutable(gateway_) { }

    function deposit(uint256 _amount) external payable {
        // Update the balance
        balances[msg.sender] += _amount;

        // Emit the event
        emit Deposited(msg.sender, _amount);
    }

    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload_
    )
        internal
        virtual
        override
    {
        // Decode the payload
        DepositUpdateParam[] memory params = abi.decode(payload_, (DepositUpdateParam[]));
        uint256 len = params.length;

        for (uint256 i = 0; i < len; i++) {
            DepositUpdateParam memory param = params[i];
            address user = param.user;
            uint256 amount = param.amount;

            // Update the balance
            balances[user] -= amount;

            // Emit the event
            emit DepositUpdate(DepositUpdateParam(user, balances[user]));
        }
    }
}
