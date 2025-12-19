// SPDX-License-Identifier:MIT SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

// import {Test, console} from "forge-std/Test.sol";

// import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
// import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
// import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

// import {RebaseToken} from "../src/RebaseToken.sol";
// import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
// import {Vault} from "../src/Vault.sol";
// import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
// import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
// import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
// import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
// import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
// import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

// contract CrossChainTest is Test {
//     address public joshua = makeAddr("joshua");
//     uint256 sepoliaEthFork;
//     uint256 arbSepoliaFork;
//     uint256 public SEND_VALUE = 1e5;
//     CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

//     RebaseToken arbSepoliaToken;
//     RebaseToken sepoliaEthToken;

//     Vault vault;

//     RebaseTokenPool arbSepoliaPool;
//     RebaseTokenPool sepoliaEthPool;

//     TokenAdminRegistry tokenAdminRegistrySepolia;
//     TokenAdminRegistry tokenAdminRegistryarbSepolia;

//     Register.NetworkDetails sepoliaNetworkDetails;
//     Register.NetworkDetails arbSepoliaNetworkDetails;

//     RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
//     RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia;

//     function setUp() public {
//         address[] memory allowlist = new address[](0);

//         sepoliaEthFork = vm.createSelectFork("sepolia-eth");
//         arbSepoliaFork = vm.createFork("arb-sepolia");

//         ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
//         // we have to make it persistent on both chains
//         vm.makePersistent(address(ccipLocalSimulatorFork));

//         // 2. Deploy and configure on the source chain: Sepolia
//         //sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
//         //(sourceRebaseToken, sourcePool, vault) = sourceDeployer.run(owner);
//         sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
//         vm.startPrank(joshua);
//         sepoliaEthToken = new RebaseToken();
//         console.log("source rebase token address");
//         console.log(address(sepoliaEthToken));
//         console.log("Deploying token pool on Sepolia");
//         sepoliaEthPool = new RebaseTokenPool(
//             IERC20(address(sepoliaEthToken)),
//             allowlist,
//             sepoliaNetworkDetails.rmnProxyAddress,
//             sepoliaNetworkDetails.routerAddress
//         );
//         // deploy the vault
//         vault = new Vault(IRebaseToken(address(sepoliaEthToken)));
//         // add rewards to the vault
//         vm.deal(address(vault), 1e18);
//         // Set pool on the token contract for permissions on Sepolia
//         sepoliaEthToken.grantMintAndBurnRole(address(sepoliaEthPool));
//         sepoliaEthToken.grantMintAndBurnRole(address(vault));
//         // Claim role on Sepolia
//         registryModuleOwnerCustomSepolia =
//             RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress);
//         registryModuleOwnerCustomSepolia.registerAdminViaOwner(address(sepoliaEthToken));
//         // Accept role on Sepolia
//         tokenAdminRegistrySepolia = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress);
//         tokenAdminRegistrySepolia.acceptAdminRole(address(sepoliaEthToken));
//         // Link token to pool in the token admin registry on Sepolia
//         tokenAdminRegistrySepolia.setPool(address(sepoliaEthToken), address(sepoliaEthPool));
//         vm.stopPrank();

//         // deploy and configure on arb-sepolia
//         vm.selectFork(arbSepoliaFork);
//         vm.startPrank(joshua);
//         arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
//         arbSepoliaToken = new RebaseToken();
//         console.log("dest rebase token address");
//         console.log(address(arbSepoliaToken));
//         // Deploy the token pool on Arbitrum
//         console.log("Deploying token pool on Arbitrum");
//         arbSepoliaPool = new RebaseTokenPool(
//             IERC20(address(arbSepoliaToken)),
//             allowlist,
//             arbSepoliaNetworkDetails.rmnProxyAddress,
//             arbSepoliaNetworkDetails.routerAddress
//         );
//         // Set pool on the token contract for permissions on Arbitrum
//         arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
//         // Claim role on Arbitrum
//         registryModuleOwnerCustomarbSepolia =
//             RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress);
//         registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(address(arbSepoliaToken));
//         // Accept role on Arbitrum
//         tokenAdminRegistryarbSepolia = TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress);
//         tokenAdminRegistryarbSepolia.acceptAdminRole(address(arbSepoliaToken));
//         // Link token to pool in the token admin registry on Arbitrum
//         tokenAdminRegistryarbSepolia.setPool(address(arbSepoliaToken), address(arbSepoliaPool));
//         vm.stopPrank();
//     }

