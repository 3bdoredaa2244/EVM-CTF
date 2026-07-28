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

    bool startCtf = false; // NOTE: turn this to true when testing

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

    function test_drainDstBridgeBalance() public {
        if (!startCtf) return;

        // Set up values
        // Source and destination chain are the same just for testing purpose
        uint256 srcChainId = block.chainid;
        uint256 dstChainId = block.chainid;

        bytes memory additionalDataEncoded;
        bytes memory recipientBytes;
        // write yourcode here

        // ...

        bytes32 sourceMessageHash = bridgeSrc.sendMessage{value: 0}(
            dstChainId,
            additionalDataEncoded,
            recipientBytes
        );

        // Owner accepts the hash on bridgeDst
        vm.prank(owner);
        bridgeDst.acceptMessageHash(sourceMessageHash);

        uint256 bridgeDstBalanceBeforeAttack = address(bridgeDst).balance;
        assertEq(
            bridgeDstBalanceBeforeAttack,
            100 ether,
            "Incorrect path execution"
        );

        // Write your own code here

        // ...

        uint256 bridgeDstBalanceAfterAttack = address(bridgeDst).balance;
        assertEq(bridgeDstBalanceAfterAttack, 0 ether, "Attack Failed");
    }
}
