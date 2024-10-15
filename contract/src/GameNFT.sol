// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Script, console2} from "forge-std/Script.sol";

contract GameNFT is
    Initializable,
    ERC721Upgradeable,
    IERC721Receiver,
    OwnableUpgradeable,
    UUPSUpgradeable,
    Script
{
    error GameNFT__InvalidDiscount();
    error GameNFT__NoGamesOfThisRarity();
    error GameNFT__InvalidRating();
    error GameNFT__UnauthorizedReviewer();

    uint8 private constant MAX_RATING = 10;

    enum Rarity {
        Common,
        Rare,
        Epic,
        Legendary
    }

    struct Game {
        string name;
        string description;
        uint256 price;
        uint256 discount;
        string imageURI;
        Rarity rarity;
        uint256 totalRatings;
        uint256 numberOfReviews;
        uint8 averageRating;
    }

    struct Review {
        address reviewer;
        uint8 rating;
        string comment;
        uint40 timestamp;
    }

    uint256[] private s_tokenIds;
    mapping(uint256 => Game) private s_games;
    mapping(Rarity => uint256[]) private s_gamesByRarity;
    mapping(uint256 => Review[]) private s_gameReviews;
    mapping(uint256 => mapping(address => bool)) private s_hasReviewed;
    mapping(uint256 => uint256) private s_purchaseTimestamps;

    event GameCreated(uint256 indexed tokenId, string name, Rarity rarity);
    event GameReviewed(
        uint256 indexed tokenId,
        address indexed reviewer,
        uint8 rating
    );

    function initialize(address initialOwner) public initializer {
        __ERC721_init("GameNFT", "GNFT");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function createGame(
        string memory name,
        string memory description,
        uint256 price,
        string memory imageURI,
        Rarity rarity
    ) external onlyOwner {
        uint256 tokenId = s_tokenIds.length;
        s_games[tokenId] = Game({
            name: name,
            description: description,
            price: price,
            discount: 0,
            imageURI: imageURI,
            rarity: rarity,
            totalRatings: 0,
            numberOfReviews: 0,
            averageRating: 0
        });
        s_gamesByRarity[rarity].push(tokenId);
        s_tokenIds.push(tokenId);
        _safeMint(address(this), tokenId);
        emit GameCreated(tokenId, name, rarity);
    }

    function setDiscount(uint256 tokenId, uint256 discount) external onlyOwner {
        if (discount > 100) revert GameNFT__InvalidDiscount();
        s_games[tokenId].discount = discount;
    }

    function getGame(uint256 tokenId) external view returns (Game memory) {
        return s_games[tokenId];
    }

    function getRandomGameByRarity(
        Rarity rarity,
        uint256 randomness
    ) external view returns (uint256) {
        uint256[] storage gamesOfRarity = s_gamesByRarity[rarity];
        if (gamesOfRarity.length == 0) revert GameNFT__NoGamesOfThisRarity();
        return gamesOfRarity[randomness % gamesOfRarity.length];
    }

    function reviewGame(
        uint256 tokenId,
        uint8 rating,
        string memory comment
    ) external {
        if (rating > MAX_RATING) revert GameNFT__InvalidRating();
        if (s_hasReviewed[tokenId][msg.sender])
            revert GameNFT__UnauthorizedReviewer();

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

    function setPurchaseTimestamp(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the token");
        s_purchaseTimestamps[tokenId] = block.timestamp;
    }

    function getPurchaseTimestamp(
        uint256 tokenId
    ) external view returns (uint256) {
        return s_purchaseTimestamps[tokenId];
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
