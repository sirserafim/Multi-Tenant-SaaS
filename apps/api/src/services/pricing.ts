import type {
  EngagementEventType,
  Tier,
} from "@multi-tenant-saas/contracts";

/** Minimum modal dwell (ms) before a dwell counts as a meaningful event. */
export const MEANINGFUL_DWELL_MS = 6000;

const ALWAYS_MEANINGFUL = new Set<EngagementEventType>([
  "call_click",
  "directions_click",
  "coupon_redeem",
]);

/**
 * Pure pricing function — sole authority for ledger amount_minor.
 * v1 returns 0 for every event and tier; callers must never hardcode amounts.
 */
export function priceEngagementEvent(
  _eventType: EngagementEventType,
  _tier: Tier | null,
): number {
  return 0;
}

/** Whether this event should attempt a ledger credit (subject to membership + dedup). */
export function isMeaningfulEvent(
  eventType: EngagementEventType,
  durationMs: number | undefined,
): boolean {
  if (ALWAYS_MEANINGFUL.has(eventType)) {
    return true;
  }
  if (eventType === "modal_dwell") {
    return (durationMs ?? 0) >= MEANINGFUL_DWELL_MS;
  }
  return false;
}
