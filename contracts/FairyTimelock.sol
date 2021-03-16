// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libraries/EnumerableSet.sol";
import "./interfaces/IBEP20.sol";

contract Adminable {
    address public admin;
    address public pendingAdmin;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    
    constructor (address admin_) {
        admin = admin_;
        emit NewAdmin(admin);
    }

    /**
    * @dev Throws if called by any account other than the admin.
    */
    modifier onlyAdmin() {
        require(admin == msg.sender, "Adminable: caller is not the admin");
        _;
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Adminable::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "Adminable::setPendingAdmin: Call must come from Timelock.");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

}

contract FairyTimlock is Adminable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint public constant UNLOCK_PERIOD = 7 days;
    uint public constant UNLOCK_AMOUNT = 50 * 10**18;
    
    address public aWSBAddress;
    uint public startTime = 0;
    uint public claimedAmount = 0;
    uint public maxAmount = 2500 * 10**18;

    EnumerableSet.AddressSet private _fairyPalace;

    event ComeinFairy(address fairy);
    event ComeoffFairy(address fairy);
    event Claimed(address fairy, uint amount);

    constructor(address admin_, address awsb, uint startTime_) Adminable(admin_) {
        aWSBAddress = awsb;
        startTime = startTime_;
    }
    
    /**
     * @dev fairy can claim token by transfer 
     */
    receive () external payable {
        if (msg.value > 0) {

            // 0.00300 BNB (msg.value) => 300 aWSB (claimTokenAmount)
            // token decimal must be 18, which equals BNB
            uint claimTokenAmount = msg.value * 10**5;
            claim(claimTokenAmount);
            
            // send back BNB
            payable(msg.sender).transfer(msg.value);
        }
    }

    fallback () external payable {}

    function releasedVault() public view returns (uint valut) {
        if (block.timestamp < startTime) {
            return 0;
        }

        // calculate the valut
        valut = ((block.timestamp - startTime ) / UNLOCK_PERIOD + 1) * UNLOCK_AMOUNT;
        if (valut > maxAmount) {
            valut = maxAmount;
        }
    }
    
    function claimableAmount() public view returns (uint) {
        return releasedVault() - claimedAmount;
    }

    function claim(uint amount_) public returns (bool) {
        require(_fairyPalace.contains(msg.sender), "FairyTimlock: Sorry, you are not in the fairy palace");

        require(claimableAmount() >= amount_, "FairyTimlock: claim exceed the released amount");

        claimedAmount = claimedAmount + amount_;

        IBEP20 aWSB = IBEP20(aWSBAddress);
        require(aWSB.transfer(msg.sender, amount_), "Token transfer failed");
        
        emit Claimed(msg.sender, amount_);
        return true;
    }

    function fairiesComein(address[] calldata fairies_) public onlyAdmin returns (bool) {
        
        for (uint i = 0; i < fairies_.length; i++) {
            require(fairies_[i] != address(0x0), "FairyTimlock:: Can not add 0x0 fairy");
            _fairyPalace.add(fairies_[i]);
        
            emit ComeinFairy(fairies_[i]);
        }
        
        return true;
    }

    function fairiesComeoff(address[] calldata fairies_) public onlyAdmin returns (bool) {
        for (uint i = 0; i < fairies_.length; i++) {
            require(_fairyPalace.remove(fairies_[i]), "FairyTimlock:: fairy not exist");
        
            emit ComeoffFairy(fairies_[i]);
        }
        
        return true;
    }

    function containsFairy(address fairy_) public view returns (bool) {
        return _fairyPalace.contains(fairy_);
    }

    function fairiesCount() public view returns (uint) {
        return _fairyPalace.length();
    }

    function fairyAtIndex(uint index) public view returns (address) {
        require(index < _fairyPalace.length(), "FairyTimelock:: index out of bounds");
        return _fairyPalace.at(index);
    }

    function setStartTime(uint startTime_) public onlyAdmin {
        startTime = startTime_;
    }

    function setMaxAmount(uint maxAmount_) public onlyAdmin {
        maxAmount = maxAmount_;
    }
    
    function setTokenAddress(address tokenAddress_) public onlyAdmin {
        aWSBAddress = tokenAddress_;
    }

    /*
     * @dev Pull out all balance of token or BNB in this contract. When tokenAddress_ is 0x0, will transfer all BNB to the admin owner.
     */
    function pullFunds(address tokenAddress_) onlyAdmin public {
        if (tokenAddress_ == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            IBEP20 token = IBEP20(tokenAddress_);
            token.transfer(msg.sender, token.balanceOf(address(this)));
        }
    }
}