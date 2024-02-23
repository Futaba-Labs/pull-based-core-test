// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";

import { Withdraw } from "../src/Withdraw.sol";
import { DepositMock } from "./mocks/DepositMock.sol";
import { FutabaGatewayMock } from "./mocks/FutabaGatewayMock.sol";
import { AxelarGatewayMock } from "./mocks/AxelarGatewayMock.sol";
import { AxelarGasServiceMock } from "./mocks/AxelarGasServiceMock.sol";
import { StargateRouterMock } from "./mocks/StargateRouterMock.sol";

contract WithdrawTest is PRBTest, StdCheats {
    enum BridgeStatus {
        PeindingQuery,
        Bridged,
        Batched,
        Finalized
    }

    Withdraw public withdraw;
    FutabaGatewayMock public futabaGateway;
    AxelarGatewayMock public axelarGateway;
    AxelarGasServiceMock public axelarGasService;
    StargateRouterMock public stargateRouter;
    DepositMock public deposit;
    address public lightClient = address(this);

    function setUp() public virtual {
        // Instantiate the contract-under-test.
        deposit = new DepositMock(lightClient);
        futabaGateway = new FutabaGatewayMock();
        axelarGateway = new AxelarGatewayMock();
        axelarGasService = new AxelarGasServiceMock();
        stargateRouter = new StargateRouterMock();

        withdraw = new Withdraw(
            address(axelarGateway),
            address(axelarGasService),
            address(futabaGateway),
            address(deposit),
            lightClient,
            address(stargateRouter)
        );
    }

    function test_Withdraw() external {
        uint16 dstChainId = 10_232;
        uint256 amount = 1000;
        uint256 height = 10_000;
        bytes32 slot = bytes32("0");
        uint256 futabaFee = 100;

        withdraw.withdraw{ value: 200 }(dstChainId, amount, height, slot, futabaFee);
        uint256 nonce = withdraw.getNonce();
        bytes32 id = keccak256(abi.encodePacked(address(this), dstChainId, amount, nonce - 1));

        Withdraw.Bridge memory bridge = withdraw.getBridge(id);

        assertEq(bridge.user, address(this));
        assertEq(bridge.dstChainId, dstChainId);
        assertEq(bridge.amount, amount);
        assertEq(uint256(bridge.status), uint256(BridgeStatus.PeindingQuery));
    }

    function test_ReceiveQuery() external {
        uint16 dstChainId = 10_232;
        uint256 amount = 1000;
        uint256 height = 10_000;
        bytes32 slot = bytes32("0");
        uint256 futabaFee = 100;
        uint256 lzFee = 100;

        withdraw.withdraw{ value: amount + futabaFee + lzFee }(dstChainId, amount, height, slot, futabaFee);
        uint256 withdrawNonce = withdraw.getNonce();
        bytes32 id = keccak256(abi.encodePacked(address(this), dstChainId, amount, withdrawNonce - 1));

        Withdraw.Bridge memory bridge = withdraw.getBridge(id);

        assertEq(bridge.user, address(this));
        assertEq(bridge.dstChainId, dstChainId);
        assertEq(bridge.amount, amount);
        assertEq(uint256(bridge.status), uint256(BridgeStatus.PeindingQuery));

        uint256 futabaNonce = futabaGateway.getNonce();
        bytes32 queryId = keccak256(abi.encodePacked(futabaNonce - 1));

        futabaGateway.receiveQuery(queryId);

        bridge = withdraw.getBridge(id);
        assertEq(uint256(bridge.status), uint256(BridgeStatus.Bridged));

        bytes32[] memory batches = withdraw.getBatches();
        assertEq(batches.length, 1);
        assertEq(batches[0], id);
    }

    function test_BatchToL1() external {
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 10_000;
        amounts[1] = 20_000;
        amounts[2] = 30_000;
        amounts[3] = 40_000;
        amounts[4] = 50_000;

        bytes32[] memory ids = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            _requestWithdraw(amounts[i]);
            uint256 withdrawNonce = withdraw.getNonce();
            uint16 dstChainId = 10_232;
            ids[i] = keccak256(abi.encodePacked(address(this), dstChainId, amounts[i], withdrawNonce - 1));
        }

        withdraw.batchToL1();
        assertEq(withdraw.getBatches().length, 0);

        for (uint256 i = 0; i < 5; i++) {
            Withdraw.Bridge memory bridge = withdraw.getBridge(ids[i]);
            assertEq(uint256(bridge.status), uint256(BridgeStatus.Batched));
        }
    }

    function _requestWithdraw(uint256 _amount) internal {
        uint16 dstChainId = 10_232;
        uint256 height = 10_000;
        bytes32 slot = bytes32("0");
        uint256 futabaFee = 100;
        uint256 lzFee = 100;

        withdraw.withdraw{ value: _amount + futabaFee + lzFee }(dstChainId, _amount, height, slot, futabaFee);

        uint256 futabaNonce = futabaGateway.getNonce();
        bytes32 queryId = keccak256(abi.encodePacked(futabaNonce - 1));

        futabaGateway.receiveQuery(queryId);
    }
}
