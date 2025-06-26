const { ethers, deployments } = require('hardhat');
const { expect } = require('chai');

describe('Test upgrade', async function () {
  it('Should be able to deplay', async function () {
    // 部署业务合约
    await deployments.fixture(['deployNftAuction']);
    const nftAuctionProxy = await deployments.get('NftAuctionProxy');
    const nftAuction = await ethers.getContractAt(
      'NftAuction',
      nftAuctionProxy.address
    );
    // 调用createAuction方法创建拍卖
    await nftAuction.createAuction(
      100 * 1000,
      ethers.parseEther('0.01'),
      ethers.ZeroAddress,
      1
    );
    const auction = await nftAuction.auctions(0);
    console.log('创建拍卖成功:', auction);
    // 升级合约
    await deployments.fixture(['upgradeNftAuction']);
    // 读取合约的auction[0]
    const auction2 = await nftAuction.auctions(0);
    console.log('读取auction[0]成功:', auction2);
    expect(auction.auctionId).to.equal(auction2.auctionId);
    const nftAuctionV2 = await ethers.getContractAt(
      'NftAuctionV2',
      nftAuctionProxy.address
    );
    const hello = await nftAuctionV2.testHello();
    console.log('hello:', hello);
  });
});
