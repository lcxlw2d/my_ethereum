const { ethers, upgrades } = require('hardhat');
const path = require('path');
const fs = require('fs');
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { save } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log('部署用户地址', deployer);

  // 读取.cache/proxyNftAuction.json
  const storePath = path.resolve(__dirname, './.cache/proxyNftAuction.json');
  const storeData = fs.readFileSync(storePath, 'utf8');
  const { proxyAddress, implAddress, abi } = JSON.parse(storeData);

  // 升级版的业务合约
  const NftAuctionV2 = await ethers.getContractFactory('NftAuctionV2');

  // 升级代理合约
  const nftAuctionV2 = await upgrades.upgradeProxy(proxyAddress, NftAuctionV2);
  await nftAuctionV2.waitForDeployment();
  const proxyAddressV2 = await nftAuctionV2.getAddress();
  console.log('升级后的代理合约地址:', proxyAddressV2);

  await save('NftAuctionV2', {
    abi: abi,
    address: proxyAddressV2,
  });
};

module.exports.tags = ['upgradeNftAuction'];
