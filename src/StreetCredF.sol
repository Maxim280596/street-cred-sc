pragma solidity 0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

error InvalidAddress();
error AlreadyMeet();
error NotOwner(address user);
error ArraysLengthsNotMatch();
error TokenNotExist();
error InsufficientEth();
error InsufficienUSD();
error InsufficientTokens();
error Incest();

interface IMarket {
    function sell(address to, uint256 tokenId) external;
}

contract StreetCred is ERC721, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for uint256;
    using SafeCast for uint256;
    uint256 private _nextTokenId;

    enum TokenType {
        Solver,
        Gold,
        Platinum
    }

    struct TokenInfo {
        TokenType tokenType;
        address parent1;
        address parent2;
        uint256 timestamp;
        uint256 health;
    }

    string private baseURI;
    mapping(uint256 => TokenInfo) private tokenInfos; // tokenId -> TokenInfo
    mapping(address => mapping(TokenType => EnumerableSet.UintSet))
        private ownedTokens; //address -> (TokenType -> tokenId)
    mapping(bytes32 => EnumerableSet.UintSet) private meets; // address1, address2 -> tokenId

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _owner
    ) ERC721("Street Cred", "STREET") Ownable(_owner) {}

    function generateKey(
        address a1,
        address a2
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a1, a2));
    }

    function balanceOfType(
        address user,
        TokenType _type
    ) public view returns (uint256) {
        return ownedTokens[user][_type].length();
    }

    function meetCount(bytes32 key) public view returns (uint256) {
        return meets[key].length();
    }

    function getMeetNft(
        bytes32 key,
        uint256 index
    ) public view returns (uint256) {
        return meets[key].at(index);
    }

    function maxTokenHealth() public pure returns (uint256) {
        return 4;
    }

    function tokenHealth(uint256 tokenId) public view returns (uint256) {
        return tokenInfos[tokenId].health;
    }

    function getTokenInfo(
        uint256 tokenId
    ) external view returns (TokenInfo memory) {
        return tokenInfos[tokenId];
    }

    function tokenOfOwnerTypeAndIndex(
        address user,
        TokenType _type,
        uint256 index
    ) public view returns (uint256) {
        return ownedTokens[user][_type].at(index);
    }

    function tokenOfOwnerTypeLast(
        address user,
        TokenType _type
    ) public view returns (uint256) {
        return
            ownedTokens[user][_type].at(ownedTokens[user][_type].length() - 1);
    }

    function chance() public view returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 randomHash = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, blockValue))
        );
        return (randomHash % 2 == 1);
    }

    function mint(
        address _to,
        TokenType _type,
        address parent1,
        address parent2
    ) public onlyOwner {
        (address a1, address a2) = parent1 < parent2
            ? (parent1, parent2)
            : (parent2, parent1);
        uint256 tokenId = ++_nextTokenId;

        if (!(parent1 == address(0) && parent2 == address(0))) {
            bytes32 key = generateKey(a1, a2);

            if (meetCount(key) > 0) revert AlreadyMeet();
            if (address(this) == _to || parent1 == parent2)
                revert InvalidAddress();

            if (balanceOfType(parent1, _type) == 0) revert NotOwner(parent1);
            if (balanceOfType(parent2, _type) == 0) revert NotOwner(parent2);

            uint256 tokenId1 = tokenOfOwnerTypeLast(parent1, _type);
            uint256 tokenId2 = tokenOfOwnerTypeLast(parent2, _type);

            if (
                tokenInfos[tokenId1].health <= 0 ||
                tokenInfos[tokenId2].health <= 0
            ) revert InsufficientTokens();

            if (_ownerOf(tokenId1) == tokenInfos[tokenId2].parent1)
                revert Incest();
            if (_ownerOf(tokenId1) == tokenInfos[tokenId2].parent2)
                revert Incest();
            if (_ownerOf(tokenId2) == tokenInfos[tokenId1].parent1)
                revert Incest();
            if (_ownerOf(tokenId2) == tokenInfos[tokenId1].parent2)
                revert Incest();

            if (chance() == true) {
                tokenInfos[tokenId1].health--;
                tokenInfos[tokenId2].health--;
            } else {
                _to = address(0x000000000000000000000000000000000000dEaD);
            }

            meets[key].add(tokenId);
        }

        tokenInfos[tokenId] = TokenInfo(
            _type,
            a1,
            a2,
            block.timestamp,
            maxTokenHealth()
        );
        _safeMint(_to, tokenId);
    }

    function mintBatch(
        address[] calldata _tos,
        TokenType[] calldata _types,
        uint16[] calldata _counts
    ) external onlyOwner {
        if (_tos.length != _types.length || _tos.length != _counts.length)
            revert ArraysLengthsNotMatch();
        for (uint16 i = 0; i < _tos.length; i++) {
            for (uint16 j = 0; j < _counts[i]; j++) {
                mint(_tos[i], _types[i], address(0), address(0));
            }
        }
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenNotExist();

        string memory _tokenBaseURI = _baseURI();
        return
            bytes(_tokenBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        _tokenBaseURI,
                        tokenId.toString(),
                        "/",
                        uint256(tokenInfos[tokenId].tokenType).toString()
                    )
                )
                : "";
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        TokenType _type = tokenInfos[tokenId].tokenType;
        ownedTokens[from][_type].remove(tokenId);
        if (to != address(0)) {
            ownedTokens[to][_type].add(tokenId);
            return super._update(to, tokenId, auth);
        } else {
            delete tokenInfos[tokenId];
            return super._update(to, tokenId, auth);
        }
    }

    receive() external payable {}

    function withdraw(
        address tokenAddress,
        address to,
        uint256 amount
    ) public onlyOwner {
        if (tokenAddress == address(0)) {
            if (address(this).balance < amount) revert InsufficientEth();
            payable(to).transfer(amount);
        } else {
            IERC20 token = IERC20(tokenAddress);
            if (token.balanceOf(address(this)) < amount)
                revert InsufficienUSD();
            token.transfer(to, amount);
        }
    }

    function burn(uint256 tokenId) external {
        _update(address(0), tokenId, msg.sender);
    }

    function burnAndRollback(uint256 tokenId) external {
        if (
            tokenInfos[tokenId].parent1 != address(0) &&
            tokenInfos[tokenId].health > 0
        ) {
            uint256 t1 = tokenOfOwnerTypeLast(
                tokenInfos[tokenId].parent1,
                tokenInfos[tokenId].tokenType
            );
            uint256 t2 = tokenOfOwnerTypeLast(
                tokenInfos[tokenId].parent2,
                tokenInfos[tokenId].tokenType
            );

            tokenInfos[t1].health++;
            tokenInfos[t2].health++;
        }

        _update(address(0), tokenId, msg.sender);
    }
}
