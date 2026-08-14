import type { NextFunction, Request, Response } from "express";
import type { Env } from "../config/env.js";
import { AppError } from "../lib/errors.js";

type Bucket = { count: number; resetAt: number };

function take(store: Map<string, Bucket>, key: string, max: number, windowMs: number): boolean {
  const now = Date.now();
  const current = store.get(key);
  if (!current || current.resetAt <= now) {
    store.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (current.count >= max) {
    return false;
  }
  current.count += 1;
  return true;
}

/**
 * In-memory fixed-window rate limits.
 * Sufficient for a single API process; replace with Redis when horizontally scaled.
 */
export function createRateLimiters(env: Env) {
  const ipBuckets = new Map<string, Bucket>();
  const sessionBuckets = new Map<string, Bucket>();

  function ipRateLimit(req: Request, _res: Response, next: NextFunction): void {
    const ip = req.ip || req.socket.remoteAddress || "unknown";
    if (
      !take(
        ipBuckets,
        ip,
        env.RATE_LIMIT_IP_MAX,
        env.RATE_LIMIT_IP_WINDOW_MS,
      )
    ) {
      next(
        new AppError(429, "rate_limited", "Too many requests from this IP"),
      );
      return;
    }
    next();
  }

  function sessionRateLimit(
    req: Request,
    _res: Response,
    next: NextFunction,
  ): void {
    const sessionId =
      typeof req.body?.session_id === "string" ? req.body.session_id : null;
    if (!sessionId) {
      next();
      return;
    }
    if (
      !take(
        sessionBuckets,
        sessionId,
        env.RATE_LIMIT_SESSION_MAX,
        env.RATE_LIMIT_SESSION_WINDOW_MS,
      )
    ) {
      next(
        new AppError(
          429,
          "rate_limited",
          "Too many requests from this session",
        ),
      );
      return;
    }
    next();
  }

  return { ipRateLimit, sessionRateLimit };
}
