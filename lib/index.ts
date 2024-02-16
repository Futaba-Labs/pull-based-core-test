import * as dotenv from 'dotenv';
dotenv.config();

import { BigNumber, ethers } from "ethers";
import FUTABA_ABI from "./constants/futaba.abi.json";
import LZ_ABI from "./constants/layerzero.abi.json";
import { defaultAbiCoder, formatEther, hexZeroPad, parseEther, solidityPack, toUtf8Bytes } from 'ethers/lib/utils';
import fetch from 'node-fetch';

async function main() {
  const rpcMainnet = `https://arbitrum-mainnet.infura.io/v3/${process.env.API_KEY_INFURA}`
  const rpcSepolia = `https://arbitrum-sepolia.infura.io/v3/${process.env.API_KEY_INFURA}`
  const providerMainnet = new ethers.providers.JsonRpcProvider(rpcMainnet);
  const providerSepolia = new ethers.providers.JsonRpcProvider(rpcSepolia);
  const privateKey = process.env.PRIVATE_KEY || "";
  const walletMainnet = new ethers.Wallet(privateKey, providerMainnet);
  const walletSepolia = new ethers.Wallet(privateKey, providerSepolia);

  const coinmarketcapApiKey = process.env.COINMARKETCAP_API_KEY || "";
  const res = await fetch(`https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=ETH`, {
    headers: {
      'X-CMC_PRO_API_KEY': coinmarketcapApiKey
    }

  })
  const data = await res.json()
  const usdPrice = data.data.ETH.quote.USD.price
  console.log(`ETH Price: ${usdPrice} USD\n`)

  // Futaba (Arbitrum Sepolia)
  console.log("Calculating Futaba Fee for batching... (Arbitrum Sepolia -> Ethereum Sepolia)")
  const futabaAddress = "0x00EF9F95500621f08C25587106d4D362b9db9225"
  const futabaLcAddress = "0x997ae35162766C4aF4623EEa4faB6F484bC4593c"
  const futaba = new ethers.Contract(futabaAddress, FUTABA_ABI, walletSepolia);

  const queries =
    [{
      dstChainId: 11155111, to: "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8", height:
        5287151, slot: "0x39b9128158627ade9f9bd452bca008fbb87bcb3df3809faa7220b0a3b11f57cc"
    }]

  const futabaFee = await futaba.estimateFee(futabaLcAddress, queries)
  const futabaFeeWithoutProtocolFee = futabaFee.sub(parseEther("0.001"))
  console.log(`Futaba Fee (without 0.001 ETH protocol fee): ${formatEther(futabaFee)} ETH (${parseFloat(formatEther(futabaFeeWithoutProtocolFee)) * parseFloat(usdPrice)} USD)\n`)

  // TODO Bridge (Arbitrum -> Optimism)
  console.log("Calculating Bridge Fee for batching... (Arbitrum -> Optimism)")
  console.log("Skipped (not implemented)\n")

  // LZ (Arbitrum -> Ethereum)
  console.log("Calculating LZ Fee for batching... (Arbitrum -> Ethereum)")
  const lzAddress = "0x3c2269811836af69497E5F486A85D7316753cf62"
  const messages = []
  for (let i = 0; i < 10; i++) {
    messages.push("Hello, World!")
  }
  console.log(`Messages size: ${messages.length}`)
  const payload = solidityPack(["string[]"], [messages])

  const lz = new ethers.Contract(lzAddress, LZ_ABI, walletMainnet);
  const fees = await lz.estimateFees(
    101,            // the destination LayerZero chainId
    "0x352d8275AAE3e0c2404d9f68f6cEE084B5bEB3DD",     // your contract address that calls Endpoint.send()
    payload,                  // empty payload
    false,                 // _payInZRO
    "0x"                   // default '0x' adapterParams, see: Relayer Adapter Param docs
  )
  console.log(`LZ Fee: ${formatEther(fees.nativeFee)} ETH (${parseFloat(formatEther(fees.nativeFee)) * parseFloat(usdPrice)} USD)\n`)

  const batchSize = 40
  console.log(`Batch Size: ${batchSize}`)
  const batchFee = formatEther(futabaFeeWithoutProtocolFee.add(fees.nativeFee.div(BigNumber.from(batchSize))))
  console.log(`Total Fee: ${batchFee} ETH (${parseFloat(batchFee) * parseFloat(usdPrice)} USD)`)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
