// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { Bridge }                from "src/testing/Bridge.sol";
import { Domain, DomainHelpers } from "src/testing/Domain.sol";

contract MessageOrdering {

    address   public receiver;
    uint256[] public messages;

    function push(uint256 messageId) external {
        require(msg.sender == receiver, "only-receiver");

        messages.push(messageId);
    }

    function length() public view returns (uint256) {
        return messages.length;
    }

    function setReceiver(address _receiver) external {
        receiver = _receiver;
    }

}

abstract contract IntegrationBaseTest is Test {

    using DomainHelpers for *;

    address sourceAuthority      = makeAddr("sourceAuthority");
    address destinationAuthority = makeAddr("destinationAuthority");
    address randomAddress        = makeAddr("randomAddress");

    Domain source;
    Domain destination;

    MessageOrdering moSource;
    MessageOrdering moDestination;

    function setUp() public {
        source = getChain("mainnet").createFork();

        source.selectFork();
        moSource = new MessageOrdering();
    }

    function initDestination(Domain memory _destination) internal {
        destination = _destination;

        destination.selectFork();
        moDestination = new MessageOrdering();

        moDestination.setReceiver(initDestinationReceiver(address(moDestination)));
    }

    function initDestinationReceiver(address target) internal virtual returns (address receiver);

}
