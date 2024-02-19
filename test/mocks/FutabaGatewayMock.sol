// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IGateway } from "../../src/interfaces/IGateway.sol";
import { IReceiver } from "../../src/interfaces/IReceiver.sol";
import { QueryType } from "../../src/QueryType.sol";

contract FutabaGatewayMock is IGateway {
    uint256 private _nonce = 1;

    enum QueryStatus {
        Pending, // Waiting for query results
        Success, // Query succeeded
        Failed // Query failed

    }

    struct Query {
        bytes data; // `encode(callBack, queries, message, lightClient)`
        QueryStatus status;
    }

    // query id => Query
    mapping(bytes32 queryId => Query query) public queryStore;

    function query(
        QueryType.QueryRequest[] memory queries,
        address lightClient,
        address callBack,
        bytes calldata message
    )
        external
        payable
    {
        bytes memory encodedPayload = abi.encode(callBack, queries, message, lightClient);
        bytes32 queryId = keccak256(abi.encodePacked(_nonce));

        queryStore[queryId] = Query(encodedPayload, QueryStatus.Pending);
        ++_nonce;
    }

    function receiveQuery(bytes32 queryId) external payable {
        Query memory storedQuery = queryStore[queryId];

        bytes[] memory results = new bytes[](1);
        // covert uint256 to bytes
        results[0] = abi.encodePacked(bytes32(uint256(100_000)));

        (address callBack, QueryType.QueryRequest[] memory queries, bytes memory message, address lc) =
            abi.decode(storedQuery.data, (address, QueryType.QueryRequest[], bytes, address));

        try IReceiver(callBack).receiveQuery(queryId, results, queries, message) {
            queryStore[queryId].status = QueryStatus.Success;
        } catch Error(string memory reason) {
            queryStore[queryId].status = QueryStatus.Failed;
        }
    }

    function getNonce() external view returns (uint256) {
        return _nonce;
    }

    function estimateFee(
        address lightClient,
        QueryType.QueryRequest[] memory queries
    )
        external
        view
        returns (uint256)
    {
        return 100_000;
    }
}
