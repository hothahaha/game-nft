// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Upgradeable} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Upgradeable.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "./GameNFT.sol";
import "./GameMarketplace.sol";

contract GameLottery is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    VRFConsumerBaseV2Upgradeable
{
    error GameLottery__InsufficientPayment();
    error GameLottery__NoGamesAvailable();

    uint256 private constant MAX_CHANCE_VALUE = 100;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    GameNFT public s_gameNFT;
    GameMarketplace public s_gameMarketplace;

    uint256 private s_entranceFee;
    address private s_vrfCoordinator;
    uint256 private s_subscriptionId;
    bytes32 private s_keyHash;
    uint32 private s_callbackGasLimit;

    mapping(uint256 => address) private s_requestIdToSender;

    event LotteryEntered(address indexed player);
    event LotteryWon(address indexed player, uint256 indexed tokenId);

    function initialize(
        uint256 _entranceFee,
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        address _gameNFT,
        address _gameMarketplace
    ) external initializer {
        __UUPSUpgradeable_init();
        __VRFConsumerBaseV2_init(_vrfCoordinator);
        __Ownable_init(msg.sender);
        s_entranceFee = _entranceFee;
        s_vrfCoordinator = _vrfCoordinator;
        s_subscriptionId = _subscriptionId;
        s_keyHash = _keyHash;
        s_callbackGasLimit = _callbackGasLimit;
        s_gameNFT = GameNFT(_gameNFT);
        s_gameMarketplace = GameMarketplace(_gameMarketplace);
    }

    function enterLottery() external payable {
        if (msg.value < s_entranceFee)
            revert GameLottery__InsufficientPayment();

        VRFV2PlusClient.RandomWordsRequest memory params = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: s_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = IVRFCoordinatorV2Plus(s_vrfCoordinator)
            .requestRandomWords(params);

        s_requestIdToSender[requestId] = msg.sender;

        emit LotteryEntered(msg.sender);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        address player = s_requestIdToSender[_requestId];
        uint256 randomNumber = _randomWords[0] % MAX_CHANCE_VALUE;
        GameNFT.Rarity wonRarity = getGameFromRarity(randomNumber);

        uint256 wonTokenId = s_gameNFT.getRandomGameByRarity(
            wonRarity,
            _randomWords[0]
        );

        s_gameMarketplace.addUserGame(player, wonTokenId);
        emit LotteryWon(player, wonTokenId);
    }

    function getGameFromRarity(
        uint256 moddedRng
    ) public pure returns (GameNFT.Rarity) {
        uint8[4] memory chanceValues = [55, 30, 12, 3];
        uint256 cumulativeProbability = 0;
        for (uint256 i = 0; i < 4; i++) {
            cumulativeProbability += chanceValues[i];
            if (moddedRng < cumulativeProbability) {
                return GameNFT.Rarity(i);
            }
        }
        return GameNFT.Rarity.Common;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function getEntranceFee() public view returns (uint256) {
        return s_entranceFee;
    }

    function getVRFCoordinator() public view returns (address) {
        return s_vrfCoordinator;
    }
}
