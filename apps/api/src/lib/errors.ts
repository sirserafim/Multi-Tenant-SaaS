export type ErrorCode =
  | "validation_error"
  | "coupon_already_redeemed"
  | "listing_not_in_tenant_shortlist"
  | "rate_limited"
  | "internal_error";

export class AppError extends Error {
  readonly statusCode: number;
  readonly errorCode: ErrorCode;
  readonly details?: unknown;

  constructor(
    statusCode: number,
    errorCode: ErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.details = details;
  }
}

export function isAppError(err: unknown): err is AppError {
  return err instanceof AppError;
}
