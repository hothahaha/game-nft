import GameList from "@/components/GameList";
import Header from "@/components/Header";

export default function Home() {
  return (
    <main className="min-h-screen bg-gray-100">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-4xl font-bold mb-8">Game NFT Marketplace</h1>
        <GameList />
      </div>
    </main>
  );
}
