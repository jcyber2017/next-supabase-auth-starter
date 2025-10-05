import React from "react";
import ClientProvider from "src/components/ClientProvider";

export default function Page() {
  return (
    <ClientProvider>
      <div className="p-4">
        <h1 className="text-xl font-bold">Welcome to fluent-flow</h1>
        <p>Next.js + NextAuth + Prisma + and more...</p>
      </div>
    </ClientProvider>
  );
}
