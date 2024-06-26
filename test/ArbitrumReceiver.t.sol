// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { TargetContractMock } from "test/mocks/TargetContractMock.sol";

import { ArbitrumReceiver } from "src/receivers/ArbitrumReceiver.sol";

contract ArbitrumReceiverTest is Test {

    TargetContractMock target;

    ArbitrumReceiver receiver;

    address sourceAuthority = makeAddr("sourceAuthority");
    address sourceAuthorityWithOffset;
    address randomAddress   = makeAddr("randomAddress");

    function setUp() public {
        target = new TargetContractMock();

        receiver = new ArbitrumReceiver(
            sourceAuthority,
            address(target)
        );
        unchecked {
            sourceAuthorityWithOffset = address(uint160(sourceAuthority) + uint160(0x1111000000000000000000000000000000001111));
        }
    }

    function test_constructor() public {
        receiver = new ArbitrumReceiver(
            sourceAuthority,
            address(target)
        );

        assertEq(receiver.l1Authority(), sourceAuthority);
        assertEq(receiver.target(),      address(target));
    }

    function test_forward_invalidL1Authority() public {
        vm.prank(randomAddress);
        vm.expectRevert("ArbitrumReceiver/invalid-l1Authority");
        TargetContractMock(address(receiver)).increment();
    }

    function test_forward_invalidL1AuthoritySourceAuthorityNoOffset() public {
        vm.prank(sourceAuthority);
        vm.expectRevert("ArbitrumReceiver/invalid-l1Authority");
        TargetContractMock(address(receiver)).increment();
    }

    function test_forward_success() public {
        assertEq(target.count(), 0);
        vm.prank(sourceAuthorityWithOffset);
        TargetContractMock(address(receiver)).increment();
        assertEq(target.count(), 1);
    }

    function test_forward_revert() public {
        vm.prank(sourceAuthorityWithOffset);
        vm.expectRevert("TargetContract/error");
        TargetContractMock(address(receiver)).revertFunc();
    }
    
}
