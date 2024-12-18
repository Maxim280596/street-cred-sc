/// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {TokenType, TokenInfo, StreetCred} from "./StreetCred.sol";

struct UserInfo {
    address ref;
    uint128 refCount;
    uint256 refEarnings;
    uint256 spentInGame;
    uint256 earnedInGame;
    uint256 connectionTimestamp; /// timestamp when user come
}

contract HustleMarket is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for ERC20;

    uint32 public constant PRECCISION = 100_000;
    uint32 public constant HOMIE_FEE_PERCENT = 37_500;
    uint32 public constant PROJECT_FEE_PERCENT = 18_000;
    uint32 public constant REF_FEE_PERCENT = 5_000;
    uint32 public constant HUSTLE_BOX_FEE_PERCENT = 2_000;

    StreetCred public immutable streetCred;
    ERC20 public immutable usdToken;
    address public lottery;

    uint256 public totalUsdInGame;
    uint256 public totalUsers;

    mapping(TokenType => EnumerableSet.UintSet) internal queues;
    mapping(TokenType => EnumerableSet.AddressSet) internal usersQueue;
    mapping(TokenType => uint256) private tokenPrice;
    mapping(address => UserInfo) private users;

    error ZeroAddress();
    error InvalidTokenType();
    error InvalidTokenPrice();
    error ForbiddenSender();
    error EmptyQueue();
    error InvalidRef();
    error AlreadyInQueue();
    error AlreadySetted();
    error Cheat();

    event Buy(
        address indexed user,
        TokenType tokenType,
        uint256 tokenId,
        uint256 price,
        address indexed homie1,
        address indexed homie2,
        bool isFromQueue
    );

    event Sell(
        address indexed homie1,
        address indexed homie2,
        TokenType tokenType,
        uint256 tokenId,
        uint256 price
    );

    event AddToUsersQueue(address user, TokenType tokenType);
    event AddNewNftType(TokenType tokenType, uint256 price);
    event LotterySetted(address lottery);
    event RefSetted(address user, address ref);

    constructor(
        address _initialOwner,
        address _streetCred,
        address _usdToken,
        uint256[] memory _prices
    ) Ownable(_initialOwner) {
        require(_streetCred != address(0), ZeroAddress());
        require(_usdToken != address(0), ZeroAddress());
        streetCred = StreetCred(_streetCred);
        usdToken = ERC20(_usdToken);

        for (uint8 i = 0; i < _prices.length; i++) {
            tokenPrice[TokenType(i)] = _prices[i];
            emit AddNewNftType(TokenType(i), _prices[i]);
        }
    }

    function setLottery(address _lottery) external onlyOwner {
        lottery = _lottery;
        emit LotterySetted(_lottery);
    }

    function addNewTokenType(
        TokenType tokenType,
        uint256 price
    ) external onlyOwner {
        require(price > 0, InvalidTokenPrice());
        require(tokenPrice[tokenType] == 0, AlreadySetted());
        tokenPrice[tokenType] = price;
        emit AddNewNftType(tokenType, price);
    }

    function sell(uint256 tokenId) internal {
        TokenType tokenType = streetCred.getNftTypeById(tokenId);
        uint256 price = tokenPrice[tokenType];
        require(price > 0, InvalidTokenType());
        (address homie1, address homie2) = _getHomies(tokenId);
        emit Sell(homie1, homie2, tokenType, tokenId, price);
        if (usersQueue[tokenType].length() > 0) {
            _sellToQueueOfUsers(tokenType, tokenId);
        } else {
            queues[tokenType].add(tokenId);
        }
    }

    function buy(TokenType tokenType, address ref) external {
        _setUpRef(msg.sender, ref);

        if (queues[tokenType].length() > 0) {
            _buyFromQueue(tokenType);
        } else {
            _queueUp(tokenType);
        }
    }

    function _queueUp(TokenType tokenType) internal {
        uint256 price = tokenPrice[tokenType];
        address user = msg.sender;
        require(!usersQueue[tokenType].contains(user), AlreadyInQueue());

        users[user].spentInGame += price;
        totalUsdInGame += price;

        usersQueue[tokenType].add(user);

        usdToken.safeTransferFrom(user, address(this), price);
        emit AddToUsersQueue(user, tokenType);
    }

    function _sellToQueueOfUsers(
        TokenType tokenType,
        uint256 tokenId
    ) internal {
        uint256 price = tokenPrice[tokenType];
        address user = usersQueue[tokenType].at(0);

        usersQueue[tokenType].remove(user);

        (
            uint256 homieFee,
            uint256 projectFee,
            uint256 refFee,
            uint256 lotteryFee
        ) = _calculateFees(tokenType);

        (address homie1, address homie2) = _getHomies(tokenId);

        users[homie1].earnedInGame += homieFee;
        users[homie2].earnedInGame += homieFee;
        address referrer = users[user].ref;
        users[referrer].refEarnings += refFee;

        usdToken.safeTransfer(owner(), projectFee);
        usdToken.safeTransfer(homie1, homieFee);
        usdToken.safeTransfer(homie2, homieFee);
        usdToken.safeTransfer(referrer, refFee);
        usdToken.safeTransfer(lottery, lotteryFee);

        streetCred.safeTransferFrom(address(this), user, tokenId);
        emit Buy(user, tokenType, tokenId, price, homie1, homie2, false);
    }

    function _buyFromQueue(TokenType tokenType) internal {
        uint256 price = tokenPrice[tokenType];
        address user = msg.sender;

        uint256 tokenId = queues[tokenType].at(0);
        queues[tokenType].remove(tokenId);
        {}

        /////   [1,2,3,4,]
        //// remove 0 = [4,2,3]
        /// add 4

        (
            uint256 homieFee,
            uint256 projectFee,
            uint256 refFee,
            uint256 lotteryFee
        ) = _calculateFees(tokenType);

        (address homie1, address homie2) = _getHomies(tokenId);
        users[homie1].earnedInGame += homieFee;
        users[homie2].earnedInGame += homieFee;
        address referrer = users[user].ref;
        users[referrer].refEarnings += refFee;

        users[user].spentInGame += price;
        totalUsdInGame += price;

        usdToken.safeTransferFrom(user, address(this), price);
        usdToken.safeTransfer(owner(), projectFee);
        usdToken.safeTransfer(homie1, homieFee);
        usdToken.safeTransfer(homie2, homieFee);
        usdToken.safeTransfer(referrer, refFee);
        usdToken.safeTransfer(lottery, lotteryFee);

        streetCred.safeTransferFrom(address(this), user, tokenId);
        emit Buy(user, tokenType, tokenId, price, homie1, homie2, true);
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

    function getUserInfo(address user) external view returns (UserInfo memory) {
        return users[user];
    }

    function getUsersQueueLength(
        TokenType tokenType
    ) external view returns (uint256) {
        return usersQueue[tokenType].length();
    }

    function getUserInQueueByIndex(
        TokenType tokenType,
        uint256 index
    ) external view returns (address) {
        return usersQueue[tokenType].at(index);
    }

    function _setUpRef(address user, address ref) internal {
        UserInfo memory userInfo = users[user];
        bool isNew = userInfo.connectionTimestamp == 0;
        address owner = owner();
        if (isNew) {
            require(ref != msg.sender, Cheat());
            if (ref != address(0)) {
                require(users[ref].connectionTimestamp > 0, InvalidRef());
                users[user].ref = ref;
                users[ref].refCount++;
                emit RefSetted(user, ref);
            } else {
                users[user].ref = owner;
                users[owner].refCount++;
                emit RefSetted(user, owner);
            }
            users[user].connectionTimestamp = block.timestamp;
            totalUsers++;
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
        internal
        view
        returns (
            uint256 homieFee,
            uint256 projectFee,
            uint256 refFee,
            uint256 lotteryFee
        )
    {
        uint256 price = tokenPrice[tokenType];
        homieFee = (price * HOMIE_FEE_PERCENT) / PRECCISION;
        projectFee = (price * PROJECT_FEE_PERCENT) / PRECCISION;
        refFee = (price * REF_FEE_PERCENT) / PRECCISION;
        lotteryFee = (price * HUSTLE_BOX_FEE_PERCENT) / PRECCISION;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) public returns (bytes4) {
        if (from == address(0)) {
            sell(tokenId);
            return this.onERC721Received.selector;
        } else {
            revert ForbiddenSender();
        }
    }
}
