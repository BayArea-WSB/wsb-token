// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libraries/Ownable.sol";
import "./interfaces/IBEP20.sol";
import "./libraries/EnumerableSet.sol";


contract AirdropClaim is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    uint public claimExpiredAt;
    mapping (address => uint) public claimWhitelist;
    EnumerableSet.AddressSet private _whitelistKeys;

    address public airdropTokenAddress;
    
    uint public registeredId = 0;
    event Registered(uint registeredId_, address add_, uint amount_);

    uint public claimId = 0;
    event Claimed(uint claimId_, address add_, uint amount_);
    
    event CleanCandidate(address add_, uint amount);

    constructor(address airdropToken_) {
        require(airdropToken_ != address(0));
        airdropTokenAddress = airdropToken_;
    }

    receive () external payable {}
    fallback () external payable {}

    /*
     * @dev Pull out all balance of token or BNB in this contract. When tokenAddress_ is 0x0, will transfer all BNB to the admin owner.
     */
    function pullFunds(address tokenAddress_) onlyOwner public {
        if (tokenAddress_ == address(0)) {
            _msgSender().transfer(address(this).balance);
        } else {
            IBEP20 token = IBEP20(tokenAddress_);
            token.transfer(_msgSender(), token.balanceOf(address(this)));
        }
    }

    function setAirdropTokenAddress(address airdropToken_) onlyOwner public {
        require(airdropToken_ != address(0));
        airdropTokenAddress = airdropToken_;
    }

    function setClaimExpiredAt(uint expireTimestamp_) onlyOwner public {
        claimExpiredAt = expireTimestamp_;
    }

    function setupWhitelist(address[] calldata candidates_, uint[] calldata values_) onlyOwner public returns (bool) {
        require(candidates_.length == values_.length, "Value lengths do not match.");
        require(candidates_.length > 0, "The length is 0");

        for(uint i = 0; i < candidates_.length; i++){
            require(candidates_[i] != address(0));
            claimWhitelist[candidates_[i]] = values_[i];
            _whitelistKeys.add(candidates_[i]);

            emit Registered(registeredId++, candidates_[i], values_[i]);
        }

        return true;
    }

    /**
     * @dev clean the whitelist
     */
    function cleanWhitelist() onlyOwner public returns (bool) {
        require(claimExpiredAt < block.timestamp, "Can not reset before expire time of current round.");
        uint length = _whitelistKeys.length();
        for(uint i = 0; i < length; i++) {
            // modify fix 0 position while iterating all keys 
            address key = _whitelistKeys.at(0);

            emit CleanCandidate(key, claimWhitelist[key]);
            
            delete claimWhitelist[key];
            _whitelistKeys.remove(key);
        }
        require(_whitelistKeys.length() == 0);

        return true;
    }

    function sumClaimableAmount() public view returns (uint s) {
        uint length = _whitelistKeys.length();
        for(uint i = 0; i < length; i++) {
            s += claimWhitelist[_whitelistKeys.at(i)];
        }
    }

    function whitelistLength() public view returns (uint) {
        return _whitelistKeys.length();
    }

    function claim() public returns (bool) {
        require(block.timestamp <= claimExpiredAt, "Claim was expired.");
        require(airdropTokenAddress != address(0), "The token of airdrop is null");

        uint amount = claimWhitelist[msg.sender];
        require(amount > 0, "You're not in the whitelist or you had claimed out.");

        delete claimWhitelist[msg.sender];
        _whitelistKeys.remove(msg.sender);

        emit Claimed(claimId++, msg.sender, amount);

        IBEP20 token = IBEP20(airdropTokenAddress);
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        return true;
    }
}
