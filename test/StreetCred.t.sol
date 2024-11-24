// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {StreetCred, TokenType, TokenInfo} from "src/StreetCred.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TestUsdc} from "test/TestUsdc.sol";

contract StreetCredTest is Test {
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
