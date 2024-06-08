// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { Address } from "lib/openzeppelin-contracts/contracts/utils/Address.sol";

interface IArbitraryMessagingBridge {
    function messageSender() external view returns (address);
    function messageSourceChainId() external view returns (bytes32);
}

/**
 * @title  AMBReceiver
 * @notice Receive messages to AMB-style chain.
 */
contract AMBReceiver {

    using Address for address;

    address public immutable amb;
    bytes32 public immutable sourceChainId;
    address public immutable sourceAuthority;
    address public immutable target;

    constructor(
        address _amb,
        bytes32 _sourceChainId,
        address _sourceAuthority,
        address _target
    ) {
        amb             = _amb;
        sourceChainId   = _sourceChainId;
        sourceAuthority = _sourceAuthority;
        target          = _target;
    }

    fallback(bytes calldata message) external returns (bytes memory) {
        require(msg.sender == amb,                                                      "AMBReceiver/invalid-sender");
        require(IArbitraryMessagingBridge(amb).messageSourceChainId() == sourceChainId, "AMBReceiver/invalid-sourceChainId");
        require(IArbitraryMessagingBridge(amb).messageSender() == sourceAuthority,      "AMBReceiver/invalid-sourceAuthority");

        return target.functionCall(message);
    }

}
