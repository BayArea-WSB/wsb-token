// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./libraries/Ownable.sol";
import "./interfaces/IBEP20.sol";


contract AirdropClaim is Ownable {

    uint public claimExpiredAt;
    mapping (address => uint) public claimWhitelist;

    address public airdropTokenAddress;
    
    uint public registeredId = 0;
    event Registered(uint registeredId_, address add_, uint amount_);

    uint public claimId = 0;
    event Claimed(uint claimId_, address add_, uint amount_);
    

    constructor(address airdropToken_) {
        require(airdropToken_ != address(0));
        airdropTokenAddress = airdropToken_;
    }

    receive () external payable {}
    fallback () external payable {}

    function pullFunds(address tokenAddress_) onlyOwner public {
        if (tokenAddress_ == address(0)) {
            msg.sender.transfer(address(this).balance);
        } else {
            IBEP20 token = IBEP20(tokenAddress_);
            token.transfer(msg.sender, token.balanceOf(address(this)));
        }
    }

    function setAirdropTokenAddress(address airdropToken_) onlyOwner public {
        require(airdropToken_ != address(0));
        airdropTokenAddress = airdropToken_;
    }

    function setClaimExpiredAt(uint expireTimestamp_) onlyOwner public {
        require(expireTimestamp_ > block.timestamp, "The expireTimestamp has passed");
        claimExpiredAt = expireTimestamp_;
    }

    function setupWhitelist(address[] calldata candidates_, uint[] calldata values_) onlyOwner public returns (bool){
        require(candidates_.length == values_.length, "Value lengths do not match.");
        require(candidates_.length > 0, "The length is 0");

        for(uint i = 0; i < candidates_.length; i++){
            require(candidates_[i] != address(0));
            claimWhitelist[candidates_[i]] = values_[i];

            emit Registered(registeredId++, candidates_[i], values_[i]);
        }

        return true;
    }

    function claim() public returns (bool) {
        require(block.timestamp <= claimExpiredAt, "Claim was expired.");
        require(airdropTokenAddress != address(0), "The token of airdrop is null");

        uint amount = claimWhitelist[msg.sender];
        require(amount > 0, "You're not in the whitelist or you had claimed out.");

        delete amount;

        emit Claimed(claimId++, msg.sender, amount);

        IBEP20 token = IBEP20(airdropTokenAddress);
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        return true;
    }
}