const { ethers, deployments } = require('hardhat');
const { expect } = require('chai');

describe('Test NFTAuction Should pass', async function () {
  await deployments.fixture(['deployNftAuction']);
  const nftAuctionProxy = await deployments.get('NftAuctionProxy');

  const [signer, buyer] = await ethers.getSigners();

  // 部署ERC721合约
  const TestERC721 = await ethers.getContractFactory('TestERC721');
  const testERC721 = await TestERC721.deploy();
  await testERC721.waitForDeployment();
  const testERC721Address = await testERC721.getAddress();
  console.log(`TestERC721 deployed to: ${testERC721Address}`);

  // mint 10个 NFT
  for (let i = 0; i < 10; i++) {
    await testERC721.mint(signer.address, i + 1);
  }
  const tokenId = 1;
  // 调用createAuction 创建拍卖
  const nftAuction = await ethers.getContractAt(
    'NftAuction',
    nftAuctionProxy.address
  );
  // 给代理合约授权
  await testERC721
    .connect(signer)
    .setApprovalForAll(nftAuctionProxy.address, true);

  await nftAuction.createAuction(
    10,
    ethers.parseEther('0.01'),
    testERC721Address,
    tokenId
  );
  const auction = await nftAuction.auctions(0);

  console.log('创建拍卖成功:', auction);

  // 购买者参与拍卖
  await nftAuction.connect(buyer).placeBid(0, {
    value: ethers.parseEther('0.01'),
  });
  // 等待10秒
  await new Promise((resolve) => setTimeout(resolve, 10000));

  await nftAuction.connect(signer).endAuction(0);

  // 验证结果
  const auctionResult = await nftAuction.auctions(0);
  console.log('拍卖结果:', auctionResult);
  expect(auctionResult.highestBidder).to.equal(buyer.address);
  expect(auctionResult.highestBid).to.equal(ethers.parseEther('0.01'));
  // 验证NFT所有权
  const nftOwner = await testERC721.ownerOf(tokenId);
  console.log('NFT所有权:', nftOwner);
  expect(nftOwner).to.equal(buyer.address);
});
