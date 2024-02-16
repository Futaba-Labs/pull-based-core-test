import * as dotenv from 'dotenv';
dotenv.config();

import { ethers } from "ethers";
import FUTABA_ABI from "./constants/futaba.abi.json";
import LZ_ABI from "./constants/layerzero.abi.json";
import { defaultAbiCoder, formatEther, hexZeroPad, solidityPack, toUtf8Bytes } from 'ethers/lib/utils';
import fetch from 'node-fetch';

async function main() {
  const rpcMainnet = `https://arbitrum-mainnet.infura.io/v3/${process.env.API_KEY_INFURA}`
  const rpcSepolia = `https://arbitrum-sepolia.infura.io/v3/${process.env.API_KEY_INFURA}`
  const providerMainnet = new ethers.providers.JsonRpcProvider(rpcMainnet);
  const providerSepolia = new ethers.providers.JsonRpcProvider(rpcSepolia);
  const privateKey = process.env.PRIVATE_KEY || "";
  const walletMainnet = new ethers.Wallet(privateKey, providerMainnet);
  const walletSepolia = new ethers.Wallet(privateKey, providerSepolia);

  // Futaba (Arbitrum Sepolia)
  const futabaAddress = "0x00EF9F95500621f08C25587106d4D362b9db9225"
  const futabaLcAddress = "0x997ae35162766C4aF4623EEa4faB6F484bC4593c"
  const futaba = new ethers.Contract(futabaAddress, FUTABA_ABI, walletSepolia);

  const queries =
    [{
      dstChainId: 11155111, to: "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8", height:
        5287151, slot: "0x39b9128158627ade9f9bd452bca008fbb87bcb3df3809faa7220b0a3b11f57cc"
    }]

  const futabaFee = await futaba.estimateFee(futabaLcAddress, queries)
  console.log(`Futaba Fee: ${formatEther(futabaFee)} ETH`)

  // Orbiter
  const api = "https://api.orbiter.finance/sdk/routers/simulation/receiveAmount?line=10/42161-ETH/ETH&value=10000000000000009002"
  const response = await fetch(api)
  const data = await response.json()
  console.log(data)

  // LZ (Arbitrum -> Ethereum)
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
  console.log(`LZ Fee: ${formatEther(fees.nativeFee)} ETH`)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
