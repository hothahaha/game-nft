// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GameLottery} from "../src/GameLottery.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {GameMarketplace} from "../src/GameMarketplace.sol";
import {DeployGameMarketplace} from "../script/DeployGameMarketplace.s.sol";
import {HelperConfig} from "script/HelperConfig.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployGameLottery is Script {
    function run(
        address initialOwner
    ) external returns (GameLottery, GameNFT, GameMarketplace, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        _setupSubscription(config);

        (
            GameMarketplace gameMarketplace,
            GameNFT gameNFT
        ) = new DeployGameMarketplace().run(initialOwner);

        GameLottery gameLottery = _deployGameLottery(
            config,
            address(gameNFT),
            address(gameMarketplace)
        );

        new AddConsumer().addConsumer(
            address(gameLottery),
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );

        return (gameLottery, gameNFT, gameMarketplace, helperConfig);
    }

    function _setupSubscription(
        HelperConfig.NetworkConfig memory config
    ) internal {
        if (config.subscriptionId == 0) {
            (
                config.subscriptionId,
                config.vrfCoordinator
            ) = new CreateSubscription().createSubscription(
                config.vrfCoordinator,
                config.account
            );

            new FundSubscription().fundSubscription(
                config.subscriptionId,
                config.vrfCoordinator,
                config.link,
                config.account
            );
        }
    }

    function _deployGameLottery(
        HelperConfig.NetworkConfig memory config,
        address gameNFTAddress,
        address gameMarketplaceAddress
    ) internal returns (GameLottery) {
        GameLottery implementation = new GameLottery();
        bytes memory data = abi.encodeWithSelector(
            GameLottery.initialize.selector,
            config.entranceFee,
            config.vrfCoordinator,
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            gameNFTAddress,
            gameMarketplaceAddress
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        return GameLottery(address(proxy));
    }
}
