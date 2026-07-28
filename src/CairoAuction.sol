// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

/// @title CairoAuction
/// @notice A simple English auction. The prize (trophy) is an NFT escrowed by
///         this contract. Users bid in ETH; when the auction ends the highest
///         bidder receives the trophy and the seller receives the winning bid.
contract CairoAuction {
    // The NFT put up for auction. Fixed at deployment and can never change.
    IERC721 public immutable trophy;
    uint256 public immutable tokenId;

    address public immutable seller; // who receives the winning bid
    uint256 public immutable endTime; // auction closes at this timestamp

    address public highestBidder;
    uint256 public highestBid;
    bool public ended;

    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    constructor(address _trophy, uint256 _tokenId, uint256 _biddingTime) {
        trophy = IERC721(_trophy);
        tokenId = _tokenId;
        seller = msg.sender;
        endTime = block.timestamp + _biddingTime;
    }

    /// @notice Place a bid. Must strictly exceed the current highest bid.
    function bid() external payable {
        require(block.timestamp < endTime, "Auction ended");
        require(msg.value > highestBid, "Bid not high enough");

        // Credit the previous leader so they can withdraw their funds.
        if (highestBidder != address(0)) {
            (bool success, ) = highestBidder.call{value: highestBid}("");
            require(success, "Transaction Failed");
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    /// @notice Settle the auction after it closes: winner gets the NFT, seller
    ///         gets the ETH. If nobody bid, the trophy returns to the seller.
    function end() external {
        require(block.timestamp >= endTime, "Auction not yet ended");
        require(!ended, "Auction already settled");
        ended = true;

        if (highestBidder == address(0)) {
            // No bids: return the trophy to the seller.
            trophy.safeTransferFrom(address(this), seller, tokenId);
            emit AuctionEnded(address(0), 0);
            return;
        }

        // Deliver the trophy to the winner and the proceeds to the seller.
        trophy.safeTransferFrom(address(this), highestBidder, tokenId);
        (bool sent, ) = seller.call{value: highestBid}("");
        require(sent, "Seller payout failed");

        emit AuctionEnded(highestBidder, highestBid);
    }

    /// @notice Accept NFTs sent via safeTransferFrom (the trophy is escrowed here).
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
