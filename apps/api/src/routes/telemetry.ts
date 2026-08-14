import { Router } from "express";
import {
  TelemetryEventSchema,
  type TelemetryEvent,
} from "@multi-tenant-saas/contracts";
import type { Pool } from "pg";
import { AppError } from "../lib/errors.js";
import { logger } from "../lib/logger.js";
import { recordTelemetryEvent } from "../services/telemetry.js";

export function createTelemetryRouter(pool: Pool): Router {
  const router = Router();

  /*
   * POST /api/telemetry/event is a fraud magnet once ledger amounts are real money:
   * a guest (or bot) could spam paid intent events or replay coupon codes to mint credits.
   *
   * Controls that already blunt that:
   * 1) Idempotency_key UNIQUE — exact retries return the original row, no double credit.
   * 2) 24h dedup per (session, listing, event_type) — drip-feeding the same intent
   *    yields at most one ledger row per day.
   * 3) Per-IP and per-session rate limits — volume spikes die at the edge.
   * 4) tenant_listings membership — forged tenant/listing pairs are recorded but
   *    never credited.
   * 5) priceEngagementEvent() is the only amount source — insert sites cannot
   *    hardcode payouts.
   * 6) Coupon code UNIQUE — already-redeemed codes abort the whole transaction (409).
   * 7) Writes use the server DB role only — browsers never touch ledger/redemptions.
   */
  router.post("/event", async (req, res, next) => {
    try {
      const parsed = TelemetryEventSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new AppError(400, "validation_error", "Invalid request body", {
          issues: parsed.error.issues.map((i) => ({
            path: i.path.join("."),
            code: i.code,
          })),
        });
      }

      const event: TelemetryEvent = parsed.data;
      const ip = req.ip || req.socket.remoteAddress || "unknown";

      const result = await recordTelemetryEvent(pool, event, {
        ip,
        userAgent: req.header("user-agent") ?? undefined,
      });

      logger.info("telemetry_event_recorded", {
        request_id: req.requestId,
        status: result.status,
        event_type: event.event_type,
        engagement_event_id: result.engagement_event_id,
        ledger_entry_id: result.ledger_entry_id,
        redemption_id: result.redemption_id,
        ledger_skipped_reason: result.ledger_skipped_reason,
      });

      res.status(result.status === "created" ? 201 : 200).json(result);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
