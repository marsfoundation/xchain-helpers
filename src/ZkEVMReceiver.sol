// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IZkEVMBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable;
}

/**
 * @title ZkEVMReceiver
 * @notice Receive messages to a zkevm chain
 */
abstract contract ZkEVMReceiver is IZkEVMBridgeMessageReceiver {
    address public immutable l1Authority;
    uint32  public immutable originNetworkId;
    address public constant  bridge          = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

    constructor(address _l1Authority, uint32 _originNetworkId) {
        l1Authority = _l1Authority;
        originNetworkId = _originNetworkId;
    }

    modifier onlyCrossChainMessage() {
        require(msg.sender == address(this), "Receiver/invalid-sender");
        _;
    }

    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable {
        require(msg.sender == bridge,             "Receiver/invalid-sender");
        require(originNetwork == originNetworkId, "Receiver/invalid-originNetwork");
        require(originAddress == l1Authority,     "Receiver/invalid-l1Authority");
        (bool success, bytes memory ret) = address(this).call(data);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}
