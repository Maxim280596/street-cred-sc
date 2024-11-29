pragma solidity 0.8.27;

import {StreetCred, TokenType} from "./StreetCred.sol";
import {HustleMarket} from "./HustleMarket.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StreetBox is Ownable {
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

    function openBox(uint256 _tokenId) external {
        address user = msg.sender;
        require(streetCred.ownerOf(_tokenId) == user, OnlyNftOwner());
        require(isAvailableToOpen(_tokenId), ActivationNotAllowed());
        require(usdToken.balanceOf(address(this)) >= 1, EmptyBox());

        isActivated[_tokenId] = true;
        uint256 winningsAmount = _calculateWinnings(user, _tokenId);
        usdToken.safeTransfer(user, winningsAmount);

        emit BoxOpened(user, _tokenId, winningsAmount);
    }

    function isAvailableToOpen(uint256 _tokenId) public view returns (bool) {
        return !streetCred.isActive(_tokenId) && !isActivated[_tokenId];
    }

    function calculateMaxPrize(uint256 _tokenId) public view returns (uint256) {
        TokenType tokenType = streetCred.getNftTypeById(_tokenId);
        uint256 nftPrice = hustleMarket.getPrice(tokenType);
        uint256 maxPrize = nftPrice * 3;
        uint256 usdBalance = usdToken.balanceOf(address(this));
        if (usdBalance < maxPrize) {
            return usdBalance;
        }
        return maxPrize * 3;
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
