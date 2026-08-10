import { z } from "zod";
import { TimestampSchema } from "../primitives.js";

/** Server-generated scannable coupon code — unique per redemption row. */
const RedemptionCodeSchema = z
  .string()
  .regex(
    /^[A-Z0-9-]{6,32}$/,
    "Redemption code must be 6–32 uppercase letters, digits, or hyphens",
  );

/**
 * Immutable record of a coupon scan at checkout.
 * Captured from day one — redemption history is the future monetization asset.
 */
export const RedemptionSchema = z.object({
  id: z.string().uuid(),
  tenant_id: z.string().uuid(),
  listing_id: z.string().uuid(),
  /** Guest session that generated the per-session redemption code. */
  session_id: z.string().uuid(),
  /** Server-generated scannable code — unique per redemption. */
  code: RedemptionCodeSchema,
  /** Discount applied at checkout (0–100). */
  discount_pct: z.number().int().min(0).max(100),
  /** Client-generated key for idempotent inserts under concurrent requests. */
  idempotency_key: z.string().min(1).max(128),
  redeemed_at: TimestampSchema,
});

export type Redemption = z.infer<typeof RedemptionSchema>;
