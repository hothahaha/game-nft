"use client";

import { useState, useEffect } from "react";
import GameCard from "./GameCard";
import { useContract, useProvider } from "wagmi";
import { GameNFT__factory } from "@/types/ethers-contracts";

export default function GameList() {
  const [games, setGames] = useState([]);
  const provider = useProvider();
  const gameNFTContract = useContract({
    address: process.env.NEXT_PUBLIC_GAME_NFT_ADDRESS,
    abi: GameNFT__factory.abi,
    signerOrProvider: provider,
  });

  useEffect(() => {
    const fetchGames = async () => {
      if (gameNFTContract) {
        const totalSupply = await gameNFTContract.totalSupply();
        const fetchedGames = [];
        for (let i = 0; i < totalSupply.toNumber(); i++) {
          const game = await gameNFTContract.getGame(i);
          fetchedGames.push({ id: i, ...game });
        }
        setGames(fetchedGames);
      }
    };
    fetchGames();
  }, [gameNFTContract]);

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {games.map((game) => (
        <GameCard key={game.id} game={game} />
      ))}
    </div>
  );
}
