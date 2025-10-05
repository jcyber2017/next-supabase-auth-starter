import NextAuth, { type Session } from "next-auth"
import EmailProvider from "next-auth/providers/email"
import { DrizzleAdapter } from "@auth/drizzle-adapter"
import type { AdapterUser } from "next-auth/adapters"

import { accounts, sessions, users, verificationTokens, authenticators } from "../server/db/schema"
import { db } from "src/server/db"

export const { handlers, signIn, signOut, auth } = NextAuth({
  adapter: DrizzleAdapter(db, {
    usersTable: users,
    accountsTable: accounts,
    sessionsTable: sessions,
    verificationTokensTable: verificationTokens,
    authenticatorsTable: authenticators
  }),
  providers: [
    EmailProvider({
      server: process.env.EMAIL_SERVER,
      from: process.env.EMAIL_FROM
    })
  ],
  session: {
    strategy: "database",
  },
  callbacks: {
    async session({ session, user }: { session: Session; user: AdapterUser }) {
      if (user) {
        session.user = user
      }
      return session
    },
  },
});
