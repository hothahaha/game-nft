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
        GameNFT gameNFT = new DeployGameNFT().run(initialOwner);

        GameMarketplace implementation = new GameMarketplace();
        bytes memory data = abi.encodeWithSelector(
            GameMarketplace.initialize.selector,
            initialOwner,
            address(gameNFT)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        return (GameMarketplace(address(proxy)), gameNFT);
    }
}
