// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OfficialTrump is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 public constant TOTAL_SUPPLY = 28600 * 10**18;
    uint256 public constant TRANSACTION_FEE = 5;
    uint256 public constant HOLDER_REWARD_PERCENTAGE = 4;
    uint256 public constant OWNER_FEE_PERCENTAGE = 1;

    address public constant OWNER_ADDRESS = 0x3f9F46a2Aa13341f05F24aAA7602490F64004Bbe;
    mapping(address => bool) private _blacklist;
    bool private _ownershipRenounced = false;
    address[] private _holders;

    event BlacklistUpdated(address indexed user, bool value);
    event OwnershipRenounced();

    constructor() ERC20("OFFICIAL TRUMP", "TRUMP") Ownable(msg.sender) {
        _mint(msg.sender, TOTAL_SUPPLY);
        _holders.push(msg.sender);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(!_blacklist[sender], "Sender is blacklisted");
        require(!_blacklist[recipient], "Recipient is blacklisted");

        uint256 feeAmount = amount.mul(TRANSACTION_FEE).div(100);
        uint256 rewardAmount = feeAmount.mul(HOLDER_REWARD_PERCENTAGE).div(TRANSACTION_FEE);
        uint256 ownerFeeAmount = feeAmount.mul(OWNER_FEE_PERCENTAGE).div(TRANSACTION_FEE);
        uint256 transferAmount = amount.sub(feeAmount);

        super._transfer(sender, recipient, transferAmount);
        super._transfer(sender, OWNER_ADDRESS, ownerFeeAmount);
        distributeRewards(sender, rewardAmount);

        if (balanceOf(recipient) > 0 && !_isHolder(recipient)) {
            _holders.push(recipient);
        }
    }

    function distributeRewards(address sender, uint256 rewardAmount) private {
        uint256 totalSupplyExcludingBlacklisted;
        uint256 holderCount = _holders.length;

        for (uint256 i = 0; i < holderCount; i++) {
            address holder = _holders[i];
            if (!_blacklist[holder]) {
                totalSupplyExcludingBlacklisted = totalSupplyExcludingBlacklisted.add(balanceOf(holder));
            }
        }

        if (totalSupplyExcludingBlacklisted > 0) {
            for (uint256 i = 0; i < holderCount; i++) {
                address holder = _holders[i];
                if (!_blacklist[holder]) {
                    uint256 holderShare = balanceOf(holder).mul(rewardAmount).div(totalSupplyExcludingBlacklisted);
                    super._transfer(sender, holder, holderShare);
                }
            }
        }
    }

    function _isHolder(address account) private view returns (bool) {
        uint256 holderCount = _holders.length;
        for (uint256 i = 0; i < holderCount; i++) {
            if (_holders[i] == account) {
                return true;
            }
        }
        return false;
    }

    function addBlacklist(address user) external onlyOwner {
        require(!_ownershipRenounced, "Ownership renounced");
        _blacklist[user] = true;
        emit BlacklistUpdated(user, true);
    }

    function removeBlacklist(address user) external onlyOwner {
        require(!_ownershipRenounced, "Ownership renounced");
        _blacklist[user] = false;
        emit BlacklistUpdated(user, false);
    }

    function renounceOwnership() public override onlyOwner {
        _ownershipRenounced = true;
        emit OwnershipRenounced();
    }
}
