import { z } from "zod";

const EnvSchema = z.object({
  PORT: z.coerce.number().int().positive().default(4000),
  CORS_ORIGIN: z.string().min(1),
  DATABASE_URL: z.string().min(1),
  JSON_BODY_LIMIT: z.string().default("32kb"),
  RATE_LIMIT_IP_MAX: z.coerce.number().int().positive().default(120),
  RATE_LIMIT_IP_WINDOW_MS: z.coerce.number().int().positive().default(60_000),
  RATE_LIMIT_SESSION_MAX: z.coerce.number().int().positive().default(60),
  RATE_LIMIT_SESSION_WINDOW_MS: z.coerce
    .number()
    .int()
    .positive()
    .default(60_000),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

export type Env = z.infer<typeof EnvSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = EnvSchema.safeParse(source);
  if (!parsed.success) {
    const details = parsed.error.issues
      .map((i) => `${i.path.join(".")}: ${i.message}`)
      .join("; ");
    throw new Error(`Invalid environment: ${details}`);
  }
  return parsed.data;
}

export function corsAllowlist(env: Env): string[] {
  return env.CORS_ORIGIN.split(",")
    .map((o) => o.trim())
    .filter(Boolean);
}