//     function configureTokenPool(
//         uint256 fork,
//         TokenPool localPool,
//         TokenPool remotePool,
//         IRebaseToken remoteTokenAddress,
//         Register.NetworkDetails memory remoteNetworkDetails
//     ) public {
//         vm.selectFork(fork);
//         vm.prank(joshua);
//         TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);

//         // We don't need to pass the remoteAddress as an array here because we're only adding one at a time on the latest CCIP contract version

//         // bytes[] memory remotePoolAddresses = new bytes[](1);
//         // remotePoolAddresses[0] = abi.encode(address(remotePool));

//         chainsToAdd[0] = TokenPool.ChainUpdate({
//             remoteChainSelector: remoteNetworkDetails.chainSelector,
//             allowed: true,
//             remotePoolAddress: abi.encode(remotePool), // encode single address
//             remoteTokenAddress: abi.encode(remoteTokenAddress), // encode single address
//             outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
//             inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
//         });
//         TokenPool(localPool).applyChainUpdates(chainsToAdd);
//     }

//     function bridgeTokens(
//         uint256 amountToBridge,
//         uint256 localFork,
//         uint256 remoteFork,
//         Register.NetworkDetails memory localNetworkDetails,
//         Register.NetworkDetails memory remoteNetworkDetails,
//         RebaseToken localToken,
//         RebaseToken remoteToken
//     ) public {
//         vm.selectFork(localFork);
//         vm.startPrank(joshua);
//         Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
//         Client.EVMTokenAmount memory tokenAmount =
//             Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});
//         tokenToSendDetails[0] = tokenAmount;
//         // Approve the router to burn tokens on users behalf
//         IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

//         Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
//             receiver: abi.encode(joshua),
//             data: "",
//             tokenAmounts: tokenToSendDetails,
//             feeToken: localNetworkDetails.linkAddress,
//             extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 900_000}))
//         });
//         vm.stopPrank();

//         ccipLocalSimulatorFork.requestLinkFromFaucet(
//             joshua, IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
//         );
//         vm.startPrank(joshua);
//         IERC20(localNetworkDetails.linkAddress).approve(
//             localNetworkDetails.routerAddress,
//             IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
//         );

//         uint256 localBalanceBefore = localToken.balanceOf(joshua);
//         console.log("Local balance before bridge: %d", localBalanceBefore);

//         IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
//         uint256 localBalanceAfter = IERC20(address(localToken)).balanceOf(joshua);
//         console.log("Local balance after bridge: %d", localBalanceAfter);
//         assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
//         vm.stopPrank();

//         vm.selectFork(remoteFork);
//         // Pretend it takes 15 minutes to bridge the tokens
//         vm.warp(block.timestamp + 900);

//         uint256 remoteBalanceBefore = remoteToken.balanceOf(joshua);
//         console.log("Remote balance before bridge: %d", remoteBalanceBefore);
//         vm.selectFork(localFork);
//         ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

//         console.log("Remote user interest rate: %d", remoteToken.getUserInterestRate(joshua));
//         uint256 remoteBalanceAfter = remoteToken.balanceOf(joshua);
//         console.log("Remote balance after bridge: %d", remoteBalanceAfter);
//         assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
//         // uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(joshua);
//         // assertEq(remoteUserInterestRate, localUserInterestRate);
//     }

//     function testBridgeAllTheTokens() public {
//         configureTokenPool(
//             sepoliaEthFork,
//             sepoliaEthPool,
//             arbSepoliaPool,
//             IRebaseToken(address(arbSepoliaToken)),
//             arbSepoliaNetworkDetails
//         );
//         configureTokenPool(
//             arbSepoliaFork,
//             arbSepoliaPool,
//             sepoliaEthPool,
//             IRebaseToken(address(sepoliaEthToken)),
//             sepoliaNetworkDetails
//         );
//         vm.selectFork(sepoliaEthFork);
//         vm.deal(joshua, SEND_VALUE);
//         vm.prank(joshua);
//         Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
//         // bridge the tokens
//         console.log("Bridging %d tokens", SEND_VALUE);
//         assertEq(sepoliaEthToken.balanceOf(joshua), SEND_VALUE);
//         vm.stopPrank();

//         // bridge ALL TOKENS to the destination chain
//         bridgeTokens(
//             SEND_VALUE,
//             sepoliaEthFork,
//             arbSepoliaFork,
//             sepoliaNetworkDetails,
//             arbSepoliaNetworkDetails,
//             sepoliaEthToken,
//             arbSepoliaToken
//         );
//     }
// }
