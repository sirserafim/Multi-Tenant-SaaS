import { z } from "zod";
import { EngagementEventTypeSchema } from "../enums/engagement-event-type.js";

/**
 * POST /telemetry request body.
 * Validated identically on web (client guard) and API (authoritative).
 */
export const TelemetryEventSchema = z.object({
  event_type: EngagementEventTypeSchema,
  tenant_id: z.string().uuid(),
  /** Required for listing-scoped events; omitted only for tenant-level signals. */
  listing_id: z.string().uuid().optional(),
  /** Replay-safe deduplication key — enforced unique at the database layer. */
  idempotency_key: z.string().min(1).max(128),
  /** Client clock; server still records server-side timestamp for auditing. */
  client_timestamp: z.string().datetime({ offset: true }).optional(),
  /** Non-indexed event context (dwell ms, viewport, etc.). */
  metadata: z.record(z.unknown()).optional(),
});

export type TelemetryEvent = z.infer<typeof TelemetryEventSchema>;
