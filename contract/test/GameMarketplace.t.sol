// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GameMarketplace} from "../src/GameMarketplace.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {DeployGameNFT} from "../script/DeployGameNFT.s.sol";
import {DeployGameMarketplace} from "../script/DeployGameMarketplace.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GameMarketplaceTest is Test {
    GameMarketplace public gameMarketplace;
    GameNFT public gameNFT;
    address public deployer;
    address public user1;
    address public user2;

    uint256 private constant REFUND_PERIOD = 2 hours;

    function setUp() public {
        deployer = msg.sender;
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(deployer);
        DeployGameMarketplace deployGameMarketplace = new DeployGameMarketplace();
        (gameMarketplace, gameNFT) = deployGameMarketplace.run(deployer);

        gameNFT.createGame(
            "Test Game",
            "Description",
            100,
            "imageURI",
            GameNFT.Rarity.Common
        );
        gameNFT.setDiscount(0, 90); // 10% discount
        gameNFT.approve(address(gameMarketplace), 0); // 授权 GameMarketplace 操作 NFT
        gameNFT.transferFrom(deployer, address(gameMarketplace), 0);
        vm.stopPrank();
    }

    function testAddToCart() public {
        vm.startPrank(user1);
        gameMarketplace.addToCart(0);
        GameNFT.Game[] memory cart = gameMarketplace.getUserCart(user1);
        assertEq(cart.length, 1);
        assertEq(cart[0].name, "Test Game");
        vm.stopPrank();
    }

    function testRemoveFromCart() public {
        vm.startPrank(user1);
        gameMarketplace.addToCart(0);
        gameMarketplace.removeFromCart(0);
        GameNFT.Game[] memory cart = gameMarketplace.getUserCart(user1);
        assertEq(cart.length, 0);
        vm.stopPrank();
    }

    function testPurchaseGames() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        gameMarketplace.addToCart(0);
        gameMarketplace.purchaseGames{value: 90}(); // 10% discount applied
        uint256[] memory userGames = gameMarketplace.getUserGames(user1);
        assertEq(userGames.length, 1);
        assertEq(userGames[0], 0);
        vm.stopPrank();
    }

    function testPurchaseGamesFailsWithInsufficientPayment() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        gameMarketplace.addToCart(0);
        vm.expectRevert(
            GameMarketplace.GameMarketplace__InsufficientPayment.selector
        );
        gameMarketplace.purchaseGames{value: 9}(); // Insufficient payment
        vm.stopPrank();
    }

    function testRefundGame() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        gameMarketplace.addToCart(0);
        gameMarketplace.purchaseGames{value: 90}();

        uint256 balanceBefore = user1.balance;
        gameNFT.approve(address(gameMarketplace), 0);
        gameMarketplace.refundGame(0);
        uint256 balanceAfter = user1.balance;
        assertEq(balanceAfter - balanceBefore, 90);
        uint256[] memory userGames = gameMarketplace.getUserGames(user1);
        assertEq(userGames.length, 0);
        vm.stopPrank();
    }

    function testRefundGameAfterRefundPeriod() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        gameMarketplace.addToCart(0);
        gameMarketplace.purchaseGames{value: 90}();
        vm.warp(block.timestamp + 2 hours + 1 seconds);
        vm.expectRevert(
            GameMarketplace.GameMarketplace__RefundPeriodExpired.selector
        );
        gameMarketplace.refundGame(0);
        vm.stopPrank();
    }

    function testRefundGameForNonOwner() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        gameMarketplace.addToCart(0);
        gameMarketplace.purchaseGames{value: 90}();
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(
            GameMarketplace.GameMarketplace__NotOwnerOfGame.selector
        );
        gameMarketplace.refundGame(0);
        vm.stopPrank();
    }
}
