// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { Address } from "openzeppelin-contracts/contracts/utils/Address.sol";

interface ICrossDomainOptimism {
    function xDomainMessageSender() external view returns (address);
}

/**
 * @title  OptimismReceiver
 * @notice Receive messages to an Optimism-style chain.
 */
contract OptimismReceiver {

    using Address for address;

    ICrossDomainOptimism public constant l2CrossDomain = ICrossDomainOptimism(0x4200000000000000000000000000000000000007);

    address public immutable l1Authority;
    address public immutable target;

    constructor(
        address _l1Authority,
        address _target
    ) {
        l1Authority = _l1Authority;
        target      = _target;
    }

    fallback(bytes calldata message) external returns (bytes memory) {
        require(msg.sender == address(l2CrossDomain),                "OptimismReceiver/invalid-sender");
        require(l2CrossDomain.xDomainMessageSender() == l1Authority, "OptimismReceiver/invalid-l1Authority");

        return target.functionCall(message);
    }

}
