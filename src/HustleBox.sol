/// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {StreetCred, TokenType} from "./StreetCred.sol";
import {HustleMarket} from "./HustleMarket.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract HustleBox is Ownable, ERC721Holder {
    using SafeERC20 for ERC20;

    StreetCred public immutable streetCred;
    HustleMarket public immutable hustleMarket;
    ERC20 public immutable usdToken;

    mapping(uint256 => bool) isActivated;

    error ActivationNotAllowed();
    error EmptyBox();
    error OnlyNftOwner();

    event BoxOpened(address user, uint256 tokenId, uint256 winningsAmount);

    constructor(
        address _initialOwner,
        address _stretCred,
        address _hustleMarket
    ) Ownable(_initialOwner) {
        streetCred = StreetCred(_stretCred);
        hustleMarket = HustleMarket(_hustleMarket);
        usdToken = ERC20(HustleMarket(_hustleMarket).usdToken());
    }

    function openBox(uint256 tokenId) external {
        address user = msg.sender;
        require(usdToken.balanceOf(address(this)) >= 1, EmptyBox());
        require(streetCred.ownerOf(tokenId) == user, OnlyNftOwner());
        require(isAvailableToOpen(tokenId), ActivationNotAllowed());

        isActivated[tokenId] = true;
        uint256 winningsAmount = _calculateWinnings(user, tokenId);
        streetCred.safeTransferFrom(user, address(this), tokenId);
        usdToken.safeTransfer(user, winningsAmount);

        emit BoxOpened(user, tokenId, winningsAmount);
    }

    function isAvailableToOpen(uint256 tokenId) public view returns (bool) {
        return !streetCred.isActive(tokenId) && !isActivated[tokenId];
    }

    function calculateMaxPrize(uint256 tokenId) public view returns (uint256) {
        TokenType tokenType = streetCred.getNftTypeById(tokenId);
        uint256 nftPrice = hustleMarket.getPrice(tokenType);
        // uint256 maxPrize = nftPrice;
        uint256 usdBalance = usdToken.balanceOf(address(this));
        if (usdBalance < nftPrice) {
            return usdBalance;
        }
        return nftPrice;
    }

    function _calculateWinnings(
        address _user,
        uint256 _tokenId
    ) internal view returns (uint256 winningsAmount) {
        uint256 maxPrize = calculateMaxPrize(_tokenId);
        winningsAmount = _random(_user, _tokenId) % maxPrize;

        if (winningsAmount == 0) {
            winningsAmount = 1;
        }
    }

    function _random(
        address _user,
        uint256 _tokenId
    ) private view returns (uint) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        address(_user),
                        address(this),
                        usdToken.balanceOf(address(this)),
                        _tokenId,
                        block.number,
                        block.prevrandao,
                        block.timestamp
                    )
                )
            );
    }
}
