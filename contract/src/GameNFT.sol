// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Script, console2} from "forge-std/Script.sol";

contract GameNFT is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    Script
{
    // 错误
    error GameNFT__InvalidDiscount();
    error GameNFT__NoGamesOfThisRarity();
    error GameNFT__InvalidRating();
    error GameNFT__UnauthorizedReviewer();

    // 静态变量
    uint8 private constant MAX_RATING = 10;
    uint256 private constant ZERO_NUM = 0;

    enum Rarity {
        Common,
        Rare,
        Epic,
        Legendary
    }

    struct Game {
        string name;
        string description;
        uint96 price; // 使用uint96以便与uint160打包
        string imageURI;
        Rarity rarity;
        uint8 discount;
        uint8 averageRating;
        uint32 totalRatings;
        uint32 numberOfReviews;
    }

    struct Review {
        address reviewer;
        uint8 rating;
        string comment;
        uint40 timestamp;
    }

    mapping(uint256 => Game) private s_games;
    mapping(Rarity => uint256[]) private s_gamesByRarity;
    uint256 private s_nextTokenId;

    mapping(uint256 => Review[]) private s_gameReviews;
    mapping(uint256 => mapping(address => bool)) private s_hasReviewed;

    event GameCreated(uint256 indexed tokenId, Rarity rarity);
    event DiscountSet(uint256 indexed tokenId, uint8 discount);
    event GameReviewed(
        uint256 indexed tokenId,
        address indexed reviewer,
        uint8 rating
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        super.transferFrom(from, to, tokenId);
        console2.log("from:", from);
        console2.log("tokenId:", ownerOf(tokenId));
        Game storage game = s_games[tokenId];
        uint256[] storage gamesOfRarity = s_gamesByRarity[game.rarity];
        for (uint256 i = 0; i < gamesOfRarity.length; i++) {
            if (gamesOfRarity[i] == tokenId) {
                gamesOfRarity[i] = gamesOfRarity[gamesOfRarity.length - 1];
                gamesOfRarity.pop();
                break;
            }
        }
    }

    function initialize(address initialOwner) external initializer {
        __ERC721_init("GameNFT", "GNFT");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function createGame(
        string calldata name,
        string calldata description,
        uint96 price,
        string calldata imageURI,
        Rarity rarity
    ) external onlyOwner {
        uint256 tokenId = s_nextTokenId++;
        s_games[tokenId] = Game(
            name,
            description,
            price,
            imageURI,
            rarity,
            100,
            uint8(ZERO_NUM),
            uint32(ZERO_NUM),
            uint32(ZERO_NUM)
        );
        s_gamesByRarity[rarity].push(tokenId);
        _safeMint(msg.sender, tokenId);
        emit GameCreated(tokenId, rarity);
    }

    function setDiscount(uint256 tokenId, uint8 discount) external onlyOwner {
        if (discount > 100) {
            revert GameNFT__InvalidDiscount();
        }
        s_games[tokenId].discount = discount;
        emit DiscountSet(tokenId, discount);
    }

    function getGame(uint256 tokenId) external view returns (Game memory) {
        return s_games[tokenId];
    }

    function getGamesByRarity(
        Rarity rarity
    ) external view returns (uint256[] memory) {
        return s_gamesByRarity[rarity];
    }

    function getRandomGameByRarity(
        Rarity rarity,
        uint256 randomness
    ) external view returns (uint256) {
        uint256[] storage gamesOfRarity = s_gamesByRarity[rarity];
        if (gamesOfRarity.length == 0) {
            revert GameNFT__NoGamesOfThisRarity();
        }
        return gamesOfRarity[randomness % gamesOfRarity.length];
    }

    function getAllGames() external view returns (Game[] memory) {
        Game[] memory allGames = new Game[](s_nextTokenId);
        for (uint256 i = 0; i < s_nextTokenId; i++) {
            allGames[i] = s_games[i];
        }
        return allGames;
    }

    function getGames(
        uint256[] memory tokenIds
    ) external view returns (Game[] memory) {
        Game[] memory games = new Game[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            games[i] = s_games[tokenIds[i]];
        }
        return games;
    }

    function reviewGame(
        uint256 tokenId,
        uint8 rating,
        string calldata comment
    ) external {
        if (rating > MAX_RATING) {
            revert GameNFT__InvalidRating();
        }
        if (s_hasReviewed[tokenId][msg.sender]) {
            revert GameNFT__UnauthorizedReviewer();
        }

        s_gameReviews[tokenId].push(
            Review({
                reviewer: msg.sender,
                rating: rating,
                comment: comment,
                timestamp: uint40(block.timestamp)
            })
        );

        s_hasReviewed[tokenId][msg.sender] = true;

        Game storage game = s_games[tokenId];
        game.totalRatings += rating;
        game.numberOfReviews++;
        game.averageRating = uint8(game.totalRatings / game.numberOfReviews);

        emit GameReviewed(tokenId, msg.sender, rating);
    }

    function getGameReviews(
        uint256 tokenId
    ) external view returns (Review[] memory) {
        return s_gameReviews[tokenId];
    }

    function getGameAverageRating(
        uint256 tokenId
    ) external view returns (uint8) {
        return s_games[tokenId].averageRating;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
