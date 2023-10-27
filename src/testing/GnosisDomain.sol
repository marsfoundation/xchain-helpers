// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs }          from "./RecordedLogs.sol";

interface IAMB {
    function requireToPassMessage(address, bytes memory, uint256) external returns (bytes32);
    function validatorContract() external view returns (address);
}

interface IHomeAMB is IAMB {
    function executeAffirmation(bytes memory) external;
}

interface IForeignAMB is IAMB {
    function executeSignatures(bytes memory, bytes memory) external;
}

interface IValidatorContract {
    function validatorList() external view returns (address[] memory);
    function requiredSignatures() external view returns (uint256);
}

contract GnosisDomain is BridgedDomain {

    bytes32 private constant USER_REQUEST_FOR_AFFIRMATION_TOPIC = keccak256("UserRequestForAffirmation(bytes32,bytes)");
    bytes32 private constant USER_REQUEST_FOR_SIGNATURE_TOPIC   = keccak256("UserRequestForSignature(bytes32,bytes)");

    IForeignAMB public L1_AMB_CROSS_DOMAIN_MESSENGER;
    IHomeAMB public    L2_AMB_CROSS_DOMAIN_MESSENGER;

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("gnosis_chain")) {
            L1_AMB_CROSS_DOMAIN_MESSENGER = IForeignAMB(0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e);
            L2_AMB_CROSS_DOMAIN_MESSENGER = IHomeAMB(0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);
        } else if (name == keccak256("chiado")) {
            L1_AMB_CROSS_DOMAIN_MESSENGER = IForeignAMB(0x87A19d769D875964E9Cd41dDBfc397B2543764E6);
            L2_AMB_CROSS_DOMAIN_MESSENGER = IHomeAMB(0x99Ca51a3534785ED619f46A79C7Ad65Fa8d85e7a);
        } else {
            revert("Unsupported chain");
        }

        hostDomain.selectFork();

        // Set minimum required signatures on L1 to 0
        IValidatorContract validatorContract = IValidatorContract(L1_AMB_CROSS_DOMAIN_MESSENGER.validatorContract());
        vm.store(
            address(validatorContract),
            0x8a247e09a5673bd4d93a4e76d8fb9553523aa0d77f51f3d576e7421f5295b9bc,
            0
        );

        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork(); // switch to Gnosis domain

        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (
                log.topics[0] == USER_REQUEST_FOR_AFFIRMATION_TOPIC
                && log.emitter == address(L1_AMB_CROSS_DOMAIN_MESSENGER)
            ) {
                IValidatorContract validatorContract = IValidatorContract(L2_AMB_CROSS_DOMAIN_MESSENGER.validatorContract());
                address[] memory validators = validatorContract.validatorList();
                uint256 requiredSignatures = validatorContract.requiredSignatures();
                bytes memory messageToRelay = removeFirst64Bytes(log.data);
                for (uint256 i = 0; i < requiredSignatures; i++) {
                    vm.prank(validators[i]);
                    L2_AMB_CROSS_DOMAIN_MESSENGER.executeAffirmation(messageToRelay);
                }
            }
        }

        if (!switchToGuest) {
            hostDomain.selectFork();
        }
    }

    function relayToHost(bool switchToHost) external override {
        hostDomain.selectFork();

        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < logs.length; lastToHostLogIndex++) {
            Vm.Log memory log = logs[lastToHostLogIndex];
            if (
                log.topics[0] == USER_REQUEST_FOR_SIGNATURE_TOPIC
                && log.emitter == address(L2_AMB_CROSS_DOMAIN_MESSENGER)
            ) {
                bytes memory messageToRelay = removeFirst64Bytes(log.data);
                L1_AMB_CROSS_DOMAIN_MESSENGER.executeSignatures(messageToRelay, abi.encodePacked(uint256(0)));
            }
        }

        if (!switchToHost) {
            selectFork();
        }
    }

    function removeFirst64Bytes(bytes memory inputData) public pure returns (bytes memory) {
        bytes memory returnValue = new bytes(inputData.length - 64);
        for (uint256 i = 0; i < inputData.length - 64; i++) {
            returnValue[i] = inputData[i + 64];
        }
        return returnValue;
    }

}
