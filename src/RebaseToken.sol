// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

// Layout of Contract:
// license
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @dev A simple ERC20 token contract named "Rebase Token" with symbol "R
 * @notice This a cross-chain rebase token that incentivizes users to deposit into a vault
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that would be the global interest rate at the time of their deposit
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateTooHigh(uint256 interestRate, uint256 _newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    // interest rate is represented in 1e18 format which means 0.00000000005 is added to the users balance every second
    uint256 private interestRate = 5e10;
    // uint256 private interestRate = (5 * PRECISION_FACTOR) / 1e10; // we do it this way to avoid floating point numbers and to prevent truncation errors 10^-8 = 1/10^8
    mapping(address => uint256) private userInterestRate;
    mapping(address => uint256) private userLastUpdateTimeStamp;

    event InterestRateSet(uint256 _newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    ///////////////////////////////
    // Role functions /////////////
    ///////////////////////////////
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    ///////////////////////////////
    // External Functions /////////
    ///////////////////////////////
    /**
     * @notice Sets the interest rate in the contract
     * @param _newInterestRate The new interest rate to be set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Implementation for setting a new interest rate
        if (_newInterestRate >= interestRate) {
            revert RebaseToken__InterestRateTooHigh(interestRate, _newInterestRate);
        }

        interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Mints the user token when they deposit into the vault
     * @param _to the user to mint the tokens to
     * @param _amount the amount of tokens to mint
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        // Accrued interest basically means interest that has been earned but not yet paid out
        // So when a user mints new tokens, we need to calculate the interest they have accrued so far and mint that interest to them before minting the new tokens they requested
        _mintAccruedInterest(_to);

        // We making sure to set the user's interest rate to the current global interest rate at the time of their minting that's why we have to payout the accrued interest first
        userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the users token when they withdraw from the vault
     * @param _from the user to burn the token from
     * @param _amount the amount of tokens user wants to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient the user to transfer the tokens to
     * @param _amount the amount of tokens to transfer
     * @return bool indicating whether the transfer was successful
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        // if (_amount == type(uint256).max) {
        //     _amount = balanceOf(msg.sender);
        // }
        // let's rephrase it to if amount is greater than sender's balance, transfer the entire balance
        if (_amount > balanceOf(msg.sender)) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            userInterestRate[_recipient] = userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another on behalf of the user
     * @param _sender the user to transfer the tokens from
     * @param _recipient the user to transfer the tokens to
     * @param _amount the amount of tokens to transfer
     * @return bool indicating whether the transfer was successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            userInterestRate[_recipient] = userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice calculates the balance of the user including any interest that has accumulated since their last update
     * (principal balance) * some interest that has accrued
     * @param _user the user to calculate the balance for
     * @return the balance of the user including any interest that has accumulated since their last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principal balance(number of tokens that has been minted to the user)
        // multiply the principal balance by the interest that has accumulated in the time since the balance was last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    ////////////////////////////
    // Internal Functions //////
    ////////////////////////////

    // /**
    //  * @notice Mint the accrued interest to the user since the last time they interacted with the protocol(e.g burn, mint, transfer)
    //  * @params _user The user to mint the accrued interest to
    //  */
    function _mintAccruedInterest(address _user) internal {
        // 1. Find out their current balance of rebase tokens that have been minted to the user
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // 2. Calculate their current balance including any interest => balanceOf
        uint256 currentBalance = balanceOf(_user);
        // 3. calculate the number of tokens that need to be minted to the user => 2 - 1 = 1(if 1 was their initial balance and 2 is their balance with interest)
        uint256 balanaceIncrease = currentBalance - previousPrincipleBalance;
        // 4. set the users lastUpdateTimeStamp
        userLastUpdateTimeStamp[_user] = block.timestamp;
        // 5. call _mint to mint the tokens to the user
        _mint(_user, balanaceIncrease);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumulated since the user's last update
        // this is going to be a linear growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        // (principal amount) + (principal amount * user's interest rate * time elapsed)
        // principal amount(1 + (user's interest rate * time elapsed)) - Both formula's will give the same result but this is standard
        // deposit: 10 tokens
        // interest rate: 0.5 tokens per second
        // time elapsed: 2 seconds
        // 10 + ( 10 * 0.5 * 2 ) = 20 tokens
        uint256 timeElapsed = block.timestamp - userLastUpdateTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + userInterestRate[_user] * timeElapsed;
    }

    ////////////////////////////
    // Getter Functions ////////
    ////////////////////////////

    // Returns the global interest rate of the contract any future depositors or transactions will recieve or update to this interest rate
    function getInterestRate() external view returns (uint256) {
        return interestRate;
    }

    // Returns the interest rate of a specific user
    function getUserInterestRate(address _user) external view returns (uint256) {
        return userInterestRate[_user];
    }

    // Returns the principal balance of the user, This is the number of tokens that have currently be minted by the user without any interest accrued since the last time the user interacted with the protocol
    function getPrincipalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
