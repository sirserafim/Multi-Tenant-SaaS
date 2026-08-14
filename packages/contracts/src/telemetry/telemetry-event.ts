import { z } from "zod";
import { DeviceTypeSchema } from "../enums/device-type.js";
import { EngagementEventTypeSchema } from "../enums/engagement-event-type.js";
import { RedemptionCodeSchema } from "../entities/redemption.js";
import { TimestampSchema } from "../primitives.js";

/**
 * POST /telemetry request body.
 * Validated identically on web (client guard) and API (authoritative).
 */
export const TelemetryEventSchema = z.object({
  event_type: EngagementEventTypeSchema,
  tenant_id: z.string().uuid(),
  /** Required for listing-scoped events; omitted only for tenant-level signals. */
  listing_id: z.string().uuid().optional(),
  /** Client-generated guest session — shared with redemptions / ledger attribution. */
  session_id: z.string().uuid(),
  /**
   * Client-generated event id (UUID v4 recommended).
   * Unique at the DB layer — retries return the original result.
   */
  idempotency_key: z.string().uuid(),
  /** Client clock; server still records server-side timestamp for auditing. */
  client_timestamp: TimestampSchema.optional(),
  /** Dwell duration in ms — sent by client on modal close (modal_dwell). */
  duration_ms: z.number().int().min(0).optional(),
  /** Client hint only — API may ignore or override from User-Agent. */
  device_type: DeviceTypeSchema.optional(),
  /** Coupon code — required when event_type is coupon_redeem. */
  code: RedemptionCodeSchema.optional(),
  /** Discount percent — required when event_type is coupon_redeem. */
  discount_pct: z.number().int().min(0).max(100).optional(),
  /** Non-indexed event context (viewport, etc.). */
  metadata: z.record(z.unknown()).optional(),
});

export type TelemetryEvent = z.infer<typeof TelemetryEventSchema>;
