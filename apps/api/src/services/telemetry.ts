import { createHash } from "node:crypto";
import type { DeviceType, TelemetryEvent } from "@multi-tenant-saas/contracts";
import type { Pool } from "pg";
import { AppError } from "../lib/errors.js";
import { isMeaningfulEvent, priceEngagementEvent } from "./pricing.js";

const LEDGER_CURRENCY = "EUR";
const DEDUP_HOURS = 24;

export type TelemetryResult = {
  status: "created" | "duplicate";
  engagement_event_id: string;
  ledger_entry_id: string | null;
  redemption_id: string | null;
  ledger_skipped_reason:
    | "not_meaningful"
    | "not_member"
    | "dedup_window"
    | null;
};

function isUniqueViolation(err: unknown, constraint?: string): boolean {
  if (!err || typeof err !== "object") return false;
  const e = err as { code?: string; constraint?: string };
  if (e.code !== "23505") return false;
  if (!constraint) return true;
  return e.constraint === constraint;
}

export function deriveDeviceType(
  userAgent: string | undefined,
  clientHint: DeviceType | undefined,
): DeviceType | null {
  if (!userAgent) {
    return clientHint ?? null;
  }
  const ua = userAgent.toLowerCase();
  if (/ipad|tablet/.test(ua)) return "tablet";
  if (/mobi|iphone|android/.test(ua)) return "mobile";
  if (/windows|macintosh|linux/.test(ua)) return "desktop";
  return clientHint ?? null;
}

export function hashIp(ip: string): string {
  return createHash("sha256").update(ip).digest("hex").slice(0, 32);
}

/**
 * Phase 3 simplification: `code` and `discount_pct` are accepted from the client
 * with shape checks only — there is no issuance table to validate against yet.
 * Phase 4 should issue codes server-side (e.g. when the guest opens ListingModal),
 * persist them, and validate redeem against that instead of trusting the client.
 */
function validateCouponFields(event: TelemetryEvent): void {
  if (event.event_type !== "coupon_redeem") return;
  if (!event.listing_id) {
    throw new AppError(
      400,
      "validation_error",
      "listing_id is required for coupon_redeem",
    );
  }
  if (!event.code || event.discount_pct === undefined) {
    throw new AppError(
      400,
      "validation_error",
      "code and discount_pct are required for coupon_redeem",
    );
  }
}

async function loadExistingResult(
  pool: Pool,
  idempotencyKey: string,
): Promise<TelemetryResult | null> {
  const { rows } = await pool.query<{
    id: string;
    ledger_entry_id: string | null;
    redemption_id: string | null;
  }>(
    `SELECT ee.id,
            le.id AS ledger_entry_id,
            r.id AS redemption_id
     FROM engagement_events ee
     LEFT JOIN ledger_entries le ON le.engagement_event_id = ee.id
     LEFT JOIN redemptions r ON r.idempotency_key = ee.idempotency_key
     WHERE ee.idempotency_key = $1
     LIMIT 1`,
    [idempotencyKey],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    status: "duplicate",
    engagement_event_id: row.id,
    ledger_entry_id: row.ledger_entry_id,
    redemption_id: row.redemption_id,
    ledger_skipped_reason: null,
  };
}

/**
 * Persist a telemetry event atomically.
 *
 * Fraud target if this ever paid real money:
 * - Spamming call_click / coupon_redeem would mint credits or burn coupons.
 * Mitigations already in place:
 * - Idempotency_key UNIQUE → retries cannot double-insert.
 * - 24h dedup per (session, listing, event_type) → drip spam earns at most one credit.
 * - pg_advisory_xact_lock around dedup+ledger → concurrent different keys cannot race.
 * - IP + session rate limits → volume abuse is throttled before the DB.
 * - tenant_listings membership check → forged tenant/listing pairs earn no ledger
 *   and cannot insert redemptions.
 * - Pricing only via priceEngagementEvent() → insert sites cannot invent amounts.
 * - Coupon UNIQUE(code) → already-redeemed codes roll back the whole txn (409).
 * - service_role server-side only → clients never write ledger/redemptions directly.
 */
