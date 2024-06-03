// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IArbitraryMessagingBridge {
    function messageSender() external view returns (address);
    function messageSourceChainId() external view returns (bytes32);
}

/**
 * @title  AMBReceiver
 * @notice Receive messages to AMB-style chain.
 */
contract AMBReceiver {

    IArbitraryMessagingBridge public immutable amb;
    bytes32                   public immutable sourceChainId;
    address                   public immutable sourceAuthority;
    address                   public immutable target;

    constructor(
        address _amb,
        bytes32 _sourceChainId,
        address _sourceAuthority,
        address _target
    ) {
        amb             = IArbitraryMessagingBridge(_amb);
        sourceChainId   = _sourceChainId;
        sourceAuthority = _sourceAuthority;
        target          = _target;
    }

    function forward(bytes memory message) external {
        require(msg.sender == address(amb),                  "AMBReceiver/invalid-sender");
        require(amb.messageSourceChainId() == sourceChainId, "AMBReceiver/invalid-sourceChainId");
        require(amb.messageSender() == sourceAuthority,      "AMBReceiver/invalid-sourceAuthority");

        (bool success, bytes memory ret) = target.call(message);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }

}
