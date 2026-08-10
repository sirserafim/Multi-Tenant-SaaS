import { z } from "zod";
import { TimestampSchema } from "../primitives.js";

/** ISO 4217 currency code (e.g. EUR). */
const CurrencyCodeSchema = z
  .string()
  .length(3)
  .regex(/^[A-Z]{3}$/, "Currency must be a 3-letter ISO 4217 code");

/**
 * Append-only credit row for an engagement event.
 * amount_minor is always 0 until real pricing is enabled.
 */
export const LedgerEntrySchema = z.object({
  id: z.string().uuid(),
  tenant_id: z.string().uuid(),
  listing_id: z.string().uuid(),
  /** One credit per engagement event — enforced unique at the database layer. */
  engagement_event_id: z.string().uuid(),
  amount_minor: z.number().int().min(0),
  currency: CurrencyCodeSchema,
  created_at: TimestampSchema,
});

export type LedgerEntry = z.infer<typeof LedgerEntrySchema>;
