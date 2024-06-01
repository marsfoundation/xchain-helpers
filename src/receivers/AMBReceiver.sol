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
    bytes32                   public immutable chainId;
    address                   public immutable sourceAuthority;
    address                   public immutable target;

    constructor(
        address _amb,
        uint256 _chainId,
        address _authority,
        address _target
    ) {
        amb       = IArbitraryMessagingBridge(_amb);
        chainId   = bytes32(_chainId);
        authority = _authority;
        target    = _target;
    }

    function forward(bytes memory message) external {
        require(msg.sender == address(amb),                       "AMBReceiver/invalid-sender");
        require(l2CrossDomain.messageSourceChainId() == chainId,  "AMBReceiver/invalid-chainId");
        require(l2CrossDomain.messageSender() == sourceAuthority, "AMBReceiver/invalid-sourceAuthority");

        (bool success, bytes memory ret) = target.call(message);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }

}
