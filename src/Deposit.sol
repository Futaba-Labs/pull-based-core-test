// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

import { ILayerZeroReceiver } from "./interfaces/ILayerZeroReceiver.sol";

contract Deposit is ILayerZeroReceiver {
    mapping(address user => uint256 balance) public balances;

    struct DepositUpdateParam {
        address user;
        uint256 amount;
    }

    event DepositUpdate(DepositUpdateParam param);
    event Deposited(address indexed user, uint256 amount);

    function deposit(uint256 _amount) external payable {
        // Update the balance
        balances[msg.sender] += _amount;

        // Emit the event
        emit Deposited(msg.sender, _amount);
    }

    /// @dev Simple code, so no access control
    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    )
        external
    {
        // Decode the payload
        DepositUpdateParam[] memory params = abi.decode(_payload, (DepositUpdateParam[]));
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
