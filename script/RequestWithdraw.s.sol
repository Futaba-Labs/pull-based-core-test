// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Withdraw } from "../src/Withdraw.sol";
import { ILayerZeroEndpoint } from "../src/interfaces/ILayerZeroEndpoint.sol";
import { IGateway } from "../src/interfaces/IGateway.sol";
import { QueryType } from "../src/QueryType.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract RequestWithdraw is BaseScript {
    Withdraw withdraw = Withdraw(0x6086cAa91C793aE55cA5864ef48371a55a681192);
    address lzEndpoint = 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3;
    address futabaEndpoint = 0x00EF9F95500621f08C25587106d4D362b9db9225;
    address lightClient = 0x997ae35162766C4aF4623EEa4faB6F484bC4593c;
    address deposit = 0xFf598258cFeafDcA634b24b5C4194c9F38a1d816;
    uint16 dstChainId = 10_232; // Optimism Sepolia
    address to = 0xc92FE6Db0a49C339E1D56eB23ECF6a7251aac67C;
    uint256 amount = 0.01 ether;
    uint256 height = 5_321_180;
    bytes32 slot = 0xf087e503ff996f9bdc465ff4979b6a3d6990ddff95eb6ec9b95f534abba7a298;

    function run() public broadcast {
        // estimate staragte fee
        (uint256 sgFee, uint256 poolId) = withdraw.quoteStaragteFee(dstChainId, to);

        // estimate futaba fee
        QueryType.QueryRequest[] memory queries = new QueryType.QueryRequest[](1);
        queries[0] = QueryType.QueryRequest(
            11_155_111, // Sepolia chain id
            deposit,
            height,
            slot
        );
        uint256 futabaFee = IGateway(futabaEndpoint).estimateFee(0x997ae35162766C4aF4623EEa4faB6F484bC4593c, queries);

        // exexute withdraw
        withdraw.withdraw{ value: sgFee + futabaFee }(dstChainId, amount, height, slot, futabaFee);
    }
}
