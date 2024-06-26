// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { Address } from "openzeppelin-contracts/contracts/utils/Address.sol";

/**
 * @title  CCTPReceiver
 * @notice Receive messages from CCTP-style bridge.
 */
contract CCTPReceiver {

    using Address for address;

    address public immutable destinationMessenger;
    uint32  public immutable sourceDomainId;
    bytes32 public immutable sourceAuthority;
    address public immutable target;

    constructor(
        address _destinationMessenger,
        uint32  _sourceDomainId,
        bytes32 _sourceAuthority,
        address _target
    ) {
        destinationMessenger = _destinationMessenger;
        sourceDomainId       = _sourceDomainId;
        sourceAuthority      = _sourceAuthority;
        target               = _target;
    }

    function handleReceiveMessage(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool) {
        require(msg.sender == destinationMessenger, "CCTPReceiver/invalid-sender");
        require(sourceDomainId == sourceDomain,     "CCTPReceiver/invalid-sourceDomain");
        require(sender == sourceAuthority,          "CCTPReceiver/invalid-sourceAuthority");

        target.functionCall(messageBody);

        return true;
    }

}
