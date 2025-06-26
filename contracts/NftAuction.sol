// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NftAuction is Initializable, UUPSUpgradeable {
    struct Auction {
        // NFT合约地址
        address nftContract;
        // NFT ID
        uint256 tokenId;
        // 卖家
        address seller;
        // 持续时间
        uint256 duration;
        // 起拍价
        uint256 startPrice;
        // 开始时间
        uint256 startTime;
        // 是否结束
        bool ended;
        // 最高出价者
        address highestBidder;
        // 最高价
        uint256 highestBid;
    }
    // 状态
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;
    // 管理员地址
    address public admin;

    function initialize() public initializer {
        admin = msg.sender;
    }

    // 创建拍卖
    function createAuction(
        uint256 _duration,
        uint256 _startPrice,
        address _nftAddress,
        uint256 tokenId
    ) public {
        require(msg.sender == admin, "Only admin can create auction");
        require(_duration >= 10, "Duration must be greater than 10");
        require(_startPrice > 0, "Start price must be greater than 0");

        // 转移NFT到合约
        IERC721(_nftAddress).approve(address(this), tokenId);
        // IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), tokenId);

        auctions[nextAuctionId] = Auction({
            nftContract: _nftAddress,
            tokenId: tokenId,
            seller: msg.sender,
            duration: _duration,
            startPrice: _startPrice,
            ended: false,
            highestBidder: address(0),
            highestBid: 0,
            startTime: block.timestamp
        });
        nextAuctionId++;
    }

    function placeBid(uint256 _auctionId) public payable {
        Auction storage auction = auctions[_auctionId];
        require(
            auctions[_auctionId].ended == false &&
                block.timestamp < (auction.startTime + auction.duration),
            "Auction has ended"
        );
        require(
            msg.value > auction.highestBid && msg.value > auction.startPrice,
            "Bid must be higher than current highest bid"
        );
        // 退回 previously highest bid
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
    }

    // 结束拍卖
    function endAuction(uint256 _auctionId) public {
        Auction storage auction = auctions[_auctionId];
        require(auction.ended == false, "Auction has ended");
        // 转移NFT到最高出价者
        IERC721(auction.nftContract).transferFrom(
            admin,
            auction.highestBidder,
            auction.tokenId
        );
        // 转移剩余的资金到卖家
        payable(address(this)).transfer(address(this).balance);
        auction.ended = true;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        require(msg.sender == admin, "Only admin can upgrade");
    }
}
