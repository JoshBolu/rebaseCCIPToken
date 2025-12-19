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
//     address joshua = makeAddr("joshua");
//     uint256 sepoliaEthFork;
//     uint256 arbSepoliaFork;
//     uint256 SEND_VALUE = 1e5;
//     CCIPLocalSimulatorFork ccipLocalSimulatorFork;

//     RebaseToken sepoliaEthToken;
//     RebaseToken arbSepoliaToken;

//     Vault vault;

//     RebaseTokenPool sepoliaEthPool;
//     RebaseTokenPool arbSepoliaPool;

//     Register.NetworkDetails sepoliaNetworkDetails;
//     Register.NetworkDetails arbSepoliaNetworkDetails;

//     function setUp() public {
//         sepoliaEthFork = vm.createSelectFork("sepolia-eth");
//         arbSepoliaFork = vm.createFork("arb-sepolia");

//         ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
//         // we have to make it persistent on both chains
//         vm.makePersistent(address(ccipLocalSimulatorFork));

//         // deploy and configure on sepolia-eth
//         sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
//         vm.startPrank(joshua);
//         sepoliaEthToken = new RebaseToken();
//         vault = new Vault(IRebaseToken(address(sepoliaEthToken)));
//         sepoliaEthPool = new RebaseTokenPool(
//             IERC20(address(sepoliaEthToken)),
//             new address[](0),
//             sepoliaNetworkDetails.rmnProxyAddress,
//             sepoliaNetworkDetails.routerAddress
//         );
//         sepoliaEthToken.grantMintAndBurnRole(address(vault));
//         sepoliaEthToken.grantMintAndBurnRole(address(sepoliaEthPool));
//         RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
//             address(sepoliaEthToken)
//         );
//         TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaEthToken));
//         TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
//             address(sepoliaEthToken), address(sepoliaEthPool)
//         );
//         vm.stopPrank();

//         // deploy and configure on arb-sepolia
//         vm.selectFork(arbSepoliaFork);
//         arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
//         vm.startPrank(joshua);
//         arbSepoliaToken = new RebaseToken();
//         arbSepoliaPool = new RebaseTokenPool(
//             IERC20(address(arbSepoliaToken)),
//             new address[](0),
//             arbSepoliaNetworkDetails.rmnProxyAddress,
//             arbSepoliaNetworkDetails.routerAddress
//         );
//         arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
//         RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
//             address(arbSepoliaToken)
//         );
//         TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
//         TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
//             address(arbSepoliaToken), address(arbSepoliaPool)
//         );
//         vm.stopPrank();
//         configureTokenPool(
//             sepoliaEthFork,
//             address(sepoliaEthPool),
//             arbSepoliaNetworkDetails.chainSelector,
//             address(arbSepoliaPool),
//             address(arbSepoliaToken)
//         );
//         configureTokenPool(
//             arbSepoliaFork,
//             address(arbSepoliaPool),
//             sepoliaNetworkDetails.chainSelector,
//             address(sepoliaEthPool),
//             address(sepoliaEthToken)
//         );
//     }

//     function configureTokenPool(
//         uint256 fork,
//         address localPool,
//         uint64 remoteChainSelector,
//         address remotePool,
//         address remoteTokenAddress
//     ) public {
//         vm.selectFork(fork);
//         vm.prank(joshua);
//         TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
//         chainsToAdd[0] = TokenPool.ChainUpdate({
//             remoteChainSelector: remoteChainSelector,
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
//         Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
//         tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});
//         Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
//             receiver: abi.encode(joshua),
//             data: "",
//             tokenAmounts: tokenAmounts,
//             feeToken: localNetworkDetails.linkAddress,
//             extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 900_000}))
//         });

//         uint256 fee =
//             IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
//         ccipLocalSimulatorFork.requestLinkFromFaucet(joshua, 10 ether);
//         vm.prank(joshua);
//         IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
//         vm.prank(joshua);
//         IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
//         uint256 localBalanceBefore = localToken.balanceOf(joshua);
//         vm.prank(joshua);
//         IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
//         uint256 localBalanceAfter = localToken.balanceOf(joshua);
//         assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
//         uint256 localUserInterestRate = localToken.getUserInterestRate(joshua);

//         vm.selectFork(remoteFork);
//         uint256 remoteBalanceBefore = remoteToken.balanceOf(joshua);
//         ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
//         uint256 remoteBalanceAfter = remoteToken.balanceOf(joshua);
//         assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
//         uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(joshua);
//         assertEq(remoteUserInterestRate, localUserInterestRate);
//     }

//     function testBridgeAllTokens() public {
//         vm.selectFork(sepoliaEthFork);
//         vm.deal(joshua, SEND_VALUE);
//         vm.prank(joshua);
//         Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
//         assertEq(sepoliaEthToken.balanceOf(joshua), SEND_VALUE);
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
