// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {StreetCred, TokenType, TokenInfo} from "src/StreetCred.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TestUsdc} from "test/TestUsdc.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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

    /// "ddsdds"
    function setUp() public {
        collection = new StreetCred(owner);
        usdc = new TestUsdc(owner);
        vm.startPrank(owner);
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
        (address testUser1, uint256 user1Pk) = makeAddrAndKey("testUser1");
        (address testUser2, uint256 user2Pk) = makeAddrAndKey("testUser2");

        collection.setHustleMarket(marketplace);
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);

        uint256[] memory marketplaceTokens = collection.userTokensByType(
            marketplace,
            TokenType.RespectSeeker
        );
        uint256 tokenId1 = marketplaceTokens[0];
        uint256 tokenId2 = marketplaceTokens[1];
        console.log("tokenId1", tokenId1);
        console.log("tokenId2", tokenId2);
        string memory codePhrase = "hello";
        bytes32 domainSeparator = collection.domainSeparator();

        _changePrank(marketplace);
        collection.safeTransferFrom(marketplace, testUser1, tokenId1);
        collection.safeTransferFrom(marketplace, testUser2, tokenId2);

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
    }

    function _signMint(
        address _user,
        uint256 _userPk,
        bytes32 _digest
    ) internal returns (bytes memory signature) {
        _changePrank(_user);
        console.log("user", _user);
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

    // function testOwnerMintStreetSoul() public {
    //     assertEq(uint256(1), uint256(1), "ok");
    // }
}
