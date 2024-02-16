// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

import { ILayerZeroEndpoint } from "./interfaces/ILayerZeroEndpoint.sol";
import { IReceiver } from "./interfaces/IReceiver.sol";
import { IGateway } from "./interfaces/IGateway.sol";
import { IStargateRouter } from "./interfaces/IStargateRouter.sol";
import { QueryType } from "./QueryType.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Withdraw is IReceiver {
    uint256 public constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint16 public constant SEPOLIA_DOMAIN = 10_161;
    address public lzEndpoint;
    address public stargateRouter;
    address public futabaEndpoint;
    address public lightClient;
    address public deposit;
    address public nativeWrap;

    uint256 private _nonce;

    enum BridgeStatus {
        PeindingQuery,
        Bridged,
        Batched,
        Finalized
    }

    mapping(bytes32 id => Bridge bridges) public bridges;

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
        address _lzEndpoint,
        address _futabaEndpoint,
        address _deposit,
        address _lightClient,
        address _stargateRouter,
        address _nativeWrap
    ) {
        lzEndpoint = _lzEndpoint;
        futabaEndpoint = _futabaEndpoint;
        deposit = _deposit;
        lightClient = _lightClient;
        stargateRouter = _stargateRouter;
        nativeWrap = _nativeWrap;
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
    {
        // query the deposit contract
        QueryType.QueryRequest[] memory queries = new QueryType.QueryRequest[](1);
        queries[0] = QueryType.QueryRequest(SEPOLIA_CHAIN_ID, deposit, _height, _slot);

        bytes32 id = keccak256(abi.encodePacked(msg.sender, _dstChainId, _amount, _nonce));

        IGateway(futabaEndpoint).query{ value: _futabaFee }(queries, lightClient, address(this), abi.encodePacked(id));

        // store the bridge data
        Bridge memory bridge = Bridge(msg.sender, _dstChainId, _amount, BridgeStatus.PeindingQuery);
        bridges[id] = bridge;
        _nonce++;
    }

    function receiveQuery(
        bytes32 queryId,
        bytes[] memory results,
        QueryType.QueryRequest[] memory queries,
        bytes memory message
    )
        public
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
        (uint256 fee, uint256 poolId) = quoteLayerZeroFee(dstChainId, sender);

        // swap use stargate
        _swap(amount, sender, fee);

        // update the bridge status
        bridge.status = BridgeStatus.Bridged;

        batches.push(id);

        emit Bridged(sender, amount);
    }

    function batchToL1() external {
        // send message to L1 using LayerZero
        bytes memory callData = _sendMessage();

        // update the bridge status
        uint256 len = batches.length;
        for (uint256 i; i < len; i++) {
            bridges[batches[i]].status = BridgeStatus.Batched;
        }

        // empty the batches
        delete batches;

        emit BatchToL1(callData);
    }

    function quoteLayerZeroFee(uint16 dstChainId, address to) public view returns (uint256, uint256) {
        bytes memory toAddress = abi.encodePacked(to);

        return IStargateRouter(stargateRouter).quoteLayerZeroFee(
            dstChainId, 1, toAddress, bytes(""), IStargateRouter.lzTxObj(0, 0, "0x")
        );
    }

    function _sendMessage() internal returns (bytes memory) {
        // send message to L1 using LayerZero
        bytes memory trustedRemote = abi.encodePacked(deposit, address(this));

        bytes memory callData = abi.encodePacked(batches);

        ILayerZeroEndpoint(lzEndpoint).send{ value: msg.value }(
            SEPOLIA_DOMAIN, // destination LayerZero chainId
            trustedRemote, // send to this address on the destination
            callData, // bytes payload
            payable(address(this)), // refund address
            address(0x0), // future parameter
            bytes("") // adapterParams (see "Advanced Features")
        );

        return callData;
    }

    function _swap(uint256 _amount, address _to, uint256 _fee) internal {
        bytes memory to = abi.encodePacked(_to);

        IStargateRouter(stargateRouter).swapETHAndCall{ value: _amount + _fee }(
            SEPOLIA_DOMAIN,
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
}