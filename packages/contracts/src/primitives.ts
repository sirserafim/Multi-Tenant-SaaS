import { z } from "zod";

/** ISO-8601 datetime string as returned by PostgreSQL timestamptz. */
export const TimestampSchema = z.string().datetime({ offset: true });

/** URL-safe slug used in public routes: /[region]/[property]. */
export const SlugSchema = z
  .string()
  .min(1)
  .max(64)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Slug must be lowercase kebab-case");

/**
 * IANA time zone identifier shape (e.g. "Europe/Athens").
 * Regex-only — does not verify membership in the tz database.
 */
export const IanaTimeZoneSchema = z
  .string()
  .min(1)
  .max(64)
  .regex(
    /^[A-Za-z0-9_+-]+(?:\/[A-Za-z0-9_+-]+)*$/,
    "Time zone must be an IANA identifier (e.g. Europe/Athens)",
  );

/** WGS-84 geographic point — shared by regions, tenants, and listings. */
export const GeoPointSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

export type GeoPoint = z.infer<typeof GeoPointSchema>;
