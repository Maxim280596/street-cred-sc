// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {HustleMarket, UserInfo} from "src/HustleMarket.sol";
import {StreetCred, TokenType, TokenInfo} from "src/StreetCred.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TestUsdc} from "test/TestUsdc.sol";
import {HustleBox} from "src/HustleBox.sol";

contract HustleBoxTest is Test {
    using ECDSA for bytes32;
    HustleMarket market;
    StreetCred collection;
    TestUsdc usdc;
    HustleBox lottery;
    address public owner = makeAddr("owner");
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

    uint256[] prices = [10e6, 50e6, 100e6];

    function setUp() public {
        vm.startPrank(owner);
        collection = new StreetCred(owner);
        usdc = new TestUsdc(address(this));
        market = new HustleMarket(
            owner,
            address(collection),
            address(usdc),
            prices
        );

        collection.setHustleMarket(address(market));
        collection.setBaseURI("https://example.com/");

        lottery = new HustleBox(owner, address(collection), address(market));
        market.setLottery(address(lottery));

        (testUser1, user1Pk) = makeAddrAndKey("testUser1");
        (testUser2, user2Pk) = makeAddrAndKey("testUser2");
        (testUser3, user3Pk) = makeAddrAndKey("testUser3");
        (testUser4, user4Pk) = makeAddrAndKey("testUser4");
        (testUser5, user5Pk) = makeAddrAndKey("testUser5");
        (testUser6, user6Pk) = makeAddrAndKey("testUser6");
    }

    function test_openBox() public {
        address[] memory users = new address[](6);
        users[0] = testUser1;
        users[1] = testUser2;
        users[2] = testUser3;
        users[3] = testUser4;
        users[4] = testUser5;
        users[5] = testUser6;

        _buyAndReplenishLottery(users, TokenType.level1);
        console.log("lottery balance: ", usdc.balanceOf(address(lottery)));
        _skip(1 days);
        assertGt(usdc.balanceOf(address(lottery)), 0);
        _changePrank(testUser1);

        _meet(
            testUser1,
            testUser2,
            user1Pk,
            user2Pk,
            TokenType.level1,
            TokenType.level1,
            "test2"
        );

        _meet(
            testUser1,
            testUser3,
            user1Pk,
            user3Pk,
            TokenType.level1,
            TokenType.level1,
            "test3"
        );

        _meet(
            testUser1,
            testUser4,
            user1Pk,
            user4Pk,
            TokenType.level1,
            TokenType.level1,
            "test4"
        );

        _meet(
            testUser1,
            testUser5,
            user1Pk,
            user5Pk,
            TokenType.level1,
            TokenType.level1,
            "test5"
        );

        uint256 userBalance = usdc.balanceOf(testUser1);
        _changePrank(testUser1);
        collection.setApprovalForAll(address(lottery), true);
        lottery.openBox(1);
        assertGt(usdc.balanceOf(testUser1), userBalance);
        assertEq(collection.ownerOf(1), address(lottery));
        console.log("user1 balance: ", usdc.balanceOf(testUser1) - userBalance);
    }

    function test_openBox_revertIfAlreadyActivated() public {
        address[] memory users = new address[](6);
        users[0] = testUser1;
        users[1] = testUser2;
        users[2] = testUser3;
        users[3] = testUser4;
        users[4] = testUser5;
        users[5] = testUser6;

        _buyAndReplenishLottery(users, TokenType.level1);
        console.log("lottery balance: ", usdc.balanceOf(address(lottery)));
        _skip(20 minutes);
        assertGt(usdc.balanceOf(address(lottery)), 0);
        _changePrank(testUser1);

        _meet(
            testUser1,
            testUser2,
            user1Pk,
            user2Pk,
            TokenType.level1,
            TokenType.level1,
            "test2"
        );

        _meet(
            testUser1,
            testUser3,
            user1Pk,
            user3Pk,
            TokenType.level1,
            TokenType.level1,
            "test3"
        );

        _meet(
            testUser1,
            testUser4,
            user1Pk,
            user4Pk,
            TokenType.level1,
            TokenType.level1,
            "test4"
        );

        _meet(
            testUser1,
            testUser5,
            user1Pk,
            user5Pk,
            TokenType.level1,
            TokenType.level1,
            "test5"
        );

        uint256 userBalance = usdc.balanceOf(testUser1);
        _changePrank(testUser1);
        collection.setApprovalForAll(address(lottery), true);
        lottery.openBox(1);
        assertGt(usdc.balanceOf(testUser1), userBalance);
        assertEq(collection.ownerOf(1), address(lottery));
        console.log("user1 balance: ", usdc.balanceOf(testUser1) - userBalance);

        vm.expectRevert(HustleBox.OnlyNftOwner.selector);
        lottery.openBox(1);
    }

    function test_openBox_revertIfActivationNotAllowed() public {
        address[] memory users = new address[](6);
        users[0] = testUser1;
        users[1] = testUser2;
        users[2] = testUser3;
        users[3] = testUser4;
        users[4] = testUser5;
        users[5] = testUser6;

        _buyAndReplenishLottery(users, TokenType.level1);
        console.log("lottery balance: ", usdc.balanceOf(address(lottery)));
        _skip(20 minutes);
        assertGt(usdc.balanceOf(address(lottery)), 0);
        _changePrank(testUser1);
        vm.expectRevert(HustleBox.ActivationNotAllowed.selector);
        lottery.openBox(1);
    }

    function test_openBox_revertIfEmptyBox() public {
        vm.expectRevert(HustleBox.EmptyBox.selector);
        lottery.openBox(1);
    }

    function test_isAvailableForOpen_success() public {
        _buyNft(testUser1, TokenType.level1);
        assertEq(lottery.isAvailableToOpen(1), false);
    }

    function test_calculateMaxPrize_success() public {
        _buyNft(testUser1, TokenType.level1);
        uint256 maxPrize1 = lottery.calculateMaxPrize(1);
        uint256 lotteryBalance = usdc.balanceOf(address(lottery));
        assertEq(maxPrize1, lotteryBalance);
    }

    function test_calculateMaxPrize2_success() public {
        _buyNft(testUser1, TokenType.level1);
        _changePrank(owner);
        usdc.mint(address(lottery), 1000e6);
        uint256 maxPrize1 = lottery.calculateMaxPrize(1);
        assertEq(maxPrize1, prices[0]);
    }

    function _buyAndReplenishLottery(
        address[] memory users,
        TokenType tokenType
    ) internal {
        for (uint256 i = 0; i < users.length; i++) {
            _buyNft(users[i], tokenType);
        }
    }

    function _buyNft(address user, TokenType tokenType) internal {
        _changePrank(owner);
        collection.ownerMintStreetSoul(tokenType);
        _replenishUsdc(user, prices[uint256(tokenType)]);
        _changePrank(user);
        market.buy(tokenType, address(0));
    }

    function _replenishUsdc(address _user, uint256 _amount) internal {
        _changePrank(owner);
        usdc.mint(_user, _amount);
        _changePrank(_user);
        usdc.approve(address(market), prices[uint256(TokenType.level1)]);
        _changePrank(owner);
    }

    function _changePrank(address user_) internal {
        vm.stopPrank();
        vm.startPrank(user_);
    }

    function _skip(uint256 seconds_) internal {
        skip(seconds_);
        console.log("skipped: ", seconds_);
    }

    function _meet(
        address _user1,
        address _user2,
        uint256 _user1Pk,
        uint256 _user2Pk,
        TokenType _tokenType1,
        TokenType _tokenType2,
        string memory _codePhrase
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

    function _signMint(
        address _user,
        uint256 _userPk,
        bytes32 _digest
    ) internal returns (bytes memory signature) {
        _changePrank(_user);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, _digest);
        signature = abi.encodePacked(r, s, v);
    }
}
