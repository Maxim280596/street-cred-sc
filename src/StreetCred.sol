/// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

enum TokenType {
    level1,
    level2,
    level3,
    level4,
    level5,
    level6,
    level7,
    level8,
    level9,
    level10,
    level11,
    level12,
    level13,
    level14,
    level15
}

struct TokenInfo {
    TokenType tokenType;
    address homie1;
    address homie2;
    uint256 timestamp;
    uint256 health;
}

contract StreetCred is Ownable, ERC721 {
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;
    using Strings for uint256;

    uint8 public constant MAX_HEALTH = 4;
    uint8 public constant MAX_OWNER_TOKENS_PER_TYPE = 10;

    bytes32 public constant MINT_TYPEHASH =
        keccak256(
            "MintData(uint256 tokenId1,uint256 tokenId2,string codePhrase,uint256 deadline)"
        );

    /// @notice domain separator for EIP712
    bytes32 public immutable domainSeparator;
    address public hustleMarket;
    string public baseURI;
    uint256 private _nextTokenId;

    mapping(TokenType => uint256) public ownerMintCount;
    mapping(bytes32 => mapping(string => bool)) public usedCodePhrases; // key -> codePhrase -> bool
    mapping(uint256 => TokenInfo) private tokenInfos; // tokenId -> TokenInfo

    mapping(address => mapping(TokenType => EnumerableSet.UintSet))
        private ownedTokens; //address -> (TokenType -> tokenId)
    mapping(bytes32 => EnumerableSet.UintSet) private meets; // address1, address2 -> tokenId

    error InvalidAddress();
    error AlreadyMet();
    error TokenNotExist();
    error SignatureExpired();
    error InvalidOrder();
    error CodePhraseUsed();
    error InvalidSigner(address signer, address owner);
    error Cheat();
    error InsufficientHealth();
    error DifferentTypes();
    error NotStarted();
    error OwnerMaxMintReached();

    event SetHustleMarket(address hustleMarket);
    event SetBaseURI(string baseURI);
    event StreetSoulMinted(
        uint256 tokenID,
        TokenType tokenType,
        address homie1,
        address homie2,
        uint256 tokenId1,
        uint256 tokenId2
    );

    constructor(
        address _owner
    ) ERC721("Street Cred", "STREET") Ownable(_owner) {
        domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("StreetCred")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /// ==================================== External ====================================

    function mintStreetSoul(
        uint256 tokenId1,
        uint256 tokenId2,
        string memory codePhrase, // Should be the same for both signatures
        uint256 deadline, // Should be the same for both signatures
        bytes memory signature1,
        bytes memory signature2
    ) external {
        require(hustleMarket != address(0), NotStarted());
        require(block.timestamp <= deadline, SignatureExpired());
        require(tokenId1 < tokenId2, InvalidOrder());
        address sender = msg.sender;

        bytes32 structHash = keccak256(
            abi.encode(
                MINT_TYPEHASH,
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        address signer1 = digest.recover(signature1);
        address signer2 = digest.recover(signature2);
        bytes32 key = generateKey(tokenId1, tokenId2);

        require(sender == signer1 || sender == signer2, InvalidAddress());
        require(!usedCodePhrases[key][codePhrase], CodePhraseUsed());

        usedCodePhrases[key][codePhrase] = true;

        address owner1 = ownerOf(tokenId1);
        address owner2 = ownerOf(tokenId2);

        require(owner1 == signer1, InvalidSigner(signer1, owner1));
        require(owner2 == signer2, InvalidSigner(signer2, owner2));
        require(signer1 != signer2, Cheat());

        _mintStreetSoul(tokenId1, tokenId2, signer1, signer2, key);
    }

    function ownerMintStreetSoul(TokenType _type) external onlyOwner {
        address hustleMarketCached = hustleMarket;
        require(
            ownerMintCount[_type] < MAX_OWNER_TOKENS_PER_TYPE,
            OwnerMaxMintReached()
        );
        require(hustleMarketCached != address(0), NotStarted());
        uint256 tokenId = ++_nextTokenId;
        tokenInfos[tokenId] = TokenInfo(
            _type,
            address(0),
            address(0),
            block.timestamp,
            MAX_HEALTH
        );
        ownerMintCount[_type]++;
        _safeMint(hustleMarketCached, tokenId);
        emit StreetSoulMinted(tokenId, _type, address(0), address(0), 0, 0);
    }

    function setHustleMarket(address _hustleMarket) external onlyOwner {
        hustleMarket = _hustleMarket;
        emit SetHustleMarket(_hustleMarket);
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
        emit SetBaseURI(_newBaseURI);
    }

    /// ==================================== Public ====================================

    function getTokenInfo(
        uint256 tokenId
    ) external view returns (TokenInfo memory) {
        return tokenInfos[tokenId];
    }

    function vibeCount(bytes32 key) public view returns (uint256) {
        return meets[key].length();
    }

    function balanceOfType(
        address user,
        TokenType _type
    ) public view returns (uint256) {
        return ownedTokens[user][_type].length();
    }

    function getCreatedNft(
        bytes32 key,
        uint256 index
    ) public view returns (uint256) {
        return meets[key].at(index);
    }

    function getNftTypeById(uint256 tokenId) public view returns (TokenType) {
        return tokenInfos[tokenId].tokenType;
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

    function userTokensByType(
        address user,
        TokenType _type
    ) public view returns (uint256[] memory) {
        uint256[] memory tokens = new uint256[](balanceOfType(user, _type));
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i] = tokenOfOwnerTypeAndIndex(user, _type, i);
        }
        return tokens;
    }

    function isActive(uint256 tokenId) public view returns (bool) {
        return tokenInfos[tokenId].health > 0;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), TokenNotExist());
        string memory _tokenBaseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string.concat(
                    _tokenBaseURI,
                    uint256(tokenInfos[tokenId].tokenType).toString(),
                    ".json"
                )
                : "";
    }

    function generateKey(
        uint256 tokenId1,
        uint256 tokenId2
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenId1, tokenId2));
    }

    /// ==================================== Internal ====================================

    function _mintStreetSoul(
        uint256 tokenId1,
        uint256 tokenId2,
        address homie1,
        address homie2,
        bytes32 key
    ) internal {
        uint256 tokenId = ++_nextTokenId;

        require(
            tokenInfos[tokenId1].health > 0 && tokenInfos[tokenId2].health > 0,
            InsufficientHealth()
        );

        TokenType type1 = tokenInfos[tokenId1].tokenType;
        TokenType type2 = tokenInfos[tokenId2].tokenType;
        require(type1 == type2, DifferentTypes());
        require(vibeCount(key) == 0, AlreadyMet());

        meets[key].add(tokenId);
        tokenInfos[tokenId1].health--;
        tokenInfos[tokenId2].health--;

        tokenInfos[tokenId] = TokenInfo(
            type1,
            homie1,
            homie2,
            block.timestamp,
            MAX_HEALTH
        );

        _safeMint(hustleMarket, tokenId);
        emit StreetSoulMinted(
            tokenId,
            type1,
            homie1,
            homie2,
            tokenId1,
            tokenId2
        );
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        TokenType _type = tokenInfos[tokenId].tokenType;
        ownedTokens[from][_type].remove(tokenId);
        ownedTokens[to][_type].add(tokenId);
        return super._update(to, tokenId, auth);
    }
}
