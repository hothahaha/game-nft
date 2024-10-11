// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./GameNFT.sol";

contract GameMarketplace is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    Script
{
    // 错误
    error GameMarketplace__InsufficientPayment();
    error GameMarketplace__RefundPeriodExpired();
    error GameMarketplace__NotOwnerOfGame();
    error GameMarketplace__UnauthorizedCaller();

    GameNFT public s_gameNFT;
    mapping(address => uint256[]) private s_userGames;
    mapping(address => uint256[]) private s_userCart;
    mapping(uint256 => uint256) private s_purchaseTime;

    uint256 private constant REFUND_PERIOD = 2 hours;

    event GamePurchased(address indexed buyer, uint256 indexed tokenId);
    event GameRefunded(address indexed buyer, uint256 indexed tokenId);
    event GameAddedToCart(address indexed user, uint256 indexed tokenId);
    event GameRemovedFromCart(address indexed user, uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _gameNFT
    ) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        s_gameNFT = GameNFT(_gameNFT);
    }

    function addToCart(uint256 tokenId) external {
        s_userCart[msg.sender].push(tokenId);
        emit GameAddedToCart(msg.sender, tokenId);
    }

    function removeFromCart(uint256 tokenId) external {
        uint256[] storage cart = s_userCart[msg.sender];
        for (uint256 i = 0; i < cart.length; i++) {
            if (cart[i] == tokenId) {
                cart[i] = cart[cart.length - 1];
                cart.pop();
                emit GameRemovedFromCart(msg.sender, tokenId);
                break;
            }
        }
    }

    function purchaseGames() external payable nonReentrant {
        uint256[] memory cart = s_userCart[msg.sender];
        uint256 totalPrice = 0;
        for (uint256 i = 0; i < cart.length; i++) {
            GameNFT.Game memory game = s_gameNFT.getGame(cart[i]);
            uint256 discountedPrice = (game.price * game.discount) / 100;
            totalPrice += discountedPrice;
        }
        if (msg.value < totalPrice) {
            revert GameMarketplace__InsufficientPayment();
        }

        for (uint256 i = 0; i < cart.length; i++) {
            s_gameNFT.transferFrom(address(this), msg.sender, cart[i]);
            s_userGames[msg.sender].push(cart[i]);
            s_purchaseTime[cart[i]] = block.timestamp;
            emit GamePurchased(msg.sender, cart[i]);
        }

        delete s_userCart[msg.sender];

        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function refundGame(uint256 tokenId) external nonReentrant {
        if (block.timestamp > s_purchaseTime[tokenId] + REFUND_PERIOD) {
            revert GameMarketplace__RefundPeriodExpired();
        }
        if (s_gameNFT.ownerOf(tokenId) != msg.sender) {
            revert GameMarketplace__NotOwnerOfGame();
        }

        GameNFT.Game memory game = s_gameNFT.getGame(tokenId);
        uint256 refundAmount = (game.price * game.discount) / 100;

        s_gameNFT.transferFrom(msg.sender, address(this), tokenId);
        payable(msg.sender).transfer(refundAmount);

        _removeUserGame(msg.sender, tokenId);

        emit GameRefunded(msg.sender, tokenId);
    }

    function getUserGames(
        address user
    ) external view returns (uint256[] memory) {
        return s_userGames[user];
    }

    function getUserCart(
        address user
    ) external view returns (GameNFT.Game[] memory) {
        uint256[] storage cartTokenIds = s_userCart[user];
        return s_gameNFT.getGames(cartTokenIds);
    }

    function addUserGame(address user, uint256 tokenId) external {
        s_userGames[user].push(tokenId);
    }

    function _removeUserGame(address user, uint256 tokenId) private {
        uint256[] storage games = s_userGames[user];
        for (uint256 i = 0; i < games.length; i++) {
            if (games[i] == tokenId) {
                games[i] = games[games.length - 1];
                games.pop();
                break;
            }
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
