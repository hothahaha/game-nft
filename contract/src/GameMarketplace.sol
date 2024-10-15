// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./GameNFT.sol";

contract GameMarketplace is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    error GameMarketplace__InsufficientPayment();
    error GameMarketplace__RefundPeriodExpired();
    error GameMarketplace__NotOwnerOfGame();
    error GameMarketplace__GameNotInCart();

    GameNFT public s_gameNFT;

    mapping(address => uint256[]) private s_userGames;
    mapping(address => uint256[]) private s_userCart;

    event GamePurchased(address indexed buyer, uint256 indexed tokenId);
    event GameRefunded(address indexed buyer, uint256 indexed tokenId);
    event GameAddedToCart(address indexed user, uint256 indexed tokenId);
    event GameRemovedFromCart(address indexed user, uint256 indexed tokenId);

    function initialize(
        address initialOwner,
        address _gameNFT
    ) public initializer {
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
                return;
            }
        }
        revert GameMarketplace__GameNotInCart();
    }

    function getUserCart(
        address user
    ) external view returns (GameNFT.Game[] memory) {
        uint256[] storage cartTokenIds = s_userCart[user];
        GameNFT.Game[] memory cartGames = new GameNFT.Game[](
            cartTokenIds.length
        );
        for (uint256 i = 0; i < cartTokenIds.length; i++) {
            cartGames[i] = s_gameNFT.getGame(cartTokenIds[i]);
        }
        return cartGames;
    }

    function purchaseGames() external payable nonReentrant {
        uint256[] storage cart = s_userCart[msg.sender];
        uint256 totalPrice = 0;
        for (uint256 i = 0; i < cart.length; i++) {
            GameNFT.Game memory game = s_gameNFT.getGame(cart[i]);
            totalPrice += (game.price * (100 - game.discount)) / 100;
        }
        if (msg.value < totalPrice)
            revert GameMarketplace__InsufficientPayment();

        for (uint256 i = 0; i < cart.length; i++) {
            uint256 tokenId = cart[i];
            s_gameNFT.transferFrom(address(s_gameNFT), msg.sender, tokenId);
            s_userGames[msg.sender].push(tokenId);
            s_gameNFT.setPurchaseTimestamp(tokenId);
            emit GamePurchased(msg.sender, tokenId);
        }

        delete s_userCart[msg.sender];

        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function refundGame(uint256 tokenId) external nonReentrant {
        if (s_gameNFT.ownerOf(tokenId) != msg.sender)
            revert GameMarketplace__NotOwnerOfGame();
        if (
            block.timestamp > s_gameNFT.getPurchaseTimestamp(tokenId) + 24 hours
        ) revert GameMarketplace__RefundPeriodExpired();

        GameNFT.Game memory game = s_gameNFT.getGame(tokenId);
        uint256 refundAmount = (game.price * (100 - game.discount)) / 100;

        s_gameNFT.transferFrom(msg.sender, address(s_gameNFT), tokenId);
        _removeUserGame(msg.sender, tokenId);

        payable(msg.sender).transfer(refundAmount);

        emit GameRefunded(msg.sender, tokenId);
    }

    function getUserGames(
        address user
    ) external view returns (uint256[] memory) {
        return s_userGames[user];
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
