// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IReceiver } from "./interfaces/IReceiver.sol";
import { IGateway } from "./interfaces/IGateway.sol";
import { IStargateRouter } from "./interfaces/IStargateRouter.sol";
import { QueryType } from "./QueryType.sol";
import { AxelarExecutable } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import { IAxelarGasService } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import { IAxelarGateway } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract Withdraw is IReceiver, AxelarExecutable {
    uint256 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    string SEPOLIA_DOMAIN = "ethereum-sepolia";
    address public axelarGasService;
    address public stargateRouter;
    address public futabaEndpoint;
    address public lightClient;
    address public deposit;

    uint256 private _nonce = 1;

    enum BridgeStatus {
        PeindingQuery,
        Bridged,
        Batched,
        Finalized,
        Error
    }

    mapping(bytes32 id => Bridge bridge) public bridges;
    mapping(address user => uint256 balance) public nonFinalizedBalances;

    bytes32[] batches;

    struct DepositUpdateParam {
        address user;
        uint256 amount;
    }

    struct Bridge {
        address user;
        uint16 dstChainId;
        uint256 amount;
        BridgeStatus status;
    }

    constructor(
        address _axelerGateway,
        address _axealrGasService,
        address _futabaEndpoint,
        address _deposit,
        address _lightClient,
        address _stargateRouter
    )
        AxelarExecutable(_axelerGateway)
    {
        axelarGasService = _axealrGasService;
        futabaEndpoint = _futabaEndpoint;
        deposit = _deposit;
        lightClient = _lightClient;
        stargateRouter = _stargateRouter;
    }

    event Bridged(address indexed user, uint256 amount);
    event BatchToL1(bytes callData);

    error InsufficientBalance();

    function withdraw(
        uint16 _dstChainId,
        uint256 _amount,
        uint256 _height,
        bytes32 _slot,
        uint256 _futabaFee
    )
        external
        payable
    {
        // query the deposit contract
        QueryType.QueryRequest[] memory queries = new QueryType.QueryRequest[](1);
        queries[0] = QueryType.QueryRequest(SEPOLIA_CHAIN_ID, deposit, _height, _slot);

        bytes32 id = keccak256(abi.encodePacked(msg.sender, _dstChainId, _amount, _nonce));

        IGateway(futabaEndpoint).query{ value: _futabaFee }(queries, lightClient, address(this), abi.encodePacked(id));

        // store the bridge data
        Bridge memory b = Bridge(msg.sender, _dstChainId, _amount, BridgeStatus.PeindingQuery);
        bridges[id] = b;
        nonFinalizedBalances[msg.sender] += _amount;
        ++_nonce;
    }

    function receiveQuery(
        bytes32 queryId,
        bytes[] memory results,
        QueryType.QueryRequest[] memory queries,
        bytes memory message
    )
        public
        payable
    {
        // check the deposit state
        bytes32 id = abi.decode(message, (bytes32));
        Bridge storage bridge = bridges[id];
        uint16 dstChainId = bridge.dstChainId;
        address sender = bridge.user;
        uint256 amount = bridge.amount;

        uint256 depositedAmount = uint256(bytes32(results[0]));
        if (depositedAmount < amount) {
            revert InsufficientBalance();
        }

        // query stargate fee
        (uint256 fee, uint256 poolId) = quoteStaragteFee(dstChainId, sender);

        // swap use stargate
        _swap(dstChainId, amount, sender, fee);

        // update the bridge status
        bridge.status = BridgeStatus.Bridged;

        batches.push(id);

        emit Bridged(sender, amount);
    }

    function batchToL1() external payable {
        // send message to L1 using LayerZero
        bytes memory callData = _sendMessage();

        // update the bridge status
        uint256 len = batches.length;
        for (uint256 i; i < len; i++) {
            Bridge memory b = bridges[batches[i]];
            b.status = BridgeStatus.Batched;
        }

        // empty the batches
        delete batches;

        emit BatchToL1(callData);
    }

    function quoteStaragteFee(uint16 dstChainId, address to) public view returns (uint256, uint256) {
        bytes memory toAddress = abi.encodePacked(to);

        return IStargateRouter(stargateRouter).quoteLayerZeroFee(
            dstChainId, 1, toAddress, bytes(""), IStargateRouter.lzTxObj(0, 0, "0x")
        );
    }

    function getNonce() external view returns (uint256) {
        return _nonce;
    }

    function getBridge(bytes32 _id) external view returns (Bridge memory) {
        return bridges[_id];
    }

    function getBatches() external view returns (bytes32[] memory) {
        return batches;
    }

    function sendToL1(DepositUpdateParam[] memory params) external payable {
        bytes memory callData = abi.encode(params);
        string memory destinationAddress = addressToString(deposit);

        IAxelarGasService(axelarGasService).payNativeGasForContractCall{ value: msg.value }(
            address(this), SEPOLIA_DOMAIN, destinationAddress, callData, msg.sender
        );
        gateway.callContract(SEPOLIA_DOMAIN, destinationAddress, callData);
    }

    function bridge(uint16 _dstchainId, uint256 _amount, address _to, uint256 _fee) external payable {
        _swap(_dstchainId, _amount, _to, _fee);
    }

    function _sendMessage() internal returns (bytes memory) {
        uint256 len = batches.length;
        DepositUpdateParam[] memory params = new DepositUpdateParam[](len);
        for (uint256 i; i < len; i++) {
            Bridge memory b = bridges[batches[i]];
            params[i] = DepositUpdateParam(b.user, b.amount);
        }
        bytes memory callData = abi.encodePacked(batches);
        string memory destinationAddress = addressToString(deposit);

        IAxelarGasService(axelarGasService).payNativeGasForContractCall{ value: msg.value }(
            address(this), SEPOLIA_DOMAIN, destinationAddress, callData, msg.sender
        );
        gateway.callContract(SEPOLIA_DOMAIN, destinationAddress, callData);

        return callData;
    }

    function _swap(uint16 _dstchainId, uint256 _amount, address _to, uint256 _fee) internal {
        bytes memory to = abi.encodePacked(_to);

        IStargateRouter(stargateRouter).swapETHAndCall{ value: _amount + _fee }(
            _dstchainId,
            payable(address(this)),
            to,
            IStargateRouter.SwapAmount(_amount, 0),
            IStargateRouter.lzTxObj(0, 0, "0x"),
            bytes("")
        );
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IReceiver).interfaceId;
    }

    function addressToString(address _addr) internal pure returns (string memory) {
        return Strings.toHexString(uint160(_addr), 20);
    }
}
