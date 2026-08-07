/**
 * @multi-tenant-saas/contracts — single source of truth for shared domain types.
 *
 * WHY THIS PACKAGE EXISTS
 * -----------------------
 * The web app and API must agree on every field name, enum value, and validation rule.
 * Defining types once here (as Zod schemas) and deriving TypeScript types with `z.infer`
 * eliminates drift: a schema change fails typecheck in both consumers immediately.
 *
 * WHAT BREAKS IF TYPES ARE DUPLICATED
 * ------------------------------------
 * - Silent runtime mismatches (API accepts a field the frontend never sends).
 * - Enum additions that compile in one app but 400 in the other.
 * - Refactors that update one copy and leave stale interfaces elsewhere.
 * - Impossible to guarantee telemetry payloads match ledger/redemption writes.
 *
 * NO BUILD STEP — exports TypeScript source directly. Web transpiles via
 * `transpilePackages`; API resolves via path alias. Do not add `dist/` output.
 */

export {
  ListingCategorySchema,
  type ListingCategory,
} from "./enums/listing-category.js";

export { TierSchema, type Tier } from "./enums/tier.js";

export {
  EngagementEventTypeSchema,
  type EngagementEventType,
} from "./enums/engagement-event-type.js";

export { RegionSchema, type Region } from "./entities/region.js";
export { TenantSchema, type Tenant } from "./entities/tenant.js";
export { ListingSchema, type Listing } from "./entities/listing.js";
export {
  TenantListingSchema,
  type TenantListing,
} from "./entities/tenant-listing.js";
export {
  RedemptionSchema,
  type Redemption,
} from "./entities/redemption.js";

export {
  TelemetryEventSchema,
  type TelemetryEvent,
} from "./telemetry/telemetry-event.js";
