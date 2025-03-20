// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTAuctionHouse is ReentrancyGuard {
    struct Auction {
        address seller;
        address highestBidder;
        uint256 highestBid;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    mapping(address => mapping(uint256 => Auction)) public auctions;
    mapping(address => uint256) public pendingReturns;

    event AuctionCreated(address indexed nft, uint256 indexed tokenId, uint256 endTime);
    event BidPlaced(address indexed nft, uint256 indexed tokenId, address bidder, uint256 amount);
    event AuctionEnded(address indexed nft, uint256 indexed tokenId, address winner, uint256 amount);

    function createAuction(address nft, uint256 tokenId, uint256 duration) external {
        require(duration > 0, "Invalid duration");
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);

        auctions[nft][tokenId] = Auction({
            seller: msg.sender,
            highestBidder: address(0),
            highestBid: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            active: true
        });

        emit AuctionCreated(nft, tokenId, block.timestamp + duration);
    }

    function placeBid(address nft, uint256 tokenId) external payable nonReentrant {
        Auction storage auction = auctions[nft][tokenId];
        require(auction.active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.value > auction.highestBid, "Bid too low");

        if (auction.highestBid > 0) {
            pendingReturns[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(nft, tokenId, msg.sender, msg.value);
    }

    function withdraw() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function endAuction(address nft, uint256 tokenId) external nonReentrant {
        Auction storage auction = auctions[nft][tokenId];
        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction not ended");
        require(msg.sender == auction.seller, "Only seller can end");

        auction.active = false;
        if (auction.highestBidder != address(0)) {
            IERC721(nft).transferFrom(address(this), auction.highestBidder, tokenId);
            payable(auction.seller).transfer(auction.highestBid);
        } else {
            IERC721(nft).transferFrom(address(this), auction.seller, tokenId);
        }

        emit AuctionEnded(nft, tokenId, auction.highestBidder, auction.highestBid);
    }
}
