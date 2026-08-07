import { z } from "zod";

/** Display tier for listings — affects prominence, not billing (v1 is free). */
export const TierSchema = z.enum(["free", "premium"]);

export type Tier = z.infer<typeof TierSchema>;
