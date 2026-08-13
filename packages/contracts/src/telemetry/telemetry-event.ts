import { z } from "zod";
import { DeviceTypeSchema } from "../enums/device-type.js";
import { EngagementEventTypeSchema } from "../enums/engagement-event-type.js";
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
  /** Replay-safe deduplication key — enforced unique at the database layer. */
  idempotency_key: z.string().min(1).max(128),
  /** Client clock; server still records server-side timestamp for auditing. */
  client_timestamp: TimestampSchema.optional(),
  /** Dwell duration in ms — sent by client on modal close (modal_dwell). */
  duration_ms: z.number().int().min(0).optional(),
  /** Client hint only — API may ignore or override from User-Agent. */
  device_type: DeviceTypeSchema.optional(),
  /** Non-indexed event context (dwell ms, viewport, etc.). */
  metadata: z.record(z.unknown()).optional(),
});

export type TelemetryEvent = z.infer<typeof TelemetryEventSchema>;
