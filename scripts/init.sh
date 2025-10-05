#!/usr/bin/env bash

set -e

APP_NAME="fluent-flow"

echo "🚀 Starting setup..."

# Remove any existing app directory
rm -rf $APP_NAME

# 1. Create Next.js TypeScript app with Tailwind, src directory, app router, and yes ESLint
echo "🛠 Creating Next.js app..."
npx create-next-app@latest $APP_NAME --ts --tailwind --src-dir --app --eslint --use-npm --no-turbopack

cd $APP_NAME

# 2. Install dependencies you can change emailer to your preferred email library like resend
echo "📦 Installing dependencies..."
npm install zod @tanstack/react-query @shadcn/ui drizzle-orm postgres pg dotenv next-auth @auth/drizzle-adapter @aws-sdk/client-s3 @supabase/supabase-js nodemailer @t3-oss/env-nextjs
npm install -D drizzle-kit tsx @types/pg eslint-plugin-drizzle @types/nodemailer

# Add env.js
echo "📝 Setting up environment variables...
cat > src/env.js <<EOF
import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    DATABASE_URL: z.string().url(),
    NODE_ENV: z
      .enum(["development", "test", "production"])
      .default("development"),
  },
  runtimeEnv: {
    DATABASE_URL: process.env.DATABASE_URL,
    NODE_ENV: process.env.NODE_ENV,
  },
  skipValidation: !!process.env.SKIP_ENV_VALIDATION,
  emptyStringAsUndefined: true,
});
EOF

# Drizzle init
echo "🗄 Initializing Drizzle..."
cat > drizzle.config.ts <<EOF
import { type Config } from "drizzle-kit";

import { env } from "src/env";

export default {
  schema: "./src/server/db/schema.ts",
  dialect: "postgresql",
  dbCredentials: {
    url: env.DATABASE_URL,
  },
  tablesFilter: ["$APP_NAME_*"],
} satisfies Config;
EOF

mkdir -p src/server/db
cat > src/server/db/index.ts <<EOF
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "pg";

import { env } from "src/env";
import * as schema from "./schema";

/**
 * Cache the database connection in development.
 * This avoids creating a new connection on every HMR (Hot Module Replacement) update.
 */
const globalForDb = globalThis as unknown as {
  conn: postgres.Sql | undefined;
};

const conn = globalForDb.conn ?? postgres(env.DATABASE_URL);
if (env.NODE_ENV !== "production") globalForDb.conn = conn;

export const db = drizzle(conn, { schema });
EOF

# Overwrite Drizzle schema to support NextAuth
cat > src/server/db/schema.ts <<EOF
import { sql } from "drizzle-orm";
import {
  index,
  integer,
  pgTableCreator,
  timestamp,
  unique,
  varchar
} from "drizzle-orm/pg-core";

export const createTable = pgTableCreator((name) => `$APP_NAME_${name}`);

const createdAt = timestamp("created_at", { withTimezone: true })
  .default(sql`CURRENT_TIMESTAMP`).notNull()
const updatedAt = timestamp("updated_at", { withTimezone: true })
  .$onUpdate(() => new Date());

export const users = createTable(
  "user", {
    id: varchar("id", { length: 36 }).primaryKey().notNull().default(sql`gen_random_uuid()`),
    name: varchar("name", { length: 200 }).notNull(),
    email: varchar("email", { length: 200 }).unique().notNull(),
    image: varchar("image", { length: 200 }),
    hashedPassword: varchar("hashed_password", { length: 60 }).notNull(),
    createdAt,
    updatedAt
  }, row => ({
    emailIndex: index("email_idx").on(row.email),
    nameIndex: index("name_idx").on(row.name)
  })
);

const userIdRestrict = varchar("user_id", { length: 36 }).references(() => users.id, { onDelete: 'restrict' }).notNull();
const userIdCascade = varchar("user_id", { length: 36 }).references(() => users.id, { onDelete: 'cascade' }).notNull();

export const Accounts = createTable(
  "account", {
    id: varchar("id", { length: 36 }).primaryKey().notNull().default(sql`gen_random_uuid()`),
    userId: userIdRestrict,
    type: varchar("type", { length: 50 }).notNull(),
    provider: varchar("provider", { length: 50 }).notNull(),
    providerAccountId: varchar("provider_account_id", { length: 100 }).notNull(),
    refreshToken: varchar("refresh_token", { length: 200 }),
    accessToken: varchar("access_token", { length: 200 }),
    expiresAt: integer("expires_at"),
    tokenType: varchar("token_type", { length: 50 }),
    scope: varchar("scope", { length: 200 }),
    idToken: varchar("id_token", { length: 200 }),
    sessionState: varchar("session_state", { length: 200 }),
    createdAt,
    updatedAt
  }, row => ({
    providerAccountIdIndex: index("provider_account_id_idx").on(row.provider, row.providerAccountId),
    providerAccountUnique: unique("provider_account_id_unique").on(row.provider, row.providerAccountId)
  })
);

