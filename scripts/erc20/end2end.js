require("dotenv").config();
const Web3 = require("web3");
const { deployERC20, deployEthManager } = require("./deploy_eth");
const { deployTokenManager, deployHmyManager } = require("./deploy_hmy");
const {sleep, BLOCK_TO_FINALITY, AVG_BLOCK_TIME} = require("../utils");
const {
  mintERC20,
  checkEthBalance,
  tokenDetails,
  approveEthManger,
  lockToken,
  unlockToken,
} = require("./eth");
const {
  checkHmyBalance,
  approveHmyManger,
  approveHmyMangerTokenManager,
  getMappingFor,
  addToken,
  mintToken,
  burnToken,
} = require("./hmy");

const web3 = new Web3(process.env.ETH_NODE_URL);

(async function () {
  const userAddr = process.env.ETH_USER;
  const amount = 100;

  // deploy eth contracts
  let erc20 = await deployERC20("MyERC20 first", "MyERC20-1", 18);
  let ethManager = await deployEthManager(erc20);

  // deploy harmony contracts
  let tokenManagerAddr = await deployTokenManager();
  let hmyManager = await deployHmyManager(tokenManagerAddr);
  await approveHmyMangerTokenManager(tokenManagerAddr, hmyManager);

  // register token mapping in the token manager
  const [name, symbol, decimals] = await tokenDetails(erc20);
  await addToken(hmyManager, erc20, name, symbol, decimals);
  // get the oneTokenAddr from token manager, also available in event
  let hrc20Addr = await getMappingFor(hmyManager, erc20);

  // check eth balance before transfer
  console.log(
    "Eth balance of " +
      userAddr +
      ": " +
      (await checkEthBalance(erc20, userAddr))
  );

  // check hmy recipient balance
  console.log(
    "Hmy balance of " +
      process.env.USER +
      " before eth2hmy: " +
      (await checkHmyBalance(hrc20Addr, process.env.USER))
  );

  // let's mint some tokens for transfer on the eth side
  await mintERC20(erc20, userAddr, amount);
  console.log(
    "Eth balance of " +
      userAddr +
      " after minting: " +
      (await checkEthBalance(erc20, userAddr))
  );

  // user approve eth manager to lock tokens
  await approveEthManger(erc20, ethManager, amount);

  // wait sufficient to confirm the transaction went through
  const lockedEvent = await lockToken(ethManager, process.env.USER, amount);
  
  const expectedBlockNumber = lockedEvent.blockNumber + BLOCK_TO_FINALITY;
  while (true) {
    let blockNumber = await web3.eth.getBlockNumber();
    if (blockNumber <= expectedBlockNumber) {
      console.log(
        `Currently at block ${blockNumber}, waiting for block ${expectedBlockNumber} to be confirmed`
      );
      await sleep(AVG_BLOCK_TIME);
    } else {
      break;
    }
  }

  console.log(
    "Eth balance of " +
      userAddr +
      " after locking: " +
      (await checkEthBalance(erc20, userAddr))
  );

  const recipient = lockedEvent.returnValues.recipient;
  
  await mintToken(hmyManager, hrc20Addr, recipient, amount, lockedEvent.transactionHash);
  console.log(
    "Hmy balance of " +
      recipient +
      " after eth2hmy: " +
      (await checkHmyBalance(hrc20Addr, recipient))
  );

  // check hmy recipient balance
  console.log(
    "Hmy balance of " +
      process.env.USER +
      " before hmy2eth: " +
      (await checkHmyBalance(hrc20Addr, process.env.USER))
  );

  // check eth balance before transfer
  console.log(
    "Eth balance of " +
      userAddr +
      ": " +
      (await checkEthBalance(erc20, userAddr))
  );

  // user approves HmyManager for burning
  await approveHmyManger(hrc20Addr, hmyManager, amount);

  // hmy burn tokens, transaction is confirmed instantaneously, no need to wait
  let txHash = await burnToken(hmyManager, hrc20Addr, userAddr, amount);
  console.log(
    "Hmy balance of " +
      process.env.USER +
      " after burning: " +
      (await checkHmyBalance(hrc20Addr, process.env.USER))
  );

  await unlockToken(ethManager, userAddr, amount, txHash);
  console.log(
    "Eth balance of " +
      userAddr +
      " after unlocking: " +
      (await checkEthBalance(erc20, userAddr))
  );
  process.exit(0);
})();
