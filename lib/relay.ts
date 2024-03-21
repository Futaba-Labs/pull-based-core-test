import * as dotenv from 'dotenv';
dotenv.config();

import { ethers, TypedDataField } from "ethers";
import FUTABA_ABI from "./constants/futaba.abi.json";
import LZ_ABI from "./constants/layerzero.abi.json";
import { BytesLike, defaultAbiCoder, formatEther, hexZeroPad, parseEther, solidityPack, toUtf8Bytes } from 'ethers/lib/utils';
import fetch from 'node-fetch';
import { parse } from "ts-command-line-args";
import { AxelarQueryAPI, CHAINS, Environment, GasToken } from '@axelar-network/axelarjs-sdk';
import { AllowanceProvider, AllowanceTransfer, PERMIT2_ADDRESS, PermitSingle } from '@uniswap/permit2-sdk'
import {
  GelatoRelay,
  CallWithSyncFeeERC2771Request,
} from "@gelatonetwork/relay-sdk";
import RECEIVER_ABI from "./constants/receiver.abi.json"


const AAVE_V3_RECEIVER = "0x8dF70EF054fE8d5AFA35B34fEE02d5Aec5720c31";
const ATOKEN = "0x4086fabeE92a080002eeBA1220B9025a27a40A49";
const USDC = "0x52D800ca262522580CeBAD275395ca6e7598C014";
const NATIVE_TOKEN = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const CHAIN_ID = 80001;
const ERC20_ABI = ["function balanceOf(address) view returns (uint256)", "function approve(address, uint256) returns (bool)"];

async function main() {
  const apiKey = process.env.API_KEY_INFURA;
  const mumbaiProvider = new ethers.providers.JsonRpcProvider(`https://polygon-mumbai.infura.io/v3/${apiKey}`);
  const allowanceProvider = new AllowanceProvider(mumbaiProvider, PERMIT2_ADDRESS)
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, mumbaiProvider);
  const signer = mumbaiProvider.getSigner();
  const { nonce } = await allowanceProvider.getAllowanceData(ATOKEN, wallet.address, AAVE_V3_RECEIVER);

  const erc20 = new ethers.Contract(ATOKEN, ERC20_ABI, wallet);
  const permitAmount = await erc20.balanceOf(wallet.address);
  console.log("Permit amount: ", permitAmount);

  const permitSingle: PermitSingle = {
    details: {
      token: ATOKEN,
      amount: permitAmount,
      // You may set your own deadline - we use 30 days.
      expiration: toDeadline(/* 30 days= */ 1000 * 60 * 60 * 24 * 30),
      nonce,
    },
    spender: AAVE_V3_RECEIVER,
    // You may set your own deadline - we use 30 minutes.
    sigDeadline: toDeadline(/* 30 minutes= */ 1000 * 60 * 60 * 30),
  }

  console.log("Permit single: ", permitSingle);

  const { domain, types, values } = AllowanceTransfer.getPermitData(permitSingle, PERMIT2_ADDRESS, CHAIN_ID)

  // We use an ethers signer to sign this data:
  const signature = await wallet._signTypedData(domain, types, values)

  const contract = new ethers.Contract(
    AAVE_V3_RECEIVER,
    RECEIVER_ABI,
    wallet
  )
  // let tx;
  // try {
  //   // tx = await erc20.approve(PERMIT2_ADDRESS, ethers.constants.MaxUint256);
  //   // await tx.wait();
  //   tx = await contract.withdrawWithPermit(USDC, permitAmount, permitSingle, signature, { gasLimit: 1000000 });
  //   await tx.wait();
  //   console.log("Withdrawal transaction hash: ", tx.hash);
  // } catch (error) {
  //   console.log("Error withdrawing: ", error);
  // }


  const relay = new GelatoRelay();

  const aaveV3Receiver = new ethers.utils.Interface(RECEIVER_ABI)

  // const withdrawWithRelay = aaveV3Receiver.encodeFunctionData("withdrawWithRelay", [
  //   USDC,
  //   permitAmount,
  //   permitSingle,
  //   signature,
  // ]);

  const { data } = await contract.populateTransaction.withdrawWithRelay(
    USDC,
    permitAmount,
    permitSingle,
    signature
  );

  if (!data) {
    throw new Error("Data is null");
  }

  const request: CallWithSyncFeeERC2771Request = {
    chainId: BigInt(CHAIN_ID),
    target: AAVE_V3_RECEIVER,
    data: data,
    user: wallet.address,
    isRelayContext: true,
    feeToken: NATIVE_TOKEN
  };

  // const { struct, typedData } = await relay.getDataToSignERC2771(
  //   request,
  //   ERC2771Type.ConcurrentCallWithSyncFee
  // );

  // // eslint-disable-next-line
  // const { EIP712Domain: _, ...relayTypes } = typedData.types as Record<
  //   string,
  //   Array<TypedDataField>
  // >;

  // const relaySig = await wallet._signTypedData(
  //   typedData.domain,
  //   relayTypes,
  //   typedData.message
  // );

  // const { taskId } = await relay.callWithSyncFeeERC2771WithSignature(
  //   struct,
  //   { feeToken: NATIVE_TOKEN, isRelayContext: true },
  //   relaySig,
  //   { retries: 0 }
  // );

  const response = await relay.callWithSyncFeeERC2771(request, wallet);
  console.log("https://api.gelato.digital/tasks/status/" + response.taskId);
}

function toDeadline(expiration: number): number {
  return Math.floor((Date.now() + expiration) / 1000)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
