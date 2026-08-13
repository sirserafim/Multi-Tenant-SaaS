import { z } from "zod";

/** Coarse device class for telemetry — client hint or User-Agent-derived. */
export const DeviceTypeSchema = z.enum(["mobile", "tablet", "desktop"]);

export type DeviceType = z.infer<typeof DeviceTypeSchema>;
