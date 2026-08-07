import { z } from "zod";

/** Listing vertical shown on a tenant's curated shortlist. */
export const ListingCategorySchema = z.enum([
  "dining",
  "boat_trip",
  "mountain_trip",
  "bar",
  "tour",
  "transport",
]);

export type ListingCategory = z.infer<typeof ListingCategorySchema>;
