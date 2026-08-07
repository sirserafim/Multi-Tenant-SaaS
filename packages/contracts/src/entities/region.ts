import { z } from "zod";

/** ISO-8601 datetime string as returned by PostgreSQL timestamptz. */
const TimestampSchema = z.string().datetime({ offset: true });

/** URL-safe slug used in public routes: /[region]/[property]. */
const SlugSchema = z
  .string()
  .min(1)
  .max(64)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Slug must be lowercase kebab-case");

export const RegionSchema = z.object({
  id: z.string().uuid(),
  slug: SlugSchema,
  name: z.string().min(1).max(128),
  country_code: z
    .string()
    .length(2)
    .regex(/^[A-Z]{2}$/, "Country code must be ISO 3166-1 alpha-2 uppercase"),
  created_at: TimestampSchema,
});

export type Region = z.infer<typeof RegionSchema>;
