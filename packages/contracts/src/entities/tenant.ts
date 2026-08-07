import { z } from "zod";

const TimestampSchema = z.string().datetime({ offset: true });

const SlugSchema = z
  .string()
  .min(1)
  .max(64)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Slug must be lowercase kebab-case");

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
