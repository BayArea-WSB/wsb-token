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

contract FairyTimeLock is Adminable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint public releasedPeriod = 7 days;
    uint public claimableAmountPerFairPerPeriod = 5 * 10**18;

    address public aWSBAddress;
    uint public startTime = 0;
    uint public nextReleasedTime = 0;
    uint public claimedAmount = 0;

    mapping (address => uint) public fairyVault;
    EnumerableSet.AddressSet private _fairyPalace;

    event ComeinFairy(address fairy);
    event ComeoffFairy(address fairy);
    event Released(address fairy, uint amount);
    event CleanFairyPalace(address add_, uint amount);
    event Claimed(address fairy, uint amount);

    constructor(address admin_, address awsb, uint startTime_) Adminable(admin_) {
        aWSBAddress = awsb;
        startTime = startTime_;
        nextReleasedTime = startTime_;
    }
    
    /**
     * @dev fairy can claim token by transfer 
     */
    receive () external payable {
//        if (msg.value > 0) {
//
//            // 0.00300 BNB (msg.value) => 300 aWSB (claimTokenAmount)
//            // token decimal must be 18, which equals BNB
//            uint claimTokenAmount = msg.value * 10**5;
//            claim(claimTokenAmount);
//
//            // send back BNB
//            payable(msg.sender).transfer(msg.value);
//        }
    }

    fallback () external payable {}

    
    function releaseToFairies() public onlyAdmin returns (bool) {
        require(block.timestamp > startTime, "The contract was not enabled");
        uint amountPerFair =
            ((block.timestamp - nextReleasedTime ) / releasedPeriod + 1) * claimableAmountPerFairPerPeriod;
        require((block.timestamp - nextReleasedTime ) >= 0,
                 "FairyTimeLock: It is not the time of next round of airdrop ");
        nextReleasedTime = nextReleasedTime + releasedPeriod;
        uint totalAmount = amountPerFair * _fairyPalace.length();

        IBEP20 aWSB = IBEP20(aWSBAddress);
        require(totalAmount <= aWSB.balanceOf(address(this)), "FairyTimeLock: Not enough balance");
        
        uint length = _fairyPalace.length();
        for(uint i = 0; i < length; i++) {
            address fairyAddr = _fairyPalace.at(i);
            fairyVault[fairyAddr] = amountPerFair;
            emit Released(fairyAddr, amountPerFair);
        }

        return true;

    }


    function claimableAmount() public view returns (uint) {
        IBEP20 aWSB = IBEP20(aWSBAddress);
        return aWSB.balanceOf(address(this)) - claimedAmount;
    }

    function claim() public returns (bool) {
        require(_fairyPalace.contains(msg.sender), "FairyTimeLock: Sorry, you are not in the fairy palace");
        require(aWSBAddress != address(0), "The token of airdrop is null");

        IBEP20 aWSB = IBEP20(aWSBAddress);
        uint amount = fairyVault[msg.sender];
        require(amount > 0, "you had claimed out.");

        require(aWSB.transfer(msg.sender, amount), "Token transfer failed");
        claimedAmount = claimedAmount + amount;
        fairyVault[msg.sender] = 0;

        emit Claimed(msg.sender, amount);
        return true;
    }

    function fairiesComein(address[] calldata fairies_) public onlyAdmin returns (bool) {
        
        for (uint i = 0; i < fairies_.length; i++) {
            require(fairies_[i] != address(0x0), "FairyTimeLock:: Can not add 0x0 fairy");
            _fairyPalace.add(fairies_[i]);
        
            emit ComeinFairy(fairies_[i]);
        }
        
        return true;
    }

    function fairiesComeoff(address[] calldata fairies_) public onlyAdmin returns (bool) {
        for (uint i = 0; i < fairies_.length; i++) {
            require(_fairyPalace.remove(fairies_[i]), "FairyTimeLock:: fairy not exist");
            delete fairyVault[fairies_[i]];
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
        require(index < _fairyPalace.length(), "FairyTimeLock:: index out of bounds");
        return _fairyPalace.at(index);
    }

    function setStartTime(uint startTime_) public onlyAdmin {
        startTime = startTime_;
        nextReleasedTime = startTime_;
    }

    function setTokenAddress(address tokenAddress_) public onlyAdmin {
        aWSBAddress = tokenAddress_;
    }

    function setReleasePeriod(uint releasedPeriod_) public onlyAdmin {
        releasedPeriod = releasedPeriod_;
    }

    function setClaimableAmountPerFairPerPeriod(uint newAmount_) public onlyAdmin {
        claimableAmountPerFairPerPeriod = newAmount_;
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

    /**
     * @dev clean the fairy palace
     */
    function cleanFairPalace() onlyAdmin public returns (bool) {
        uint length = _fairyPalace.length();
        for(uint i = 0; i < length; i++) {
            address key = _fairyPalace.at(0);

            emit CleanFairyPalace(key, fairyVault[key]);

            delete fairyVault[key];
            _fairyPalace.remove(key);
        }

        require(_fairyPalace.length() == 0);
        return true;
    }

}