// SPDX-License-Identifier: GPL-3.0

/// @title Death Wish

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract DeathWish {
    struct Switch {
        uint256 unlock;
        address user;
        address tokenAddress;
        uint256 tokenType; //1 - ERC20 , 2 - ERC721 - 3 - ERC1155
        uint256 tokenId; //for ERC721/ERC1155
        uint256 amount; //for ERC20/ERC1155
    }
    uint256 counter;
    mapping(uint256 => Switch) switches;
    mapping(uint256 => address[]) benefactors;
    
    function createNewERC20Switch(uint256 unlockTimestamp, address tokenAddress, uint256 amount, address[] memory _benefactors) external returns (uint256) {
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
        counter += 1;
        return counter - 1;
    }

    function createNewERC721Switch(uint256 unlockTimestamp, address tokenAddress, uint256 tokenId, address[] memory _benefactors) external returns (uint256) {
        require(ERC721(tokenAddress).isApprovedForAll(msg.sender, address(this)), "No allowance set");
        switches[counter] = Switch(
            unlockTimestamp,
            msg.sender,
            tokenAddress,
            2,
            tokenId, //null
            0
        );
        benefactors[counter] = _benefactors;
        counter += 1;
        return counter - 1;
    }

    function createNewERC1155Switch(uint256 unlockTimestamp, address tokenAddress, uint256 tokenId, uint256 amount, address[] memory _benefactors) external returns (uint256) {
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
        counter += 1;
        return counter - 1;
    }

    function updateUnlockTime(uint256 id, uint256 newUnlock) external {
        require(id < counter, "out of range");
        Switch storage _switch = switches[id];
        require(_switch.user == msg.sender, "You are not the locker");
        _switch.unlock = newUnlock;
    }
    function updateBenefactors(uint256 id, address[] memory _benefactors) external {
        require(id < counter, "out of range");
        Switch memory _switch = switches[id];
        require(_switch.user == msg.sender, "You are not the locker");
        benefactors[id] = _benefactors;
    }

    function claimSwitch(uint256 id) external {
        require(id < counter, "out of range");
        Switch memory _switch = switches[id];
        bool isBenefactor;
        for(uint256 i = 0; i < (benefactors[id].length); i++) {
            if (benefactors[id][i] == msg.sender) {
                require(block.timestamp > (_switch.unlock + (i * 30 days)), "too early");
                isBenefactor = true;
            }
        }
        require(isBenefactor, "sender is not a benefactor");
        if (_switch.tokenType == 1) {
            ERC20(_switch.tokenAddress).transferFrom(_switch.user, msg.sender, _switch.amount);
        } else if (_switch.tokenType == 2) {
            ERC721(_switch.tokenAddress).transferFrom(_switch.user, msg.sender, _switch.tokenId);
        } else if (_switch.tokenType == 3) {
            ERC1155(_switch.tokenAddress).safeTransferFrom(_switch.user, msg.sender, _switch.tokenId, _switch.amount, '');
        } else { revert("FUD"); }
    }

}
