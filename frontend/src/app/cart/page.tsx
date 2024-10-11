import Header from "@/components/Header";
import CartList from "@/components/CartList";

export default function Cart() {
  return (
    <main className="min-h-screen bg-gray-100">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-4xl font-bold mb-8">Your Cart</h1>
        <CartList />
      </div>
    </main>
  );
}
