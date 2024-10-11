// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DeployGameNFT} from "../script/DeployGameNFT.s.sol";

contract GameNFTTest is Test {
    GameNFT public gameNFT;
    address public deployer;
    address public user1;
    address public user2;

    function setUp() public {
        deployer = msg.sender;
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        DeployGameNFT deployGameNFT = new DeployGameNFT();
        gameNFT = deployGameNFT.run(deployer);

        vm.startPrank(deployer);
        gameNFT.createGame(
            "Test Game",
            "Description",
            100,
            "imageURI",
            GameNFT.Rarity.Common
        );
        vm.stopPrank();
    }

    function testCreateGame() public {
        vm.startPrank(deployer);
        gameNFT.createGame(
            "New Game",
            "New Description",
            200,
            "newImageURI",
            GameNFT.Rarity.Rare
        );
        vm.stopPrank();

        GameNFT.Game memory game = gameNFT.getGame(1);
        assertEq(game.name, "New Game");
        assertEq(game.price, 200);
        assertEq(uint(game.rarity), uint(GameNFT.Rarity.Rare));
    }

    function testSetDiscount() public {
        vm.prank(deployer);
        gameNFT.setDiscount(0, 10);

        GameNFT.Game memory game = gameNFT.getGame(0);
        assertEq(game.discount, 10);
    }

    function testSetDiscountFailsWithInvalidDiscount() public {
        vm.expectRevert(GameNFT.GameNFT__InvalidDiscount.selector);
        vm.prank(deployer);
        gameNFT.setDiscount(0, 101);
    }

    function testReviewGame() public {
        vm.prank(user1);
        gameNFT.reviewGame(0, 8, "Great game!");

        GameNFT.Review[] memory reviews = gameNFT.getGameReviews(0);
        assertEq(reviews.length, 1);
        assertEq(reviews[0].rating, 8);
        assertEq(reviews[0].comment, "Great game!");
    }

    function testReviewGameFailsWithInvalidRating() public {
        vm.expectRevert(GameNFT.GameNFT__InvalidRating.selector);
        vm.prank(user1);
        gameNFT.reviewGame(0, 11, "Invalid rating");
    }

    function testReviewGameFailsWithDuplicateReview() public {
        vm.startPrank(user1);
        gameNFT.reviewGame(0, 8, "First review");
        vm.expectRevert(GameNFT.GameNFT__UnauthorizedReviewer.selector);
        gameNFT.reviewGame(0, 9, "Second review");
        vm.stopPrank();
    }

    function testGetRandomGameByRarity() public {
        vm.startPrank(deployer);
        gameNFT.createGame(
            "Rare Game",
            "Description",
            200,
            "imageURI",
            GameNFT.Rarity.Rare
        );
        vm.stopPrank();

        uint256 commonGameId = gameNFT.getRandomGameByRarity(
            GameNFT.Rarity.Common,
            0
        );
        uint256 rareGameId = gameNFT.getRandomGameByRarity(
            GameNFT.Rarity.Rare,
            0
        );

        assertEq(commonGameId, 0);
        assertEq(rareGameId, 1);
    }

    function testGetRandomGameByRarityFailsForNoGames() public {
        vm.expectRevert(GameNFT.GameNFT__NoGamesOfThisRarity.selector);
        gameNFT.getRandomGameByRarity(GameNFT.Rarity.Epic, 0);
    }
}