export const Sessions = createTable(
  "session", {
    id: varchar("id", { length: 36 }).primaryKey().notNull().default(sql`gen_random_uuid()`),
    sessionToken: varchar("session_token", { length: 64 }).unique().notNull(),
    userId: userIdRestrict,
    expires: timestamp("expires", { withTimezone: true }).notNull(),
    createdAt,
    updatedAt
  }, row => ({
    sessionTokenIndex: unique("session_token_unique").on(row.sessionToken),
    userIdIndex: index("user_id_idx").on(row.userId)
  })
);
EOF


# 3. Setup shadcn/ui
echo "🎨 Setting up shadcn/ui..."
npx shadcn@latest init
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add input

# 4. Create directory structure and files
echo "📂 Creating directory structure..."

mkdir -p src/app/dashboard
mkdir -p src/components/ui
mkdir -p src/components/atoms
mkdir -p src/components/organisms
mkdir -p src/components/ClientProvider
mkdir -p src/functions
mkdir -p src/hooks
mkdir -p src/queries
mkdir -p src/server
mkdir -p src/server/db
mkdir -p src/server/email/templates
mkdir -p src/server/zod

# App layout (Server Component)
cat > src/app/layout.tsx <<EOF
import "./globals.css";
import React from "react";

export const metadata = {
  title: "$APP_NAME",
  description: "A Next.js Starter",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
EOF

# ClientProvider Component (Client Component)
cat > src/components/ClientProvider/index.tsx <<EOF
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

const queryClient = new QueryClient();

export default function ClientProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}
EOF

# Main page
cat > src/app/page.tsx <<EOF
import React from "react";
import ClientProvider from "src/components/ClientProvider";

export default function Page() {
  return (
    <ClientProvider>
      <div className="p-4">
        <h1 className="text-xl font-bold">Welcome to $APP_NAME</h1>
        <p>Next.js + NextAuth + Prisma + and more...</p>
      </div>
    </ClientProvider>
  );
}
EOF

# NextAuth route and config
mkdir -p src/server/auth

cat > src/app/auth.ts <<EOF
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
EOF

# Zod schema
cat > src/server/zod/userSchemas.ts <<EOF
import { z } from 'zod';

export const signUpSchema = z.object({
  name: z.string().min(4).max(60),
  email: z.string().email(),
  password: z.string().min(4)
});

export const signInSchema = z.object({
  email: z.string().email(),
  password: z.string().min(4)
});

export const recoverPasswordSchema = z.object({
  email: z.string().email()
});

export const resetPasswordSchema = z.object({
  email: z.string().email(),
  password: z.string().min(4),
  token: z.string()
});
EOF


# Resend email setup
cat > src/server/email/emailer.ts <<EOF
'use server';
import nodemailer from 'nodemailer';

import isEmailValid from '~/functions/isEmailValid';

const sendEmail = async (to: string, subject: string, text: string, html: string) => {
  'use server';
  if (!isEmailValid(to)) throw new Error('Invalid email');
  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: {
      user: 'your@gmail.com',
      pass: 'your-email-password'
    },
  });
  await transporter.sendMail({from: '"$APP_NAME" <your@gmail.com>', to, subject, text, html});
};
EOF

cat > src/server/email/templates/getWelcomeTemplate.ts <<EOF
const getWelcomeTemplate = (name: string) => {
  return `
    <div>
      <h1>Welcome, ${name}!</h1>
      <p>Thanks for joining us!</p>
    </div>
  `;
};

export default getWelcomeTemplate;
EOF

# Example React Query hook
cat > src/hooks/useQueryHooks.ts <<EOF
import { useQuery } from "@tanstack/react-query";

export function useExampleQuery() {
  return useQuery({
    queryKey: ["example"],
    queryFn: async () => {
      return { data: "Hello from React Query" };
    },
  });
}
EOF

echo "⚠️ Note: Drizzle migrate requires DATABASE_URL and NextAuth requires EMAIL settings. Set these in a .env file."
echo "Example .env:"
echo "DATABASE_URL='postgresql://...'"
echo "EMAIL_PASSWORD='...' # password for your email"
echo "EMAIL_FROM='no-reply@yourdomain.com'"
echo
echo "Then run: npx drizzle-kit push"
echo "Start dev server: npm run dev"
echo "npm create storybook@latest to add Storybook"
echo "✅ Setup Complete!"
