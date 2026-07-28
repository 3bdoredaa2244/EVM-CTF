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

contract CairoAuctionTest is Test {
    CairoAuction public auction;
    MockNFT public nft;

    address public seller = makeAddr("seller");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant BIDDING_TIME = 1 days;

    bool startCtf = false; // NOTE: turn this to true when testing

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
        if (!startCtf) return;

        vm.prank(alice);
        auction.bid{value: 1 ether}();
        assertEq(auction.highestBidder(), alice);

        vm.prank(bob);
        auction.bid{value: 2 ether}();
        assertEq(auction.highestBidder(), bob);

        // Write your code here, You can bid up to 5 ETH at most, you need to make sure to win the auction instead of alice

        vm.prank(alice);
        auction.bid{value: 7 ether}();

        vm.warp(block.timestamp + BIDDING_TIME);
        auction.end();

        assertNotEq(
            nft.ownerOf(TOKEN_ID),
            address(alice),
            "alice shouldn't win, attacker should greif her"
        );
    }
}
