// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GameLottery} from "../src/GameLottery.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {GameMarketplace} from "../src/GameMarketplace.sol";
import {DeployGameNFT} from "../script/DeployGameNFT.s.sol";
import {DeployGameMarketplace} from "../script/DeployGameMarketplace.s.sol";
import {HelperConfig} from "script/HelperConfig.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployGameLottery is Script {
    GameNFT gameNFT;
    GameMarketplace gameMarketplace;

    function run(
        address initialOwner
    ) external returns (GameLottery, GameNFT, GameMarketplace, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        _setupSubscription(config);

        (gameNFT, gameMarketplace) = _deployNFTAndMarketplace(initialOwner);

        GameLottery gameLottery = _deployGameLottery(config);

        _addConsumer(address(gameLottery), config);
        return (gameLottery, gameNFT, gameMarketplace, helperConfig);
    }

    function _setupSubscription(
        HelperConfig.NetworkConfig memory config
    ) internal {
        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator, config.account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.subscriptionId,
                config.vrfCoordinator,
                config.link,
                config.account
            );
        }
    }

    function _deployNFTAndMarketplace(
        address initialOwner
    ) internal returns (GameNFT, GameMarketplace) {
        DeployGameMarketplace deployGameMarketplace = new DeployGameMarketplace();
        (gameMarketplace, gameNFT) = deployGameMarketplace.run(initialOwner);

        return (gameNFT, gameMarketplace);
    }

    function _deployGameLottery(
        HelperConfig.NetworkConfig memory config
    ) internal returns (GameLottery) {
        GameLottery implementationGameLottery = new GameLottery();

        bytes memory dataGameLottery = abi.encodeWithSelector(
            GameLottery.initialize.selector,
            config.entranceFee,
            config.vrfCoordinator,
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            address(gameNFT),
            address(gameMarketplace)
        );

        ERC1967Proxy proxyGameLottery = new ERC1967Proxy(
            address(implementationGameLottery),
            dataGameLottery
        );
        GameLottery gameLottery = GameLottery(address(proxyGameLottery));

        return gameLottery;
    }

    function _addConsumer(
        address gameLotteryAddress,
        HelperConfig.NetworkConfig memory config
    ) internal {
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            gameLotteryAddress,
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );
    }
}
