import { z } from "zod";

const TimestampSchema = z.string().datetime({ offset: true });

/**
 * Immutable record of a coupon scan at checkout.
 * Captured from day one — redemption history is the future monetization asset.
 */
export const RedemptionSchema = z.object({
  id: z.string().uuid(),
  tenant_id: z.string().uuid(),
  listing_id: z.string().uuid(),
  /** Client-generated key for idempotent inserts under concurrent requests. */
  idempotency_key: z.string().min(1).max(128),
  redeemed_at: TimestampSchema,
  /** Credit amount in minor units; always 0 until real pricing is enabled. */
  amount_minor: z.number().int().min(0),
});

export type Redemption = z.infer<typeof RedemptionSchema>;
