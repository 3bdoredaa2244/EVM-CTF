// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {CairoVault} from "../src/CairoVault.sol";

contract CairoVaultTest is Test {
    CairoVault public vault;

    address public owner = makeAddr("owner");
    address public attacker = makeAddr("attacker");

    bytes32 secretHash =
        0xb49efa2eaac608a3de1faa12ade1a60f85aa0fd66b48df80e144410b410ff05d;

    bool startCtf = false; // NOTE: turn this to true when testing

    function setUp() public {
        // Owner deploys the vault with 10 ETH. Only keccak256(SECRET) is public.
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        vault = new CairoVault{value: 10 ether}(owner, secretHash);

        assertEq(address(vault).balance, 10 ether, "vault not funded");
    }

    function test_DrainCairoVault() public {
        if (!startCtf) return;
        assertEq(attacker.balance, 0);

        // Write your code here

        assertTrue(attacker != vault.owner(), "attacker was never the owner");
    }
}
