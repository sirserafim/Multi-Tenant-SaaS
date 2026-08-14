import { createApp } from "./app.js";
import { loadEnv } from "./config/env.js";
import { closePool, getPool } from "./db/pool.js";
import { logger } from "./lib/logger.js";

async function main(): Promise<void> {
  const env = loadEnv();
  const pool = getPool(env.DATABASE_URL);
  const app = createApp(env, pool);

  const server = app.listen(env.PORT, () => {
    logger.info("api_listening", { port: env.PORT });
  });

  let shuttingDown = false;
  const shutdown = async (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info("api_shutdown_start", { signal });

    await new Promise<void>((resolve) => {
      server.close(() => resolve());
    });
    await closePool();
    logger.info("api_shutdown_complete", { signal });
    process.exit(0);
  };

  process.on("SIGTERM", () => {
    void shutdown("SIGTERM");
  });
  process.on("SIGINT", () => {
    void shutdown("SIGINT");
  });
}

main().catch((err: unknown) => {
  logger.error("api_boot_failed", {
    message: err instanceof Error ? err.message : "unknown",
  });
  process.exit(1);
});
