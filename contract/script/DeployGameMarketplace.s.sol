// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GameMarketplace} from "../src/GameMarketplace.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {DeployGameNFT} from "./DeployGameNFT.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployGameMarketplace is Script {
    function run(
        address initialOwner
    ) external returns (GameMarketplace, GameNFT) {
        DeployGameNFT deployGameNFT = new DeployGameNFT();
        GameNFT gameNFT = deployGameNFT.run(initialOwner);

        // 部署实现合约
        GameMarketplace implementation = new GameMarketplace();

        // 编码初始化调用
        bytes memory data = abi.encodeWithSelector(
            GameMarketplace.initialize.selector,
            msg.sender, // 使用部署者地址作为初始所有者
            address(gameNFT)
        );

        // 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        // 获取代理的GameNFT接口
        GameMarketplace gameMarketplace = GameMarketplace(address(proxy));

        return (gameMarketplace, gameNFT);
    }
}
