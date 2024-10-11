import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useAccount, useContractWrite } from "wagmi";
import { GameMarketplace__factory } from "@/types/ethers-contracts";
import { ethers } from "ethers";

export default function GameCard({ game }) {
  const { address } = useAccount();
  const { write: addToCart } = useContractWrite({
    address: process.env.NEXT_PUBLIC_GAME_MARKETPLACE_ADDRESS,
    abi: GameMarketplace__factory.abi,
    functionName: "addToCart",
  });

  const handleAddToCart = () => {
    addToCart({ args: [game.id] });
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{game.name}</CardTitle>
        <CardDescription>{game.description}</CardDescription>
      </CardHeader>
      <CardContent>
        <p>Price: {ethers.utils.formatEther(game.price)} ETH</p>
        <p>Rarity: {game.rarity}%</p>
      </CardContent>
      <CardFooter>
        <Button onClick={handleAddToCart} disabled={!address}>
          Add to Cart
        </Button>
      </CardFooter>
    </Card>
  );
}
