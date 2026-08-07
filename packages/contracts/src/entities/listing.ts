import { z } from "zod";
import { ListingCategorySchema } from "../enums/listing-category.js";
import { TierSchema } from "../enums/tier.js";

const TimestampSchema = z.string().datetime({ offset: true });

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
  latitude: z.number().min(-90).max(90).nullable(),
  longitude: z.number().min(-180).max(180).nullable(),
  /** Coupon code shown to guests; scanned at checkout via redemption QR. */
  coupon_code: z.string().min(1).max(64).nullable(),
  is_published: z.boolean(),
  created_at: TimestampSchema,
});

export type Listing = z.infer<typeof ListingSchema>;
