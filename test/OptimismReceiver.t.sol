// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { TargetContractMock } from "test/mocks/TargetContractMock.sol";

import { OptimismReceiver } from "src/receivers/OptimismReceiver.sol";

contract OptimismMessengerMock {

    address public xDomainMessageSender;

    function __setSender(address _xDomainMessageSender) public {
        xDomainMessageSender = _xDomainMessageSender;
    }

}

contract OptimismReceiverTest is Test {

    OptimismMessengerMock l2CrossDomain;
    TargetContractMock    target;

    OptimismReceiver receiver;

    address l2CrossDomainAddr = 0x4200000000000000000000000000000000000007;

    address sourceAuthority = makeAddr("sourceAuthority");
    address randomAddress   = makeAddr("randomAddress");

    function setUp() public {
        // Set the code at the particular address
        l2CrossDomain = new OptimismMessengerMock();
        vm.etch(l2CrossDomainAddr, address(l2CrossDomain).code);
        l2CrossDomain = OptimismMessengerMock(l2CrossDomainAddr);
        l2CrossDomain.__setSender(sourceAuthority);
        
        target = new TargetContractMock();

        receiver = new OptimismReceiver(
            sourceAuthority,
            address(target)
        );
    }

    function test_constructor() public {
        receiver = new OptimismReceiver(
            sourceAuthority,
            address(target)
        );

        assertEq(receiver.l1Authority(), sourceAuthority);
        assertEq(receiver.target(),      address(target));
    }

    function test_forward_invalidSender() public {
        vm.prank(randomAddress);
        vm.expectRevert("OptimismReceiver/invalid-sender");
        TargetContractMock(address(receiver)).someFunc();
    }

    function test_forward_invalidL1Authority() public {
        l2CrossDomain.__setSender(randomAddress);
        
        vm.prank(address(l2CrossDomain));
        vm.expectRevert("OptimismReceiver/invalid-l1Authority");
        TargetContractMock(address(receiver)).someFunc();
    }

    function test_forward_success() public {
        assertEq(target.data(), 0);
        vm.prank(address(l2CrossDomain));
        TargetContractMock(address(receiver)).someFunc();
        assertEq(target.data(), 1);
    }

    function test_forward_revert() public {
        vm.prank(address(l2CrossDomain));
        vm.expectRevert("error");
        TargetContractMock(address(receiver)).revertFunc();
    }
    
}
