const { deployments, upgrades } = require('hardhat');
const ethers = require('ethers');
const fs = require('fs');
const path = require('path');
const { log } = require('console');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log('部署用户地址:', deployer);
  const NftAuction = await ethers.getContractFactory('NftAuction');
  // 通过代理部署合约
  const nftAuctionProxy = await upgrades.deployProxy(NftAuction, [], {
    initializer: 'initialize',
  });
  await nftAuctionProxy.waitForDeployment();
  const proxyAddress = await nftAuctionProxy.getAddress();
  const implAddress = await upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );
  console.log('代理合约地址:', proxyAddress);
  console.log('实现合约地址:', implAddress);

  const storePath = path.resolve(__dirname, './.cache/proxyNftAuction.json');
  fs.writeFileSync(
    storePath,
    JSON.stringify({
      proxyAddress,
      implAddress,
      abi: NftAuction.interface.format('json'),
    })
  );
  await save('NftAuctionProxy', {
    address: proxyAddress,
    abi: NftAuction.interface.format('json'),
    // args: [],
    // log: true,
  });
  // await deploy('Contract', {
  //   from: deployer,
  //   args: [],
  //   log: true,
  //   waitConfirmations: 1,
  // });
};
module.exports.tags = ['deployNftAuction'];
