// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // We need to pass the token address tot the constructor
    // create a deposit function that mints tokens to the user equal to the amount of ETH the user deposited
    // create a redeem function that burns tokens from the user and sends the user ETH
    // create way to add rewards to the vault
    error Vault_redeemFailed();

    IRebaseToken public immutable i_rebaseTokenAddress;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseTokenAddress) {
        i_rebaseTokenAddress = _rebaseTokenAddress;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint RebaseToken in return
     *
     */
    function deposit() external payable {
        // We need to use the amounnt of ETH the user has sent to mint tokens to the user
        uint256 interestRate = i_rebaseTokenAddress.getInterestRate();
        i_rebaseTokenAddress.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their RebaseToken for ETH
     * @param _amount the amount of RebaseToken the user wants to redeem
     */
    function redeem(uint256 _amount) external payable {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseTokenAddress.balanceOf(msg.sender);
        }
        // 1. burn the tokens from the user
        i_rebaseTokenAddress.burn(msg.sender, _amount);
        // 2. send the user ETH equal to the amount of tokens burned
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault_redeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    ///////////////////////////
    // getter functions ///////
    ///////////////////////////

    // Get the address of the rebase token
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseTokenAddress);
    }
}
