import { z } from "zod";

/** Listing vertical shown on a tenant's curated shortlist. */
export const ListingCategorySchema = z.enum([
  "food_drink",
  "activity",
  "service",
  "retail",
  "transport",
  "venue",
]);

export type ListingCategory = z.infer<typeof ListingCategorySchema>;
