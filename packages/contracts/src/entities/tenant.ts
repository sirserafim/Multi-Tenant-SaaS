import { z } from "zod";
import { SlugSchema, TimestampSchema } from "../primitives.js";

/**
 * Tenant who curates a listing shortlist for guests.
 * Public page: multi-tenant-saas.app/[region_slug]/[property_slug]
 */
export const TenantSchema = z.object({
  id: z.string().uuid(),
  region_id: z.string().uuid(),
  property_slug: SlugSchema,
  display_name: z.string().min(1).max(128),
  /** When false, anon reads are blocked by RLS even if tenant listings exist. */
  is_published: z.boolean(),
  created_at: TimestampSchema,
});

export type Tenant = z.infer<typeof TenantSchema>;
