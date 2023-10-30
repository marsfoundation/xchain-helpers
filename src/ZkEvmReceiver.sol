// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IZkEvmBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable;
}

/**
 * @title ZkEvmReceiver
 * @notice Receive messages to a zkevm chain
 */
abstract contract ZkEvmReceiver is IZkEvmBridgeMessageReceiver {
    address public immutable l1Authority;
    address constant bridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

    constructor(address _l1Authority) {
        l1Authority = _l1Authority;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Receiver/invalid-sender");
        _;
    }

    function onMessageReceived(address originAddress, uint32, /*originNetwork*/ bytes calldata data) external payable {
        require(msg.sender == bridge, "Receiver/invalid-caller");
        require(originAddress == l1Authority, "Receiver/invalid-l1Authority");
        (bool success, bytes memory ret) = address(this).call(data);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}
