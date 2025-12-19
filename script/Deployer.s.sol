// SPDX-License-Identifier:MIT SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {
    RegistryModuleOwnerCustom
} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../src/Vault.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken rebaseToken, RebaseTokenPool tokenPool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        rebaseToken = new RebaseToken();
        tokenPool = new RebaseTokenPool(
            IERC20(address(rebaseToken)), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );
        rebaseToken.grantMintAndBurnRole(address(tokenPool));
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(rebaseToken), address(tokenPool));
        vm.stopBroadcast();
    }
}

contract SetPermissions is Script {
    function grantRole(address rebaseToken, address tokenPool) public {
        vm.startBroadcast();
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(tokenPool));
        vm.stopBroadcast();
    }

    function run(address rebaseToken, address tokenPool) public {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(tokenPool));
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(rebaseToken), address(tokenPool));
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_rebaseToken));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
