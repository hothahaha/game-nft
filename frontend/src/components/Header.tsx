"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import Link from "next/link";

export default function Header() {
  return (
    <header className="bg-white shadow-md">
      <nav className="container mx-auto px-4 py-4 flex justify-between items-center">
        <Link href="/" className="text-xl font-bold">
          Game NFT
        </Link>
        <div className="flex items-center space-x-4">
          <Link href="/cart" className="text-gray-600 hover:text-gray-900">
            Cart
          </Link>
          <Link href="/my-games" className="text-gray-600 hover:text-gray-900">
            My Games
          </Link>
          <ConnectButton />
        </div>
      </nav>
    </header>
  );
}
