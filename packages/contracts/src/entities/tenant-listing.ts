import { z } from "zod";

const TimestampSchema = z.string().datetime({ offset: true });

/** Join row linking a tenant's curated shortlist to a listing, with display order. */
export const TenantListingSchema = z.object({
  id: z.string().uuid(),
  tenant_id: z.string().uuid(),
  listing_id: z.string().uuid(),
  display_order: z.number().int().min(0),
  is_published: z.boolean(),
  created_at: TimestampSchema,
});

export type TenantListing = z.infer<typeof TenantListingSchema>;
