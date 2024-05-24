// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { Bridge }                from "src/testing/Bridge.sol";
import { Domain, DomainHelpers } from "src/testing/Domain.sol";

import { XChainForwarders } from "../src/XChainForwarders.sol";

contract MessageOrdering {

    uint256[] public messages;

    function push(uint256 messageId) public virtual {
        messages.push(messageId);
    }

    function length() public view returns (uint256) {
        return messages.length;
    }

}

abstract contract IntegrationBaseTest is Test {

    using DomainHelpers for *;

    Domain mainnet;

    address l1Authority = makeAddr("l1Authority");
    address notL1Authority = makeAddr("notL1Authority");

    function setUp() public {
        mainnet = getChain("mainnet").createFork();
    }

}