export async function recordTelemetryEvent(
  pool: Pool,
  event: TelemetryEvent,
  opts: { ip: string; userAgent: string | undefined },
): Promise<TelemetryResult> {
  validateCouponFields(event);

  const existing = await loadExistingResult(pool, event.idempotency_key);
  if (existing) {
    return existing;
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const deviceType = deriveDeviceType(opts.userAgent, event.device_type);
    const coarseIpHash = hashIp(opts.ip);

    let engagementId: string;
    try {
      const inserted = await client.query<{ id: string }>(
        `INSERT INTO engagement_events (
           event_type, tenant_id, listing_id, session_id, idempotency_key,
           client_timestamp, duration_ms, device_type, coarse_ip_hash, metadata
         ) VALUES (
           $1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb
         )
         RETURNING id`,
        [
          event.event_type,
          event.tenant_id,
          event.listing_id ?? null,
          event.session_id,
          event.idempotency_key,
          event.client_timestamp ?? null,
          event.duration_ms ?? null,
          deviceType,
          coarseIpHash,
          JSON.stringify(event.metadata ?? {}),
        ],
      );
      engagementId = inserted.rows[0]!.id;
    } catch (err) {
      if (isUniqueViolation(err, "engagement_events_idempotency_key_unique")) {
        await client.query("ROLLBACK");
        const dup = await loadExistingResult(pool, event.idempotency_key);
        if (dup) return dup;
        throw err;
      }
      throw err;
    }

    const meaningful = isMeaningfulEvent(event.event_type, event.duration_ms);
    let ledgerEntryId: string | null = null;
    let ledgerSkipped: TelemetryResult["ledger_skipped_reason"] = null;
    let redemptionId: string | null = null;

    let isMember = false;
    let listingTier: string | null = null;
    if (event.listing_id) {
      const membership = await client.query<{ tier: string }>(
        `SELECT l.tier
         FROM tenant_listings tl
         INNER JOIN listings l ON l.id = tl.listing_id
         WHERE tl.tenant_id = $1 AND tl.listing_id = $2
         LIMIT 1`,
        [event.tenant_id, event.listing_id],
      );
      if (membership.rows[0]) {
        isMember = true;
        listingTier = membership.rows[0].tier;
      }
    }

    if (event.event_type === "coupon_redeem") {
      if (!event.listing_id || !isMember) {
        throw new AppError(
          422,
          "listing_not_in_tenant_shortlist",
          "Listing is not in this tenant's shortlist",
        );
      }

      try {
        const redemption = await client.query<{ id: string }>(
          `INSERT INTO redemptions (
             tenant_id, listing_id, session_id, code, discount_pct, idempotency_key
           ) VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id`,
          [
            event.tenant_id,
            event.listing_id,
            event.session_id,
            event.code,
            event.discount_pct,
            event.idempotency_key,
          ],
        );
        redemptionId = redemption.rows[0]!.id;
      } catch (err) {
        if (isUniqueViolation(err, "redemptions_code_unique")) {
          await client.query("ROLLBACK");
          throw new AppError(
            409,
            "coupon_already_redeemed",
            "Coupon code has already been redeemed",
          );
        }
        if (isUniqueViolation(err, "redemptions_idempotency_key_unique")) {
          await client.query("ROLLBACK");
          const dup = await loadExistingResult(pool, event.idempotency_key);
          if (dup) return dup;
        }
        throw err;
      }
    }

    if (!meaningful) {
      ledgerSkipped = "not_meaningful";
    } else if (!event.listing_id || !isMember) {
      ledgerSkipped = "not_member";
    } else {
      // Dedup has no natural row to SELECT … FOR UPDATE: the conflicting credit
      // may not exist yet (that is exactly the race). An advisory xact lock keyed
      // by (session, listing, event_type) serializes concurrent first-credits so
      // the second waiter re-reads after the first commits and sees the dedup hit.
      // Unlike tenant_listings membership, there is no shared parent row here.
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtext($1 || $2 || $3))`,
        [event.session_id, event.listing_id, event.event_type],
      );

      const dedup = await client.query<{ exists: boolean }>(
        `SELECT EXISTS (
           SELECT 1
           FROM engagement_events ee
           INNER JOIN ledger_entries le ON le.engagement_event_id = ee.id
           WHERE ee.session_id = $1
             AND ee.listing_id = $2
             AND ee.event_type = $3
             AND ee.id <> $4
             AND ee.created_at > now() - make_interval(hours => $5)
         ) AS exists`,
        [
          event.session_id,
          event.listing_id,
          event.event_type,
          engagementId,
          DEDUP_HOURS,
        ],
      );

      if (dedup.rows[0]?.exists) {
        ledgerSkipped = "dedup_window";
      } else {
        const tier =
          listingTier === "premium" || listingTier === "free"
            ? listingTier
            : null;
        const amountMinor = priceEngagementEvent(event.event_type, tier);
        const ledger = await client.query<{ id: string }>(
          `INSERT INTO ledger_entries (
             tenant_id, listing_id, engagement_event_id, amount_minor, currency
           ) VALUES ($1, $2, $3, $4, $5)
           RETURNING id`,
          [
            event.tenant_id,
            event.listing_id,
            engagementId,
            amountMinor,
            LEDGER_CURRENCY,
          ],
        );
        ledgerEntryId = ledger.rows[0]!.id;
      }
    }

    await client.query("COMMIT");
    return {
      status: "created",
      engagement_event_id: engagementId,
      ledger_entry_id: ledgerEntryId,
      redemption_id: redemptionId,
      ledger_skipped_reason: ledgerSkipped,
    };
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch {
      // Client may already be rolled back.
    }
    throw err;
  } finally {
    client.release();
  }
}
