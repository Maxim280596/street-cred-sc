// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {HustleMarket, UserInfo} from "src/HustleMarket.sol";
import {StreetCred, TokenType, TokenInfo} from "src/StreetCred.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StreetCredTest is Test {
    using ECDSA for bytes32;
    HustleMarket market;
    StreetCred collection;
    TestUsdc usdc;
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

        (testUser1, user1Pk) = makeAddrAndKey("testUser1");
        (testUser2, user2Pk) = makeAddrAndKey("testUser2");
        (testUser3, user3Pk) = makeAddrAndKey("testUser3");
        (testUser4, user4Pk) = makeAddrAndKey("testUser4");
        (testUser5, user5Pk) = makeAddrAndKey("testUser5");
        (testUser6, user6Pk) = makeAddrAndKey("testUser6");
    }

    function test_deploy_success() public view {
        assertEq(address(market.owner()), owner);
        assertEq(address(market.streetCred()), address(collection));
        assertEq(address(market.usdToken()), address(usdc));

        uint256 level1Price = market.getPrice(TokenType.RespectSeeker);
        uint256 level2Price = market.getPrice(TokenType.StreetHustler);
        uint256 level3Price = market.getPrice(TokenType.UrbanLegend);

        assertEq(level1Price, prices[0]);
        assertEq(level2Price, prices[1]);
        assertEq(level3Price, prices[2]);
    }

    function test_deploy_revertIfStreetCredIncorrect() public {
        vm.expectRevert(HustleMarket.ZeroAddress.selector);
        new HustleMarket(owner, address(0), address(usdc), prices);
    }

    function test_deploy_revertIfUsdTokenIncorrect() public {
        vm.expectRevert(HustleMarket.ZeroAddress.selector);
        new HustleMarket(owner, address(collection), address(0), prices);
    }

    function test_deploy_revertIfPricesIncorrect() public {
        uint256[] memory incorrectPrices = new uint256[](2);
        incorrectPrices[0] = 10e6;
        incorrectPrices[1] = 50e6;
        vm.expectRevert(HustleMarket.InvalidTokenPrice.selector);
        new HustleMarket(
            owner,
            address(collection),
            address(usdc),
            incorrectPrices
        );
    }

    function test_sell_owner_success() public {
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
        uint256[] memory tokenIds = collection.userTokensByType(
            address(market),
            TokenType.RespectSeeker
        );
        assertEq(tokenIds.length, 1);
        assertEq(market.getQueueLength(TokenType.RespectSeeker), 1);
    }

    function test_buy_ownerNFT_success() public {
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);

        uint256 ownerBalanceBefore = usdc.balanceOf(owner);

        _replenishUsdc(testUser1, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser1);
        market.buy(TokenType.RespectSeeker, address(0));

        uint256 ownerBalanceAfter = usdc.balanceOf(owner);

        assertEq(
            ownerBalanceAfter,
            ownerBalanceBefore + prices[uint256(TokenType.RespectSeeker)]
        );
    }

    function test_buy_RevertIfNoTokensInQueue() public {
        _changePrank(testUser1);
        vm.expectRevert(HustleMarket.EmptyQueue.selector);
        market.buy(TokenType.RespectSeeker, address(0));
    }

    function test_buy_createdNftByUsers() public {
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);

        _replenishUsdc(testUser1, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser1);
        market.buy(TokenType.RespectSeeker, address(0));

        _replenishUsdc(testUser2, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser2);
        market.buy(TokenType.RespectSeeker, address(0));
        _meet(
            testUser1,
            testUser2,
            user1Pk,
            user2Pk,
            TokenType.RespectSeeker,
            TokenType.RespectSeeker,
            "test"
        );
        assertEq(market.getQueueLength(TokenType.RespectSeeker), 1);

        uint256 tokenId = market.getTokenIdInQueueByIndex(
            TokenType.RespectSeeker,
            0
        );

        (address homie1, address homie2) = _getHomies(tokenId);
        assertEq(homie1, testUser1);
        assertEq(homie2, testUser2);

        uint256 homie1BalanceBefore = usdc.balanceOf(homie1);
        uint256 homie2BalanceBefore = usdc.balanceOf(homie2);
        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        _replenishUsdc(testUser3, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser3);
        market.buy(TokenType.RespectSeeker, testUser1);

        uint256 homie1BalanceAfter = usdc.balanceOf(homie1);
        uint256 homie2BalanceAfter = usdc.balanceOf(homie2);
        uint256 ownerBalanceAfter = usdc.balanceOf(owner);

        (uint256 homieFee, uint256 projectFee, uint256 refFee) = _calculateFees(
            TokenType.RespectSeeker
        );

        _checkHealth(testUser1, TokenType.RespectSeeker, 3);
        _checkHealth(testUser2, TokenType.RespectSeeker, 3);

        assertEq(ownerBalanceAfter, projectFee + ownerBalanceBefore);
        assertEq(homie1BalanceAfter, refFee + homieFee + homie1BalanceBefore);
        assertEq(homie2BalanceAfter, homieFee + homie2BalanceBefore);
    }

    function test_buy_RevertIfCheat() public {
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);

        _replenishUsdc(testUser1, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser1);
        vm.expectRevert(HustleMarket.Cheat.selector);
        market.buy(TokenType.RespectSeeker, testUser1);
    }

    function test_buy_RevertIfInvalidRef() public {
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);

        _replenishUsdc(testUser1, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser1);
        vm.expectRevert(HustleMarket.InvalidRef.selector);
        market.buy(TokenType.RespectSeeker, testUser2);
    }

    function test_buy_NotUpdateRefIfSecondNft() public {
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);
        collection.ownerMintStreetSoul(TokenType.RespectSeeker);

        _replenishUsdc(testUser1, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser1);
        market.buy(TokenType.RespectSeeker, address(0));

        _replenishUsdc(testUser1, prices[uint256(TokenType.RespectSeeker)]);
        _changePrank(testUser1);
        market.buy(TokenType.RespectSeeker, address(0));
        UserInfo memory user1 = market.getUserInfo(testUser1);
        assertEq(user1.ref, owner);
        assertEq(user1.connectionTimestamp, block.timestamp);
        assertEq(market.totalUsers(), 1);
        assertEq(user1.refCount, 0);
        assertEq(
            user1.spentInGame,
            prices[uint256(TokenType.RespectSeeker)] * 2
        );
        assertEq(user1.earnedInGame, 0);
    }

    function test_onERC721Received_RevertIfNotFromZeroAddress() public {
        vm.expectRevert(HustleMarket.ForbiddenSender.selector);
        market.onERC721Received(address(0), testUser1, 1, abi.encodePacked());
    }

    function _checkHealth(
        address _user,
        TokenType _tokenType,
        uint256 _predictedValue
    ) public view {
        uint256 tokenId = collection.userTokensByType(_user, _tokenType)[0];
        TokenInfo memory tokenInfo = collection.getTokenInfo(tokenId);
        assertEq(tokenInfo.health, _predictedValue);
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

    function _calculateFees(
        TokenType tokenType
    )
        public
        view
        returns (uint256 homieFee, uint256 projectFee, uint256 refFee)
    {
        uint32 preccision = market.PRECCISION();
        uint256 price = prices[uint256(tokenType)];
        homieFee = (price * market.HOMIE_FEE_PERCENT()) / preccision;
        projectFee = (price * market.PROJECT_FEE_PERCENT()) / preccision;
        refFee = (price * market.REF_FEE_PERCENT()) / preccision;
    }

    function _getHomies(
        uint256 tokenId
    ) private view returns (address homie1, address homie2) {
        address marketOwner = market.owner();
        TokenInfo memory tokenInfo = collection.getTokenInfo(tokenId);
        homie1 = tokenInfo.homie1 == address(0)
            ? marketOwner
            : tokenInfo.homie1;
        homie2 = tokenInfo.homie2 == address(0)
            ? marketOwner
            : tokenInfo.homie2;
    }

    function _replenishUsdc(address _user, uint256 _amount) internal {
        _changePrank(owner);
        usdc.mint(_user, _amount);
        _changePrank(_user);
        usdc.approve(address(market), prices[uint256(TokenType.RespectSeeker)]);
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
