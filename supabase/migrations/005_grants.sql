-- 005_grants.sql
-- Least-privilege table grants matching RLS policies (defense in depth).
-- Idempotent: REVOKE ALL, then GRANT only what each role needs.

REVOKE ALL ON TABLE
  regions,
  tenants,
  listings,
  tenant_listings,
  curation_rules,
  engagement_events,
  ledger_entries,
  redemptions
FROM anon, authenticated, service_role;

-- anon: SELECT only on catalogue tables that have anon policies.
-- No grants on curation_rules / engagement_events / ledger_entries / redemptions.
GRANT SELECT ON TABLE
  regions,
  tenants,
  listings,
  tenant_listings
TO anon;

-- authenticated: SELECT on all tables; writes only where RLS write policies exist.
GRANT SELECT ON TABLE
  regions,
  tenants,
  listings,
  tenant_listings,
  curation_rules,
  engagement_events,
  ledger_entries,
  redemptions
TO authenticated;

-- tenants: owner UPDATE only (no INSERT/DELETE policies)
GRANT UPDATE ON TABLE tenants TO authenticated;

-- tenant_listings: owner CRUD
GRANT INSERT, UPDATE, DELETE ON TABLE tenant_listings TO authenticated;

-- service_role: full access (RLS bypass in Supabase; grants still required)
GRANT ALL ON TABLE
  regions,
  tenants,
  listings,
  tenant_listings,
  curation_rules,
  engagement_events,
  ledger_entries,
  redemptions
TO service_role;
