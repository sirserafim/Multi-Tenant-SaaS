import { z } from "zod";
import {
  CentreSchema,
  IanaTimeZoneSchema,
  SlugSchema,
  TimestampSchema,
} from "../primitives.js";

export const RegionSchema = z.object({
  id: z.string().uuid(),
  slug: SlugSchema,
  name: z.string().min(1).max(128),
  country_code: z
    .string()
    .length(2)
    .regex(/^[A-Z]{2}$/, "Country code must be ISO 3166-1 alpha-2 uppercase"),
  time_zone: IanaTimeZoneSchema,
  /** When false, anon reads of this region are blocked by RLS. */
  published: z.boolean(),
  centre: CentreSchema,
  created_at: TimestampSchema,
});

export type Region = z.infer<typeof RegionSchema>;
