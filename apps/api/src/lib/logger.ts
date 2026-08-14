export type LogFields = Record<string, unknown>;

function write(level: string, message: string, fields?: LogFields): void {
  const line = {
    level,
    message,
    time: new Date().toISOString(),
    ...fields,
  };
  // Structured JSON only — no free-form console formatting.
  process.stdout.write(`${JSON.stringify(line)}\n`);
}

export const logger = {
  info(message: string, fields?: LogFields): void {
    write("info", message, fields);
  },
  warn(message: string, fields?: LogFields): void {
    write("warn", message, fields);
  },
  error(message: string, fields?: LogFields): void {
    write("error", message, fields);
  },
};
