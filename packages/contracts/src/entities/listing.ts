import { z } from "zod";
import { ListingCategorySchema } from "../enums/listing-category.js";
import { TierSchema } from "../enums/tier.js";
import { GeoPointSchema, TimestampSchema } from "../primitives.js";

/** Local business or experience listed on tenant shortlists. */
export const ListingSchema = z.object({
  id: z.string().uuid(),
  region_id: z.string().uuid(),
  name: z.string().min(1).max(256),
  category: ListingCategorySchema,
  tier: TierSchema,
  description: z.string().max(4000).nullable(),
  phone: z.string().max(32).nullable(),
  website_url: z.string().url().max(2048).nullable(),
  address: z.string().max(512).nullable(),
  location: GeoPointSchema.nullable(),
  is_published: z.boolean(),
  created_at: TimestampSchema,
});

export type Listing = z.infer<typeof ListingSchema>;
