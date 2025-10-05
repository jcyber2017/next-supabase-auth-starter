import { sql } from "drizzle-orm";
import {
  integer,
  pgTable,
  timestamp,
  boolean,
  text,
  uuid,
  primaryKey
} from "drizzle-orm/pg-core";
import type { ProviderType } from "next-auth/providers/index";

type AdapterAccountType = Extract<ProviderType, "oauth" | "oidc" | "email" | "webauthn">;

const createdAt = timestamp("created_at", { withTimezone: true })
  .default(sql`CURRENT_TIMESTAMP`).notNull()
const updatedAt = timestamp("updated_at", { withTimezone: true })
  .$onUpdate(() => new Date());

const tableId = uuid("id").primaryKey().default(sql`gen_random_uuid()`).notNull();

export const users = pgTable("user", {
  id: tableId,
  name: text("name"),
  email: text("email").unique(),
  emailVerified: timestamp("emailVerified", { mode: "date" }),
  image: text("image"),
  createdAt,
  updatedAt
})

// const userIdRestrict = uuid("user_id").references(() => users.id, { onDelete: 'restrict' }).notNull();
const userIdCascade = uuid("user_id").references(() => users.id, { onDelete: 'cascade' }).notNull();

export const accounts = pgTable("account",
  {
    userId: userIdCascade,
    type: text("type").$type<AdapterAccountType>().notNull(),
    provider: text("provider").notNull(),
    providerAccountId: text("providerAccountId").notNull(),
    refresh_token: text("refresh_token"),
    access_token: text("access_token"),
    expires_at: integer("expires_at"),
    token_type: text("token_type"),
    scope: text("scope"),
    id_token: text("id_token"),
    session_state: text("session_state"),
    createdAt,
    updatedAt
  },
  (account) => [
    {
      compoundKey: primaryKey({
        columns: [account.provider, account.providerAccountId],
      }),
    },
  ]
)
 
export const sessions = pgTable("session", {
  sessionToken: text("sessionToken").primaryKey(),
  userId: userIdCascade,
  expires: timestamp("expires", { mode: "date" }).notNull(),
})
 
export const verificationTokens = pgTable("verificationToken",
  {
    identifier: text("identifier").notNull(),
    token: text("token").notNull(),
    expires: timestamp("expires", { mode: "date" }).notNull(),
  },
  (verificationToken) => [
    {
      compositePk: primaryKey({
        columns: [verificationToken.identifier, verificationToken.token],
      }),
    },
  ]
)
 
export const authenticators = pgTable("authenticator",
  {
    credentialID: text("credentialID").notNull().unique(),
    userId: userIdCascade,
    providerAccountId: text("providerAccountId").notNull(),
    credentialPublicKey: text("credentialPublicKey").notNull(),
    counter: integer("counter").notNull(),
    credentialDeviceType: text("credentialDeviceType").notNull(),
    credentialBackedUp: boolean("credentialBackedUp").notNull(),
    transports: text("transports"),
  },
  (authenticator) => [
    {
      compositePK: primaryKey({
        columns: [authenticator.userId, authenticator.credentialID],
      }),
    },
  ]
)