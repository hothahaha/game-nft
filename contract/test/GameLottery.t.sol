// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GameLottery} from "../src/GameLottery.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {GameMarketplace} from "../src/GameMarketplace.sol";
import {DeployGameLottery} from "../script/DeployGameLottery.s.sol";
import {HelperConfig} from "../script/HelperConfig.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract GameLotteryTest is Test {
    GameLottery public gameLottery;
    GameNFT public gameNFT;
    GameMarketplace public gameMarketplace;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    HelperConfig public helperConfig;

    address public deployer;
    address public player;

    uint256 public constant ENTRANCE_FEE = 0.01 ether;

    function setUp() public {
        deployer = msg.sender;
        player = makeAddr("player");

        DeployGameLottery deployGameLottery = new DeployGameLottery();
        (
            gameLottery,
            gameNFT,
            gameMarketplace,
            helperConfig
        ) = deployGameLottery.run(deployer);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);

        vm.startPrank(deployer);
        gameNFT.createGame(
            "Common Game",
            "Description",
            100,
            "imageURI",
            GameNFT.Rarity.Common
        );
        gameNFT.createGame(
            "Rare Game",
            "Description",
            200,
            "imageURI",
            GameNFT.Rarity.Rare
        );
        gameNFT.createGame(
            "Epic Game",
            "Description",
            300,
            "imageURI",
            GameNFT.Rarity.Epic
        );
        gameNFT.createGame(
            "Legendary Game",
            "Description",
            400,
            "imageURI",
            GameNFT.Rarity.Legendary
        );

        vm.stopPrank();
    }

    function testEnterLottery() public {
        vm.startPrank(player);
        vm.deal(player, 1 ether);
        gameLottery.enterLottery{value: ENTRANCE_FEE}();
        vm.stopPrank();
    }

    function testEnterLotteryFailsWithInsufficientPayment() public {
        vm.startPrank(player);
        vm.deal(player, 1 ether);
        vm.expectRevert(GameLottery.GameLottery__InsufficientPayment.selector);
        gameLottery.enterLottery{value: ENTRANCE_FEE - 1}();
        vm.stopPrank();
    }

    function testFulfillRandomWords() public {
        vm.startPrank(player);
        vm.deal(player, 1 ether);
        gameLottery.enterLottery{value: ENTRANCE_FEE}();
        vm.stopPrank();

        uint256 requestId = 1;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 123;

        vm.startPrank(address(vrfCoordinator));
        gameLottery.rawFulfillRandomWords(requestId, randomWords);
        vm.stopPrank();

        uint256[] memory playerGames = gameMarketplace.getUserGames(player);
        assertEq(playerGames.length, 1);
    }

    function testGetGameFromRarity() public view {
        GameNFT.Rarity rarity;

        rarity = gameLottery.getGameFromRarity(0);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Common));

        rarity = gameLottery.getGameFromRarity(55);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Rare));

        rarity = gameLottery.getGameFromRarity(85);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Epic));

        rarity = gameLottery.getGameFromRarity(97);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Legendary));
    }

    function testGameLotteryApproval() public {
        vm.prank(address(gameNFT));
        gameNFT.setApprovalForAll(address(gameLottery), true);

        bool isApproved = gameNFT.isApprovedForAll(
            address(gameNFT),
            address(gameLottery)
        );
        assertTrue(
            isApproved,
            "GameLottery should be approved to transfer NFTs"
        );
    }

    function testInitialize() public view {
        assertEq(gameLottery.getEntranceFee(), ENTRANCE_FEE);
        assertEq(gameLottery.getVRFCoordinator(), address(vrfCoordinator));
    }

    function testGetGameFromRarityEdgeCases() public view {
        GameNFT.Rarity rarity;

        rarity = gameLottery.getGameFromRarity(54);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Common));

        rarity = gameLottery.getGameFromRarity(84);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Rare));

        rarity = gameLottery.getGameFromRarity(96);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Epic));

        rarity = gameLottery.getGameFromRarity(99);
        assertEq(uint(rarity), uint(GameNFT.Rarity.Legendary));
    }
}
