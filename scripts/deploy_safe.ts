import { ethers } from 'hardhat';
import { EthersAdapter, ContractNetworksConfig, SafeFactory, SafeAccountConfig, DEFAULT_SAFE_VERSION } from '@safe-global/protocol-kit';
import { SafeVersion } from '@safe-global/safe-core-sdk-types';
import { randomBytes } from 'crypto';
import dotenv from 'dotenv';
dotenv.config();

async function main() {
    const network = await ethers.provider.getNetwork();
    const accounts = await ethers.getSigners();

    const ethAdapterOwner1 = new EthersAdapter({
        ethers,
        signerOrProvider: accounts[0]
    });
    const owner1Address = await ethAdapterOwner1.getSignerAddress();

    const safeVersion = process.env.SAFE_VERSION || DEFAULT_SAFE_VERSION;
    console.log(`Deploying Safe ${safeVersion} to network: ${network.name} (${network.chainId})`);
    console.log(`Owner 1 address: ${owner1Address}`);

    if (process.env.USE_L1_SAFE_SINGLETON === "true") {
        console.log("Using L1 Safe Singleton");
    } else {
        console.log("Using L2 Safe Singleton");
    }

    let safeFactory;
    if (process.env.USE_SAFE_DEPLOYMENTS === "false") {
        const contractNetworks: ContractNetworksConfig = {
            [network.chainId]: {
                safeSingletonAddress: process.env.USE_L1_SAFE_SINGLETON === "true" ? process.env.SAFE_SINGLETON_ADDRESS || "0x41675C099F32341bf84BFc5382aF534df5C7461a" : process.env.SAFE_L2_SINGLETON_ADDRESS || "0x29fcB43b46531BcA003ddC8FCB67FFE91900C762",
                safeProxyFactoryAddress: process.env.SAFE_PROXY_FACTORY_ADDRESS || "0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67",
                multiSendAddress: process.env.MULTI_SEND_ADDRESS || "0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526",
                multiSendCallOnlyAddress: process.env.MULTI_SEND_CALL_ONLY_ADDRESS || "0x9641d764fc13c8B624c04430C7356C1C7C8102e2",
                fallbackHandlerAddress: process.env.FALLBACK_HANDLER_ADDRESS || "0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99",
                signMessageLibAddress: process.env.SIGN_MESSAGE_LIB_ADDRESS || "0xd53cd0aB83D845Ac265BE939c57F53AD838012c9",
                createCallAddress: process.env.CREATE_CALL_ADDRESS || "0x9b35Af71d77eaf8d7e40252370304687390A1A52",
                simulateTxAccessorAddress: process.env.SIMULATE_TX_ACCESSOR_ADDRESS || "0x3d4BA2E0884aa488718476ca2FB8Efc291A46199"
            }
        };

        safeFactory = await SafeFactory.create({ ethAdapter: ethAdapterOwner1, contractNetworks, safeVersion: safeVersion as SafeVersion, isL1SafeSingleton: Boolean(process.env.USE_L1_SAFE_SINGLETON) });
    } else {
        // Only support networks that are added to https://github.com/safe-global/safe-deployments
        safeFactory = await SafeFactory.create({ ethAdapter: ethAdapterOwner1, safeVersion: safeVersion as SafeVersion, isL1SafeSingleton: Boolean(process.env.USE_L1_SAFE_SINGLETON) });
    }

    const safeAccountConfig: SafeAccountConfig = {
        owners: [
            owner1Address!
        ],
        threshold: 1
    };

    let safeSdkOwner1;
    if (process.env.USE_RANDOM_SALT_NONCE === "false") {
        safeSdkOwner1 = await safeFactory.deploySafe({ safeAccountConfig });
    } else {
        const saltNonce = `0x${randomBytes(32).toString('hex')}`;
        console.log(`Using random saltNonce for Safe deployment: ${saltNonce}`);
        safeSdkOwner1 = await safeFactory.deploySafe({ safeAccountConfig, saltNonce });
    }

    const safeAddress = await safeSdkOwner1.getAddress();
    console.log('Your Safe has been deployed:');
    console.log(`${safeAddress}`);
};

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
