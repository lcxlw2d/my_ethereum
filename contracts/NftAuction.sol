// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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
        // 参与竞价的资产类型， 0x地址表示ETH，其他地址表示ERC20代币
        address tokenAddress;
    }
    // 状态
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;
    // 管理员地址
    address public admin;

    // AggregatorV3Interface internal priceETHFeed;

    mapping(address => AggregatorV3Interface) public priceFeeds;

    function initialize() public initializer {
        admin = msg.sender;
    }

    function setPriceFeed(address tokenAddress, address _priceFeed) public {
        priceFeeds[tokenAddress] = AggregatorV3Interface(_priceFeed);
    }

    function getLatestPrice(address tokenAddress) public view returns (int) {
        AggregatorV3Interface priceFeed = priceFeeds[tokenAddress];
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // emit PriceUpdated(price);
        return price;
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
            startTime: block.timestamp,
            tokenAddress: address(0)
        });
        nextAuctionId++;
    }

    function placeBid(
        uint256 _auctionId,
        uint256 _amount,
        address _tokenAddress
    ) public payable {
        Auction storage auction = auctions[_auctionId];
        require(
            auctions[_auctionId].ended == false &&
                block.timestamp < (auction.startTime + auction.duration),
            "Auction has ended"
        );
        uint256 payValue;
        if (_tokenAddress != address(0)) {
            // 检查是否是ERC20代币
            payValue = _amount * uint(getLatestPrice(_tokenAddress));
        } else {
            // 处理ETH
            _amount = msg.value;
            payValue = _amount * uint(getLatestPrice(address(0)));
        }
        // uint erc20Value = _amount * uint(getLatestPrice(_tokenAddress));
        uint startPriceValue = auction.startPrice *
            uint(getLatestPrice(_tokenAddress));
        uint highestBidValue = auction.highestBid *
            uint(getLatestPrice(_tokenAddress));
        require(
            payValue >= startPriceValue && payValue > highestBidValue,
            "Bid must be higher than current highest bid"
        );
        // 转移ERC20到合约
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        if (auction.highestBidder == address(0)) {
            // 退还ETH
            payable(auction.highestBidder).transfer(auction.highestBid);
        } else {
            // 退还ERC20
            IERC20(auction.highestBidder).transfer(
                auction.highestBidder,
                auction.highestBid
            );
        }
        require(
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transfer failed"
        );
        auction.tokenAddress = _tokenAddress;
        auction.highestBid = _amount;
        auction.highestBidder = msg.sender;
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

    receive() external payable {
        // 接收NFT的支付
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        require(msg.sender == admin, "Only admin can upgrade");
    }
}
