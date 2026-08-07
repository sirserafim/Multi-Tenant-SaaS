import { z } from "zod";

/**
 * Guest engagement signals recorded by telemetry.
 * Intent events (call, directions, redeem) may trigger ledger credits.
 */
export const EngagementEventTypeSchema = z.enum([
  "card_open",
  "modal_dwell",
  "call_click",
  "directions_click",
  "website_click",
  "coupon_redeem",
  "hover_desktop",
]);

export type EngagementEventType = z.infer<typeof EngagementEventTypeSchema>;
