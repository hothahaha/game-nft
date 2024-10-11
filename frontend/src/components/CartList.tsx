"use client";

import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { useAccount, useContractRead, useContractWrite } from "wagmi";
import {
  GameMarketplace__factory,
  GameNFT__factory,
} from "@/types/ethers-contracts";
import { ethers } from "ethers";

export default function CartList() {
  const [cartItems, setCartItems] = useState([]);
  const { address } = useAccount();

  const { data: cartData } = useContractRead({
    address: process.env.NEXT_PUBLIC_GAME_MARKETPLACE_ADDRESS,
    abi: GameMarketplace__factory.abi,
    functionName: "getUserCart",
    args: [address],
    watch: true,
  });

  const { write: removeFromCart } = useContractWrite({
    address: process.env.NEXT_PUBLIC_GAME_MARKETPLACE_ADDRESS,
    abi: GameMarketplace__factory.abi,
    functionName: "removeFromCart",
  });

  const { write: purchaseGames } = useContractWrite({
    address: process.env.NEXT_PUBLIC_GAME_MARKETPLACE_ADDRESS,
    abi: GameMarketplace__factory.abi,
    functionName: "purchaseGames",
  });

  useEffect(() => {
    const fetchCartItems = async () => {
      if (cartData) {
        const items = await Promise.all(
          cartData.map(async (tokenId) => {
            const game = await GameNFT__factory.connect(
              process.env.NEXT_PUBLIC_GAME_NFT_ADDRESS,
              ethers.getDefaultProvider()
            ).getGame(tokenId);
            return { id: tokenId, ...game };
          })
        );
        setCartItems(items);
      }
    };
    fetchCartItems();
  }, [cartData]);

  const handleRemove = (id) => {
    removeFromCart({ args: [id] });
  };

  const handlePurchase = () => {
    const totalPrice = cartItems.reduce((sum, item) => sum + item.price, 0);
    purchaseGames({ value: totalPrice });
  };

  return (
    <div>
      {cartItems.map((item) => (
        <div key={item.id} className="flex justify-between items-center mb-4">
          <span>
            {item.name} - {ethers.utils.formatEther(item.price)} ETH
          </span>
          <Button onClick={() => handleRemove(item.id)}>Remove</Button>
        </div>
      ))}
      <Button onClick={handlePurchase} className="mt-4">
        Purchase All
      </Button>
    </div>
  );
}
