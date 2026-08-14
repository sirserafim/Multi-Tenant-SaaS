import cors from "cors";
import express from "express";
import helmet from "helmet";
import type { Pool } from "pg";
import type { Env } from "./config/env.js";
import { corsAllowlist } from "./config/env.js";
import {
  errorHandler,
  notFoundHandler,
} from "./middleware/error-handler.js";
import { createRateLimiters } from "./middleware/rate-limit.js";
import { requestIdMiddleware } from "./middleware/request-id.js";
import { createHealthRouter } from "./routes/health.js";
import { createTelemetryRouter } from "./routes/telemetry.js";

export function createApp(env: Env, pool: Pool): express.Application {
  const app = express();
  const allowlist = corsAllowlist(env);
  const { ipRateLimit, sessionRateLimit } = createRateLimiters(env);

  app.set("trust proxy", 1);
  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        // Non-browser clients (curl, server-to-server) send no Origin.
        if (!origin) {
          callback(null, true);
          return;
        }
        if (allowlist.includes(origin)) {
          callback(null, true);
          return;
        }
        callback(null, false);
      },
      credentials: true,
    }),
  );
  app.use(express.json({ limit: env.JSON_BODY_LIMIT }));
  app.use(requestIdMiddleware);
  app.use(ipRateLimit);

  app.use("/health", createHealthRouter());
  app.use("/api/telemetry", sessionRateLimit, createTelemetryRouter(pool));

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
