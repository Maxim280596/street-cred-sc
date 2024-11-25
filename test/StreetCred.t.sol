// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {StreetCred, TokenType, TokenInfo} from "src/StreetCred.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StreetCredTest is Test {
    using ECDSA for bytes32;
    StreetCred collection;
    TestUsdc usdc;
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");

    address public marketplace = makeAddr("marketplace");

    /// "testUser1"
    address public testUser1;
    address public testUser2;
    address public testUser3;
    address public testUser4;
    address public testUser5;
    address public testUser6;
    uint256 public user1Pk;
    uint256 public user2Pk;
    uint256 public user3Pk;
    uint256 public user4Pk;
    uint256 public user5Pk;
    uint256 public user6Pk;

    /// "ddsdds"
    function setUp() public {
        collection = new StreetCred(owner);
        usdc = new TestUsdc(owner);
        vm.startPrank(owner);

        (testUser1, user1Pk) = makeAddrAndKey("testUser1");
        (testUser2, user2Pk) = makeAddrAndKey("testUser2");
        (testUser3, user3Pk) = makeAddrAndKey("testUser3");
        (testUser4, user4Pk) = makeAddrAndKey("testUser4");
        (testUser5, user5Pk) = makeAddrAndKey("testUser5");
        (testUser6, user6Pk) = makeAddrAndKey("testUser6");
    }

    function test_SetHustleMarket_Success() public {
        vm.expectEmit(address(collection));
        emit StreetCred.SetHustleMarket(marketplace);
        collection.setHustleMarket(marketplace);
        assertEq(collection.hustleMarket(), marketplace);
    }

    function test_SetHustleMarket_RevertNotOwner() public {
        _changePrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        collection.setHustleMarket(marketplace);
    }

    function test_OwnerMintStreetSoul_Success() public {
        collection.setHustleMarket(marketplace);
        _mintAllOwnerNftsAndAssert(TokenType.RespectSeeker);
        _mintAllOwnerNftsAndAssert(TokenType.StreetHustler);
        _mintAllOwnerNftsAndAssert(TokenType.UrbanLegend);
    }

    function test_OwnerMintStreetSoul_RevertNotOwner() public {
        _changePrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
    }

    function test_OwnerMintStreetSoul_RevertMaxMintReached() public {
        collection.setHustleMarket(marketplace);
        _mintAllOwnerNftsAndAssert(TokenType.RespectSeeker);
        vm.expectRevert(StreetCred.OwnerMaxMintReached.selector);
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
    }

    function test_OwnerMintStreetSoul_RevertNotStarted() public {
        vm.expectRevert(StreetCred.NotStarted.selector);
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
    }

    function test_OwnerMintStreetSoul_TokenInfo() public {
        collection.setHustleMarket(marketplace);
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
        uint256 tokenId = 1;
        TokenInfo memory tokenInfo = collection.getTokenInfo(tokenId);
        TokenType tokenType = collection.getNftTypeById(tokenId);
        uint256 tokenIdFromGetter = collection.tokenOfOwnerTypeAndIndex(
            marketplace,
            TokenType.RespectSeeker,
            0
        );
        uint256 lastTokenIdForType = collection.tokenOfOwnerTypeLast(
            marketplace,
            TokenType.RespectSeeker
        );
        uint256[] memory userTokensByType = collection.userTokensByType(
            marketplace,
            TokenType.RespectSeeker
        );
        bool isActive = collection.isActive(tokenId);

        assertEq(tokenId, lastTokenIdForType);
        assertEq(tokenId, tokenIdFromGetter);
        assertEq(userTokensByType.length, 1);
        assertEq(userTokensByType[0], tokenId);
        assertEq(isActive, true);
        assertEq(uint256(tokenType), uint256(TokenType.RespectSeeker));
        assertEq(
            uint256(tokenInfo.tokenType),
            uint256(TokenType.RespectSeeker)
        );
        assertEq(tokenInfo.homie1, address(0));
        assertEq(tokenInfo.homie2, address(0));
        assertEq(tokenInfo.timestamp, block.timestamp);
        assertEq(tokenInfo.health, collection.MAX_HEALTH());
    }

    function test_SetBaseURI_Success() public {
        string memory baseURI = "https://example.com/";
        vm.expectEmit(address(collection));
        emit StreetCred.SetBaseURI(baseURI);
        collection.setBaseURI(baseURI);
        assertEq(collection.baseURI(), baseURI);
    }

    function test_SetBaseURI_RevertNotOwner() public {
        _changePrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        collection.setBaseURI("https://example.com/");
    }

    function test_mintStreetSoul_Success() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            testUser2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();

        /// sign
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                block.timestamp + 1000
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _changePrank(testUser1);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            block.timestamp + 1000,
            signature1,
            signature2
        );

        assertEq(
            collection.balanceOfType(marketplace, TokenType.RespectSeeker),
            1
        );
        bytes32 key = collection.generateKey(tokenId1, tokenId2);
        uint256 createdNft = collection.getCreatedNft(key, 0);
        assertEq(createdNft, 3);
    }

    function test_mintStreetSoul_RevertNotStarted() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            testUser2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();

        /// sign
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                block.timestamp + 1000
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);
        _changePrank(owner);
        collection.setHustleMarket(address(0));
        vm.expectRevert(StreetCred.NotStarted.selector);

        _changePrank(testUser1);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            block.timestamp + 1000,
            signature1,
            signature2
        );
    }

    function test_mintStreetSoul_RevertSignatureExpired() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            testUser2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();
        uint256 deadline = block.timestamp + 10;

        /// sign
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _skip(100);
        _changePrank(testUser1);
        vm.expectRevert(StreetCred.SignatureExpired.selector);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline,
            signature1,
            signature2
        );
    }

    function test_mintStreetSoul_RevertInvalidOrder() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            testUser2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();
        uint256 deadline = block.timestamp + 10;

        /// sign
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _changePrank(testUser1);
        vm.expectRevert(StreetCred.InvalidOrder.selector);
        collection.mintStreetSoul(
            tokenId2,
            tokenId1,
            codePhrase,
            deadline,
            signature1,
            signature2
        );
    }

    function test_mintStreetSoul_RevertInvalidAddress() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            testUser2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();
        uint256 deadline = block.timestamp + 10;

        /// sign
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _changePrank(testUser1);
        vm.expectRevert(StreetCred.InvalidAddress.selector);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline + 1,
            signature1,
            signature2
        );
    }

    function test_mintStreetSoul_RevertCodePhraseUsed() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            testUser2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();
        uint256 deadline = block.timestamp + 10;

        /// sign
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _changePrank(testUser1);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline,
            signature1,
            signature2
        );

        vm.expectRevert(StreetCred.CodePhraseUsed.selector);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline,
            signature1,
            signature2
        );
    }

    function test_mintStreetSoul_RevertIfCheat() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            testUser1,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();
        uint256 deadline = block.timestamp + 10;

        /// sign
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                tokenId1,
                tokenId2,
                keccak256(bytes(codePhrase)),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);

        _changePrank(testUser1);
        vm.expectRevert(StreetCred.Cheat.selector);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline,
            signature1,
            signature1
        );
    }

    function test_mintStreetSoul_RevertIfNotNftOwner_1() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            user1,
            user2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        uint256 deadline = block.timestamp + 10;

        /// sign
        bytes32 digest = _createDigest(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _changePrank(testUser1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreetCred.InvalidSigner.selector,
                testUser1,
                user1
            )
        );
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline,
            signature1,
            signature2
        );
    }

    function test_mintStreetSoul_RevertIfNotNftOwner_2() public {
        collection.setHustleMarket(marketplace);

        (uint256 tokenId1, uint256 tokenId2) = _mintAndTransferNftsToUser(
            testUser1,
            user2,
            TokenType.RespectSeeker
        );
        string memory codePhrase = "hello";
        uint256 deadline = block.timestamp + 10;

        bytes32 digest = _createDigest(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline
        );
        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _changePrank(testUser1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreetCred.InvalidSigner.selector,
                testUser2,
                user2
            )
        );
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            codePhrase,
            deadline,
            signature1,
            signature2
        );
    }

    function test_mintStreetSoul_RevertIfNotEnoughHealth() public {
        _mintAndTransferNftsToUsers(TokenType.RespectSeeker);

        _meet(
            testUser1,
            testUser2,
            user1Pk,
            user2Pk,
            TokenType.RespectSeeker,
            TokenType.RespectSeeker,
            "hello2",
            false,
            false
        );

        _meet(
            testUser1,
            testUser3,
            user1Pk,
            user3Pk,
            TokenType.RespectSeeker,
            TokenType.RespectSeeker,
            "hello3",
            false,
            false
        );

        _meet(
            testUser1,
            testUser4,
            user1Pk,
            user4Pk,
            TokenType.RespectSeeker,
            TokenType.RespectSeeker,
            "hello4",
            false,
            false
        );

        _meet(
            testUser1,
            testUser5,
            user1Pk,
            user5Pk,
            TokenType.RespectSeeker,
            TokenType.RespectSeeker,
            "hello5",
            false,
            false
        );

        _meet(
            testUser1,
            testUser6,
            user1Pk,
            user6Pk,
            TokenType.RespectSeeker,
            TokenType.RespectSeeker,
            "hello6",
            true,
            false
        );
    }

    function test_mintStreetSoul_RevertIfDifferentTypes() public {
        _mintAndTransferNftsToUsers(TokenType.RespectSeeker);
        _mintAndTransferNftsToUsers(TokenType.StreetHustler);

        _meet(
            testUser1,
            testUser2,
            user1Pk,
            user2Pk,
            TokenType.RespectSeeker,
            TokenType.StreetHustler,
            "hello2",
            false,
            true
        );
    }

    function test_mintStreetSoul_RevertIfAlreadyMeet() public {
        _mintAndTransferNftsToUsers(TokenType.RespectSeeker);

        uint256 tokenId1 = collection.userTokensByType(
            testUser1,
            TokenType.RespectSeeker
        )[0];
        uint256 tokenId2 = collection.userTokensByType(
            testUser2,
            TokenType.RespectSeeker
        )[0];
        bytes32 digest = _createDigest(
            tokenId1,
            tokenId2,
            "hello",
            block.timestamp + 5
        );

        bytes memory signature1 = _signMint(testUser1, user1Pk, digest);
        bytes memory signature2 = _signMint(testUser2, user2Pk, digest);

        _changePrank(testUser1);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            "hello",
            block.timestamp + 5,
            signature1,
            signature2
        );

        bytes32 digest2 = _createDigest(
            tokenId1,
            tokenId2,
            "hello2",
            block.timestamp + 10
        );
        bytes memory signature1_1 = _signMint(testUser1, user1Pk, digest2);
        bytes memory signature2_1 = _signMint(testUser2, user2Pk, digest2);

        _changePrank(testUser1);
        vm.expectRevert(StreetCred.AlreadyMet.selector);
        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            "hello2",
            block.timestamp + 10,
            signature1_1,
            signature2_1
        );
    }

    function test_tokenUri_Success() public {
        _mintAndTransferNftsToUsers(TokenType.RespectSeeker);
        uint256 tokenId = collection.userTokensByType(
            testUser1,
            TokenType.RespectSeeker
        )[0];
        collection.setBaseURI("https://example.com/");
        string memory uri = collection.tokenURI(tokenId);
        assertEq(uri, "https://example.com/0.json");
    }

    function test_tokenUri_RevertTokenNotExist() public {
        vm.expectRevert(StreetCred.TokenNotExist.selector);
        collection.tokenURI(1);
    }

    function test_tokenUri_EmptyString() public {
        _mintAndTransferNftsToUsers(TokenType.RespectSeeker);

        string memory uri = collection.tokenURI(1);
        assertEq(uri, "");
    }

    function _meet(
        address _user1,
        address _user2,
        uint256 _user1Pk,
        uint256 _user2Pk,
        TokenType _tokenType1,
        TokenType _tokenType2,
        string memory _codePhrase,
        bool isCheckHealth,
        bool isCheckTypes
    ) internal {
        uint256 deadline = block.timestamp + 10;

        uint256 tokenId1 = collection.userTokensByType(_user1, _tokenType1)[0];
        uint256 tokenId2 = collection.userTokensByType(_user2, _tokenType2)[0];
        bytes32 digest = _createDigest(
            tokenId1,
            tokenId2,
            _codePhrase,
            deadline
        );
        bytes memory signature1 = _signMint(_user1, _user1Pk, digest);
        bytes memory signature2 = _signMint(_user2, _user2Pk, digest);

        _changePrank(_user1);
        if (isCheckTypes) {
            vm.expectRevert(StreetCred.DifferentTypes.selector);
        }
        if (isCheckHealth) {
            vm.expectRevert(StreetCred.InsufficientHealth.selector);
        }

        collection.mintStreetSoul(
            tokenId1,
            tokenId2,
            _codePhrase,
            deadline,
            signature1,
            signature2
        );
    }

    function _createDigest(
        uint256 _tokenId1,
        uint256 _tokenId2,
        string memory _codePhrase,
        uint256 _deadline
    ) internal view returns (bytes32 digest) {
        bytes32 domainSeparator = collection.domainSeparator();
        bytes32 structHash = keccak256(
            abi.encode(
                collection.MINT_TYPEHASH(),
                _tokenId1,
                _tokenId2,
                keccak256(bytes(_codePhrase)),
                _deadline
            )
        );

        digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
    }

    function _mintAndTransferNftsToUsers(TokenType tokenType) internal {
        collection.setHustleMarket(marketplace);
        address[6] memory users = [
            testUser1,
            testUser2,
            testUser3,
            testUser4,
            testUser5,
            testUser6
        ];
        for (uint i = 0; i < users.length; i++) {
            collection.ownerMintStreetSoul(tokenType);
            uint256[] memory marketplaceTokens = collection.userTokensByType(
                marketplace,
                tokenType
            );
            _changePrank(marketplace);
            collection.safeTransferFrom(
                marketplace,
                users[i],
                marketplaceTokens[0]
            );
            _changePrank(owner);
        }
    }

    function _mintAndTransferNftsToUser(
        address _user1,
        address _user2,
        TokenType _tokenType
    ) internal returns (uint256 tokenId1, uint256 tokenId2) {
        collection.ownerMintStreetSoul(_tokenType);
        collection.ownerMintStreetSoul(_tokenType);

        uint256[] memory marketplaceTokens = collection.userTokensByType(
            marketplace,
            _tokenType
        );
        tokenId1 = marketplaceTokens[0];
        tokenId2 = marketplaceTokens[1];
        _changePrank(marketplace);
        collection.safeTransferFrom(marketplace, _user1, tokenId1);
        collection.safeTransferFrom(marketplace, _user2, tokenId2);
        _changePrank(owner);
    }

    function _signMint(
        address _user,
        uint256 _userPk,
        bytes32 _digest
    ) internal returns (bytes memory signature) {
        _changePrank(_user);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, _digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _mintAllOwnerNftsAndAssert(TokenType tokenType) internal {
        uint8 maxOwnerTokensPerType = collection.MAX_OWNER_TOKENS_PER_TYPE();
        for (uint i = 0; i < maxOwnerTokensPerType; i++) {
            collection.ownerMintStreetSoul(tokenType);
            assertEq(collection.balanceOfType(marketplace, tokenType), i + 1);
        }
    }

    function _changePrank(address user_) internal {
        vm.stopPrank();
        vm.startPrank(user_);
    }

    function _skip(uint256 seconds_) internal {
        skip(seconds_);
        console.log("skipped: ", seconds_);
    }
}

contract TestUsdc is ERC20 {
    constructor(address _owner) ERC20("USDC", "USDC") {
        _mint(_owner, 1000000 * 1e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
