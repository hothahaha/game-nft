// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployGameNFT is Script {
    function run(address initialOwner) external returns (GameNFT) {
        // 部署实现合约
        GameNFT implementation = new GameNFT();

        // 编码初始化调用
        bytes memory data = abi.encodeWithSelector(
            GameNFT.initialize.selector,
            initialOwner // 使用部署者地址作为初始所有者
        );

        // 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        // 获取代理的GameNFT接口
        GameNFT gameNFT = GameNFT(address(proxy));

        return gameNFT;
    }
}
