pragma solidity >=0.8.0;

import { Vm } from "forge-std/Vm.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import "forge-std/console.sol";


import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs } from "./RecordedLogs.sol";

interface IAMB {
    function requireToPassMessage(address, bytes memory, uint256) external returns (bytes32);
    function maxGasPerTx() external view returns (uint256);
    function validatorContract() external view returns (address);
}

interface IHomeAMB is IAMB {
    function executeAffirmation(bytes memory) external;
    function submitSignature(bytes memory, bytes memory) external;
}

interface IForeignAMB is IAMB {
    function executeSignatures(bytes memory, bytes memory) external;
}

interface IValidatorContract {
    function validatorList() external view returns (address[] memory);
    function requiredSignatures() external view returns (uint256);
    function owner() external view returns (address);
    function removeValidator(address) external;
    function addValidator(address) external;
}

contract GnosisDomain is BridgedDomain, StdCheats {

    bytes32 private constant USER_REQUEST_FOR_AFFIRMATION_TOPIC = keccak256("UserRequestForAffirmation(bytes32,bytes)");
    bytes32 private constant USER_REQUEST_FOR_SIGNATURE_TOPIC = keccak256("UserRequestForSignature(bytes32,bytes)");

    IForeignAMB public immutable        L1_AMB_CROSS_DOMAIN_MESSENGER;
    IHomeAMB public immutable           L2_AMB_CROSS_DOMAIN_MESSENGER;

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    mapping(address => uint256) validatorKeys;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("gnosis_chain")) {
            L1_AMB_CROSS_DOMAIN_MESSENGER = IForeignAMB(0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e);
            L2_AMB_CROSS_DOMAIN_MESSENGER = IHomeAMB(0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);
        } else {
            revert("Unsupported chain");
        }

        selectFork();

        // Switch validators to custom ones on bridged domain
        IValidatorContract L2ValidatorContract = IValidatorContract(L2_AMB_CROSS_DOMAIN_MESSENGER.validatorContract());
        address[] memory L2defaultValidators = L2ValidatorContract.validatorList();
        vm.startPrank(L2ValidatorContract.owner());
        for (uint256 i = 0; i < L2defaultValidators.length; i++) {
            L2ValidatorContract.removeValidator(L2defaultValidators[i]);

            (address newValidator, uint256 newValidatorPk) = makeAddrAndKey(string(abi.encodePacked(i)));

            L2ValidatorContract.addValidator(newValidator);
            validatorKeys[newValidator] = newValidatorPk;
        }
        vm.stopPrank();

        hostDomain.selectFork();

        // Switch validators to custom ones on host domain
        IValidatorContract L1ValidatorContract = IValidatorContract(L1_AMB_CROSS_DOMAIN_MESSENGER.validatorContract());
        address[] memory L1defaultValidators = L1ValidatorContract.validatorList();
        vm.startPrank(L1ValidatorContract.owner());
        for (uint256 i = 0; i < L1defaultValidators.length; i++) {
            L1ValidatorContract.removeValidator(L1defaultValidators[i]);
            L1ValidatorContract.addValidator(makeAddr(string(abi.encodePacked(i))));
        }
        vm.stopPrank();

        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (
                log.topics[0] == USER_REQUEST_FOR_AFFIRMATION_TOPIC
                && log.emitter == address(L1_AMB_CROSS_DOMAIN_MESSENGER)
            ) {
                IValidatorContract L2ValidatorContract = IValidatorContract(L2_AMB_CROSS_DOMAIN_MESSENGER.validatorContract());
                address[] memory validators = L2ValidatorContract.validatorList();
                uint256 requiredSignatures = L2ValidatorContract.requiredSignatures();
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

    // WORK IN PROGRESS
    function relayToHost(bool switchToHost) external override {
        selectFork();

        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < logs.length; lastToHostLogIndex++) {
            Vm.Log memory log = logs[lastToHostLogIndex];
            if (
                log.topics[0] == USER_REQUEST_FOR_SIGNATURE_TOPIC
                && log.emitter == address(L2_AMB_CROSS_DOMAIN_MESSENGER)
            ) {
                IValidatorContract L2ValidatorContract = IValidatorContract(L2_AMB_CROSS_DOMAIN_MESSENGER.validatorContract());
                address[] memory validators = L2ValidatorContract.validatorList();
                uint256 requiredSignatures = L2ValidatorContract.requiredSignatures();
                bytes memory messageToRelay = removeFirst64Bytes(log.data);
                for (uint256 i = 0; i < requiredSignatures; i++) {
                    console.log('submitSignature', validators[i]);
                    (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorKeys[validators[i]], bytes32(messageToRelay));
                    bytes memory signature = abi.encodePacked(r, s, v);
                    // vm.prank(validators[i]);
                    // L2_AMB_CROSS_DOMAIN_MESSENGER.submitSignature(signature, messageToRelay);
                }

                console.log('executeSignatures', validators[0]);
                // hostDomain.selectFork();
                // vm.prank(validators[0]);
                // L1_AMB_CROSS_DOMAIN_MESSENGER.executeSignatures(messageToRelay/* and blob of signatures */);
                // The blob of signatures:
                /*
                    * @param _signatures bytes blob with signatures to be validated.
                    * First byte X is a number of signatures in a blob,
                    * next X bytes are v components of signatures,
                    * next 32 * X bytes are r components of signatures,
                    * next 32 * X bytes are s components of signatures.
                */
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
