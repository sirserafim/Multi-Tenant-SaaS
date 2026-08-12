-- 008_triggers_ledger.sql
-- ledger_entries is append-only — block UPDATE and DELETE at the database layer.

CREATE OR REPLACE FUNCTION prevent_ledger_entry_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entries is append-only: % is forbidden', TG_OP;
END;
$$;

DROP TRIGGER IF EXISTS ledger_entries_immutable ON ledger_entries;

CREATE TRIGGER ledger_entries_immutable
  BEFORE UPDATE OR DELETE ON ledger_entries
  FOR EACH ROW
  EXECUTE FUNCTION prevent_ledger_entry_mutation();
