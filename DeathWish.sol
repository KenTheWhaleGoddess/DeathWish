// SPDX-License-Identifier: GPL-3.0

/// @title Death Wish

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DeathWish is ReentrancyGuard {
    struct Switch {
        uint64 unlock;
        address user;
        address tokenAddress;
        uint8 tokenType; //1 - ERC20 , 2 - ERC721 - 3 - ERC1155
        uint256 tokenId; //for ERC721/ERC1155
        uint256 amount; //for ERC20/ERC1155
    }
    uint256 counter;
    mapping(uint256 => Switch) switches;
    mapping(uint256 => bool) switchClaimed;
    mapping(address => uint256[]) userSwitches;
    mapping(uint256 => address[]) benefactors;
    
    function getCounter() external view returns (uint256) {
        return counter;
    }

    function inspectSwitch(uint256 id) external view returns (uint256, address, address, uint256, uint256, uint256) {
        require(id < counter, "Out of range");
        Switch memory _switch = switches[id];
        return (_switch.unlock, _switch.user, _switch.tokenAddress, _switch.tokenType, _switch.tokenId, _switch.amount);
    }
    function getBenefactors(uint256 id) external view returns (address[] memory) {
        require(id < counter, "Out of range");
        return benefactors[id];
    }

    function getSwitches(address _user) external view returns (uint256[] memory) {
        return userSwitches[_user];
    }

    function createNewERC20Switch(uint64 unlockTimestamp, address tokenAddress, uint256 amount, address[] memory _benefactors) external returns (uint256) {
        require(ERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount, "No allowance set");
        switches[counter] = Switch(
            unlockTimestamp,
            msg.sender,
            tokenAddress,
            1,
            0, //null
            amount
        );
        benefactors[counter] = _benefactors;
        userSwitches[msg.sender].push(counter);
        emit SwitchCreated(counter, switches[counter].tokenType);
        return counter++;
    }

    function createNewERC721Switch(uint64 unlockTimestamp, address tokenAddress, uint256 tokenId, address[] memory _benefactors) external returns (uint256) {
        require(ERC721(tokenAddress).isApprovedForAll(msg.sender, address(this)), "No allowance set");
        switches[counter] = Switch(
            unlockTimestamp,
            msg.sender,
            tokenAddress,
            2,
            tokenId, 
            0 //null
        );
        benefactors[counter] = _benefactors;
        userSwitches[msg.sender].push(counter);
        emit SwitchCreated(counter, switches[counter].tokenType);
        return counter++;
    }

    function createNewERC1155Switch(uint64 unlockTimestamp, address tokenAddress, uint256 tokenId, uint256 amount, address[] memory _benefactors) external returns (uint256) {
        require(ERC1155(tokenAddress).isApprovedForAll(msg.sender, address(this)), "No allowance set");
        switches[counter] = Switch(
            unlockTimestamp,
            msg.sender,
            tokenAddress,
            3,
            tokenId,
            amount
        );
        benefactors[counter] = _benefactors;
        userSwitches[msg.sender].push(counter);
        emit SwitchCreated(counter, switches[counter].tokenType);
        return counter++;
    }
    event SwitchCreated(uint256 id, uint8 switchType);
    event SwitchClaimed(uint256 id, uint8 switchType);
    event UnlockTimeUpdated(uint256 id, uint256 unlock_time);
    event BenefactorsUpdated(uint256 id);
    

    function updateUnlockTime(uint256 id, uint64 newUnlock) external {
        require(id < counter, "out of range");
        Switch storage _switch = switches[id];
        require(_switch.user == msg.sender, "You are not the locker");
        _switch.unlock = newUnlock;
        emit UnlockTimeUpdated(id, newUnlock);
    }
    function updateBenefactors(uint256 id, address[] memory _benefactors) external {
        require(id < counter, "out of range");
        Switch memory _switch = switches[id];
        require(_switch.user == msg.sender, "You are not the locker");
        benefactors[id] = _benefactors;
        emit BenefactorsUpdated(id);
    }

    function claimSwitch(uint256 id) external nonReentrant {
        require(id < counter, "out of range");
        require(!switchClaimed[id], "switch was claimed :(");
        Switch memory _switch = switches[id];
        bool isBenefactor;
        for(uint256 i = 0; i < (benefactors[id].length); i++) {
            if (benefactors[id][i] == msg.sender) {
                require(block.timestamp > (_switch.unlock + (i * 30 days)), "too early");
                isBenefactor = true;
            }
        }
        require(isBenefactor || msg.sender == _switch.user, "sender is not a benefactor or owner");
        if (_switch.tokenType == 1) {
            ERC20(_switch.tokenAddress).transferFrom(_switch.user, msg.sender, _switch.amount);
        } else if (_switch.tokenType == 2) {
            ERC721(_switch.tokenAddress).transferFrom(_switch.user, msg.sender, _switch.tokenId);
        } else if (_switch.tokenType == 3) {
            ERC1155(_switch.tokenAddress).safeTransferFrom(_switch.user, msg.sender, _switch.tokenId, _switch.amount, '');
        } else { revert("FUD"); }
        switchClaimed[id] = true;
        emit SwitchClaimed(id, _switch.tokenType);
    }

}
