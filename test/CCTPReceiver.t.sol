// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { TargetContractMock } from "test/mocks/TargetContractMock.sol";

import { CCTPReceiver } from "src/receivers/CCTPReceiver.sol";

contract CCTPReceiverTest is Test {

    TargetContractMock target;

    CCTPReceiver receiver;

    address destinationMessenger = makeAddr("destinationMessenger");
    uint32  sourceDomainId       = 1;
    bytes32 sourceAuthority      = bytes32(uint256(uint160(makeAddr("sourceAuthority"))));
    address randomAddress        = makeAddr("randomAddress");

    function setUp() public {
        target = new TargetContractMock();

        receiver = new CCTPReceiver(
            destinationMessenger,
            sourceDomainId,
            sourceAuthority,
            address(target)
        );
    }

    function test_constructor() public {
        receiver = new CCTPReceiver(
            destinationMessenger,
            sourceDomainId,
            sourceAuthority,
            address(target)
        );

        assertEq(receiver.destinationMessenger(), destinationMessenger);
        assertEq(receiver.sourceDomainId(),       sourceDomainId);
        assertEq(receiver.sourceAuthority(),      sourceAuthority);
        assertEq(receiver.target(),               address(target));
    }

    function test_handleReceiveMessage_invalidSender() public {
        vm.prank(randomAddress);
        vm.expectRevert("CCTPReceiver/invalid-sender");
        receiver.handleReceiveMessage(
            sourceDomainId,
            sourceAuthority,
            abi.encodeCall(TargetContractMock.increment, ())
        );
    }

    function test_handleReceiveMessage_invalidSourceChainId() public {
        vm.prank(destinationMessenger);
        vm.expectRevert("CCTPReceiver/invalid-sourceDomain");
        receiver.handleReceiveMessage(
            2,
            sourceAuthority,
            abi.encodeCall(TargetContractMock.increment, ())
        );
    }

    function test_handleReceiveMessage_invalidSourceAuthority() public {
        vm.prank(destinationMessenger);
        vm.expectRevert("CCTPReceiver/invalid-sourceAuthority");
        receiver.handleReceiveMessage(
            sourceDomainId,
            bytes32(uint256(uint160(randomAddress))),
            abi.encodeCall(TargetContractMock.increment, ())
        );
    }

    function test_handleReceiveMessage_success() public {
        assertEq(target.count(), 0);
        vm.prank(destinationMessenger);
        bool result = receiver.handleReceiveMessage(
            sourceDomainId,
            sourceAuthority,
            abi.encodeCall(TargetContractMock.increment, ())
        );
        assertEq(result,         true);
        assertEq(target.count(), 1);
    }

    function test_handleReceiveMessage_revert() public {
        vm.prank(destinationMessenger);
        vm.expectRevert("TargetContract/error");
        receiver.handleReceiveMessage(
            sourceDomainId,
            sourceAuthority,
            abi.encodeCall(TargetContractMock.revertFunc, ())
        );
    }
    
}
