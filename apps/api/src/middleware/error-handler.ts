import type { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { isAppError } from "../lib/errors.js";
import { logger } from "../lib/logger.js";

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  const requestId = req.requestId ?? "unknown";

  if (err instanceof ZodError) {
    res.status(400).json({
      error_code: "validation_error",
      message: "Invalid request body",
      request_id: requestId,
      issues: err.issues.map((i) => ({
        path: i.path.join("."),
        code: i.code,
      })),
    });
    return;
  }

  if (isAppError(err)) {
    if (err.statusCode >= 500) {
      logger.error("app_error", {
        request_id: requestId,
        error_code: err.errorCode,
        message: err.message,
      });
    }
    res.status(err.statusCode).json({
      error_code: err.errorCode,
      message: err.message,
      request_id: requestId,
      ...(err.details !== undefined ? { details: err.details } : {}),
    });
    return;
  }

  logger.error("unhandled_error", {
    request_id: requestId,
    name: err instanceof Error ? err.name : typeof err,
    // Never log stack traces to the client; keep message short for ops.
    message: err instanceof Error ? err.message : "unknown",
  });

  res.status(500).json({
    error_code: "internal_error",
    message: "Internal server error",
    request_id: requestId,
  });
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({
    error_code: "validation_error",
    message: "Not found",
    request_id: req.requestId ?? "unknown",
  });
}
