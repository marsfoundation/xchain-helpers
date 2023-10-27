// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { Domain } from "../src/testing/Domain.sol";

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

    Domain mainnet;
    Domain goerli;

    address l1Authority = makeAddr("l1Authority");
    address notL1Authority = makeAddr("notL1Authority");

    function setUp() public {
        mainnet = new Domain(getChain("mainnet"));
        goerli = new Domain(getChain("goerli"));
    }

}
