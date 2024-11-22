pragma solidity 0.8.27;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {TokenType, TokenInfo, StreetCred} from "./StreetCred.sol";

error ZeroAddress();
error InvalidTokenType();
error InvalidTokenPrice();

struct User {
    address ref;
    uint128 refCount;
    uint256 refEarnings;
    uint256 spentInGame;
    uint256 earnedInGame;
    uint256 connectionTimestamp; /// timestamp when user come
}

contract Marketplace is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    uint32 public constant PRECCISION = 100_000;
    uint32 public constant HOMIE_FEE_PERCENT = 37_500;
    uint32 public constant PROJECT_FEE_PERCENT = 20_000;
    uint32 public constant REF_FEE_PERCENT = 5_000;

    StreetCred public immutable streetCred;
    address public immutable usdToken;

    mapping(TokenType => EnumerableSet.UintSet) internal queues;
    mapping(TokenType => uint256) public tokenPrice;
    mapping(address => User) public users;

    constructor(
        address _initialOwner,
        address _streetCred,
        address _usdToken,
        uint256[] memory _prices
    ) Ownable(_initialOwner) {
        require(_initialOwner != address(0), ZeroAddress());
        require(_streetCred != address(0), ZeroAddress());
        require(_usdToken != address(0), ZeroAddress());
        streetCred = StreetCred(_streetCred);
        usdToken = _usdToken;

        require(
            _prices.length - 1 == uint256(type(TokenType).max), /// double check this line in tests
            InvalidTokenPrice()
        );
        for (uint8 i = 0; i < _prices.length; i++) {
            tokenPrice[TokenType(i)] = _prices[i];
        }
    }

    function sell(uint256 tokenId) internal {
        TokenType tokenType = streetCred.getNftTypeById(tokenId);
        queues[tokenType].add(tokenId);
    }

    function buy(TokenType tokenType, address ref) external {
        require(tokenPrice[tokenType] > 0, InvalidTokenType());
        require(queues[tokenType].length() > 0, "No tokens in queue");
        require(users[ref].connectionTimestamp > 0, "Invalid referrer");
        uint256 price = tokenPrice[tokenType];
        address user = msg.sender;
        address owner = owner();

        _setUpRef(user, ref);

        uint256 tokenId = queues[tokenType].at(0);
        queues[tokenType].remove(tokenId);

        (uint256 homieFee, uint256 projectFee, uint256 refFee) = _calculateFees(
            tokenType
        );
        (address homie1, address homie2) = _getHomies(tokenId);
        users[homie1].earnedInGame += homieFee;
        users[homie2].earnedInGame += homieFee;
        address referrer = users[user].ref;
        users[referrer].refEarnings += refFee;

        users[user].spentInGame += price;

        IERC20(usdToken).safeTransferFrom(user, address(this), price);
        IERC20(usdToken).safeTransfer(owner, projectFee);
        IERC20(usdToken).safeTransfer(homie1, homieFee);
        IERC20(usdToken).safeTransfer(homie2, homieFee);
        IERC20(usdToken).safeTransfer(referrer, refFee);

        streetCred.safeTransferFrom(address(this), user, tokenId);
    }

    function getQueueLength(
        TokenType tokenType
    ) external view returns (uint256) {
        return queues[tokenType].length();
    }

    function getTokenIdInQueueByIndex(
        TokenType tokenType,
        uint256 index
    ) external view returns (uint256) {
        return queues[tokenType].at(index);
    }

    function getPrice(TokenType tokenType) external view returns (uint256) {
        return tokenPrice[tokenType];
    }

    function _setUpRef(address user, address ref) internal {
        User memory userInfo = users[user];
        bool isNew = userInfo.connectionTimestamp == 0;
        if (isNew) {
            if (ref != address(0)) {
                users[user].ref = ref;
            } else {
                users[user].ref = owner();
            }
            users[user].connectionTimestamp = block.timestamp;
        }
    }

    function _getHomies(
        uint256 tokenId
    ) private view returns (address homie1, address homie2) {
        address owner = owner();
        TokenInfo memory tokenInfo = streetCred.getTokenInfo(tokenId);
        homie1 = tokenInfo.homie1 == address(0) ? owner : tokenInfo.homie1;
        homie2 = tokenInfo.homie2 == address(0) ? owner : tokenInfo.homie2;
    }

    function _calculateFees(
        TokenType tokenType
    )
        public
        view
        returns (uint256 homieFee, uint256 projectFee, uint256 refFee)
    {
        uint256 price = tokenPrice[tokenType];
        homieFee = (price * HOMIE_FEE_PERCENT) / PRECCISION;
        projectFee = (price * PROJECT_FEE_PERCENT) / PRECCISION;
        refFee = (price * REF_FEE_PERCENT) / PRECCISION;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public returns (bytes4) {
        if (from == address(streetCred)) {
            sell(tokenId);
            return this.onERC721Received.selector;
        } else {
            revert("Only StreetCred can send tokens");
        }
    }
}
