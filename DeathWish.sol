//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
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
    mapping(address => uint256[]) userBenefactor;
    mapping(uint256 => address[]) benefactors;

    uint64 public MAX_TIMESTAMP = 2**64 - 1; //hope this is good enough
    
    function getCounter() external view returns (uint256) {
        return counter;
    }

    function inspectSwitch(uint256 id) external view returns (uint256, address, address, uint256, uint256, uint256) {
        require(id < counter, "Out of range");
        Switch memory _switch = switches[id];
        return (switchClaimableByAt(id, msg.sender), _switch.user, _switch.tokenAddress, _switch.tokenType, _switch.tokenId, _switch.amount);
    }

    function isSwitchClaimed(uint256 id) external view returns (bool) {
        return switchClaimed[id];
    }

    function switchClaimableByAt(uint256 id, address _user) internal view returns (uint64) {
        if (switchClaimed[id]) return MAX_TIMESTAMP;
        Switch memory _switch = switches[id];
        if (_user == _switch.user) return 0;
        for(uint256 i = 0; i < (benefactors[id].length); i++) {
            if (benefactors[id][i] == _user) {
                return (_switch.unlock + uint64((i * 60 days)));
            }
        }
        return MAX_TIMESTAMP;
    }

    function isSwitchClaimableBy(uint256 id, address _user) public view returns (bool) {
        return (block.timestamp > switchClaimableByAt(id, _user));
    }

    function getBenefactorsForSwitch(uint256 id) external view returns (address[] memory) {
        require(id < counter, "Out of range");
        return benefactors[id];
    }

    function getOwnedSwitches(address _user) external view returns (uint256[] memory) {
        return userSwitches[_user];
    }

    function getBenefactorSwitches(address _user) external view returns (uint256[] memory) {
        return userBenefactor[_user];
    }

    function createNewERC20Switch(uint64 unlockTimestamp, address tokenAddress, uint256 amount, address[] memory _benefactors) external returns (uint256) {
        require(IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount, "No allowance set");
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
        for(uint256 i = 0; i < _benefactors.length; i++) {
            userBenefactor[_benefactors[i]].push(counter);
        }
        emit SwitchCreated(counter, switches[counter].tokenType);
        return counter++;
    }

    function createNewERC721Switch(uint64 unlockTimestamp, address tokenAddress, uint256 tokenId, address[] memory _benefactors) external returns (uint256) {
        require(IERC721(tokenAddress).isApprovedForAll(msg.sender, address(this)), "No allowance set");
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
        for(uint256 i = 0; i < _benefactors.length; i++) {
            userBenefactor[_benefactors[i]].push(counter);
        }
        emit SwitchCreated(counter, switches[counter].tokenType);
        return counter++;
    }

    function createNewERC1155Switch(uint64 unlockTimestamp, address tokenAddress, uint256 tokenId, uint256 amount, address[] memory _benefactors) external returns (uint256) {
        require(IERC1155(tokenAddress).isApprovedForAll(msg.sender, address(this)), "No allowance set");
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
        
        for(uint256 i = 0; i < _benefactors.length; i++) {
            userBenefactor[_benefactors[i]].push(counter);
        }
        emit SwitchCreated(counter, switches[counter].tokenType);
        return counter++;
    }

    event SwitchCreated(uint256 id, uint8 switchType);
    event SwitchClaimed(uint256 id, uint8 switchType);
    event UnlockTimeUpdated(uint256 id, uint64 unlock_time);
    event TokenAmountUpdated(uint256 id, uint256 unlock_time);
    event BenefactorsUpdated(uint256 id);
    

    function updateUnlockTime(uint256 id, uint64 newUnlock) external {
        require(id < counter, "out of range");
        Switch storage _switch = switches[id];
        require(_switch.user == msg.sender, "You are not the locker");
        _switch.unlock = newUnlock;
        emit UnlockTimeUpdated(id, newUnlock);
    }

    function updateTokenAmount(uint256 id, uint256 newAmount) external {
        require(id < counter, "out of range");
        Switch storage _switch = switches[id];
        require(_switch.user == msg.sender, "You are not the locker");
        require(_switch.tokenType != 2, "Not valid for ERC721");
        _switch.amount = newAmount;
        emit TokenAmountUpdated(id, newAmount);
    }
    function updateBenefactors(uint256 id, address[] memory _benefactors) external {
        require(id < counter, "out of range");
        Switch memory _switch = switches[id];
        require(_switch.user == msg.sender, "You are not the locker");
        benefactors[id] = _benefactors;
        emit BenefactorsUpdated(id);
    }

    function claimSwitch(uint256 id) external nonReentrant {
        Switch memory _switch = switches[id];
        require(isSwitchClaimableBy(id, msg.sender), "sender is not a benefactor or owner");
        if (_switch.tokenType == 1) {
            IERC20(_switch.tokenAddress).transferFrom(_switch.user, msg.sender, 
            // use min here in case somoene sold some of their token
            min(IERC20(_switch.tokenAddress).balanceOf(_switch.user), _switch.amount));
        } else if (_switch.tokenType == 2) {
            IERC721(_switch.tokenAddress).transferFrom(_switch.user, msg.sender, _switch.tokenId);
        } else if (_switch.tokenType == 3) {
            IERC1155(_switch.tokenAddress).safeTransferFrom(_switch.user, msg.sender, _switch.tokenId, 
            // use min here in case someone sold 1/2 of their 1155
            min(IERC1155(_switch.tokenAddress).balanceOf(_switch.user, _switch.tokenId), _switch.amount), '');
        } else { revert("FUD"); }
        switchClaimed[id] = true;
        emit SwitchClaimed(id, _switch.tokenType);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x > y) {
            return y;
        }
        return x;
    }
}
