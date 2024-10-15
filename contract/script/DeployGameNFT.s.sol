// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {GameNFT} from "../src/GameNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployGameNFT is Script {
    function run(address initialOwner) external returns (GameNFT) {
        GameNFT implementation = new GameNFT();
        bytes memory data = abi.encodeWithSelector(
            GameNFT.initialize.selector,
            initialOwner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        return GameNFT(address(proxy));
    }
}
