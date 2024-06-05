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
    address sourceAuthority      = makeAddr("sourceAuthority");
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
            bytes32(uint256(uint160(sourceAuthority))),
            abi.encodeCall(TargetContractMock.someFunc, ())
        );
    }

    function test_handleReceiveMessage_invalidSourceChainId() public {
        vm.prank(destinationMessenger);
        vm.expectRevert("CCTPReceiver/invalid-sourceDomain");
        receiver.handleReceiveMessage(
            2,
            bytes32(uint256(uint160(sourceAuthority))),
            abi.encodeCall(TargetContractMock.someFunc, ())
        );
    }

    function test_handleReceiveMessage_invalidSourceAuthority() public {
        vm.prank(destinationMessenger);
        vm.expectRevert("CCTPReceiver/invalid-sourceAuthority");
        receiver.handleReceiveMessage(
            sourceDomainId,
            bytes32(uint256(uint160(randomAddress))),
            abi.encodeCall(TargetContractMock.someFunc, ())
        );
    }

    function test_handleReceiveMessage_success() public {
        assertEq(target.data(), 0);
        vm.prank(destinationMessenger);
        receiver.handleReceiveMessage(
            sourceDomainId,
            bytes32(uint256(uint160(sourceAuthority))),
            abi.encodeCall(TargetContractMock.someFunc, ())
        );
        assertEq(target.data(), 1);
    }

    function test_handleReceiveMessage_revert() public {
        vm.prank(destinationMessenger);
        vm.expectRevert("error");
        receiver.handleReceiveMessage(
            sourceDomainId,
            bytes32(uint256(uint160(sourceAuthority))),
            abi.encodeCall(TargetContractMock.revertFunc, ())
        );
    }
    
}
