-- 009_rls.sql
-- Row Level Security — explicit policies per role.
--
-- Role summary:
--   anon            → read published public catalogue data only
--   authenticated   → tenant owner matched via tenants.user_id = auth.uid()
--   service_role    → full write access to server-owned tables (bypasses RLS in Supabase)

-- Helper: true when the current user owns the tenant row
CREATE OR REPLACE FUNCTION is_tenant_owner(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM tenants AS t
    WHERE t.id = p_tenant_id
      AND t.user_id = auth.uid()
  );
$$;

-- ── regions ──────────────────────────────────────────────────────────────────
-- anon:        SELECT is_published = true
-- tenant:      SELECT published regions + own region (even if unpublished, for dashboard)
-- service_role: all (RLS bypass)

ALTER TABLE regions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS regions_anon_select_published ON regions;
CREATE POLICY regions_anon_select_published
  ON regions
  FOR SELECT
  TO anon
  USING (is_published = true);

DROP POLICY IF EXISTS regions_tenant_select ON regions;
CREATE POLICY regions_tenant_select
  ON regions
  FOR SELECT
  TO authenticated
  USING (
    is_published = true
    OR EXISTS (
      SELECT 1 FROM tenants AS t
      WHERE t.region_id = regions.id
        AND t.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS regions_service_all ON regions;
CREATE POLICY regions_service_all
  ON regions
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── tenants ──────────────────────────────────────────────────────────────────
-- anon:        SELECT is_published = true
-- tenant:      SELECT/UPDATE own rows (all properties for auth.uid())
-- service_role: all

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenants_anon_select_published ON tenants;
CREATE POLICY tenants_anon_select_published
  ON tenants
  FOR SELECT
  TO anon
  USING (is_published = true);

DROP POLICY IF EXISTS tenants_owner_select ON tenants;
CREATE POLICY tenants_owner_select
  ON tenants
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS tenants_owner_update ON tenants;
CREATE POLICY tenants_owner_update
  ON tenants
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS tenants_service_all ON tenants;
CREATE POLICY tenants_service_all
  ON tenants
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── listings ─────────────────────────────────────────────────────────────────
-- anon:        SELECT is_published = true
-- tenant:      SELECT published listings in own region (for curation UI)
-- service_role: all

ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS listings_anon_select_published ON listings;
CREATE POLICY listings_anon_select_published
  ON listings
  FOR SELECT
  TO anon
  USING (is_published = true);

DROP POLICY IF EXISTS listings_tenant_select_region ON listings;
CREATE POLICY listings_tenant_select_region
  ON listings
  FOR SELECT
  TO authenticated
  USING (
    is_published = true
    AND EXISTS (
      SELECT 1 FROM tenants AS t
      WHERE t.user_id = auth.uid()
        AND t.region_id = listings.region_id
    )
  );

DROP POLICY IF EXISTS listings_service_all ON listings;
CREATE POLICY listings_service_all
  ON listings
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── tenant_listings ──────────────────────────────────────────────────────────
-- anon:        SELECT published shortlist on a published tenant + listing + region
-- tenant:      full CRUD on own shortlist
-- service_role: all

ALTER TABLE tenant_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_listings_anon_select_published ON tenant_listings;
CREATE POLICY tenant_listings_anon_select_published
  ON tenant_listings
  FOR SELECT
  TO anon
  USING (
    is_published = true
    AND EXISTS (
      SELECT 1 FROM tenants AS t
      WHERE t.id = tenant_listings.tenant_id
        AND t.is_published = true
        AND EXISTS (
          SELECT 1 FROM regions AS r
          WHERE r.id = t.region_id
            AND r.is_published = true
        )
    )
    AND EXISTS (
      SELECT 1 FROM listings AS l
      WHERE l.id = tenant_listings.listing_id
        AND l.is_published = true
    )
  );

DROP POLICY IF EXISTS tenant_listings_owner_select ON tenant_listings;
CREATE POLICY tenant_listings_owner_select
  ON tenant_listings
  FOR SELECT
  TO authenticated
  USING (is_tenant_owner(tenant_id));

DROP POLICY IF EXISTS tenant_listings_owner_insert ON tenant_listings;
CREATE POLICY tenant_listings_owner_insert
  ON tenant_listings
  FOR INSERT
  TO authenticated
  WITH CHECK (is_tenant_owner(tenant_id));

DROP POLICY IF EXISTS tenant_listings_owner_update ON tenant_listings;
CREATE POLICY tenant_listings_owner_update
  ON tenant_listings
  FOR UPDATE
  TO authenticated
  USING (is_tenant_owner(tenant_id))
  WITH CHECK (is_tenant_owner(tenant_id));

DROP POLICY IF EXISTS tenant_listings_owner_delete ON tenant_listings;
CREATE POLICY tenant_listings_owner_delete
  ON tenant_listings
  FOR DELETE
  TO authenticated
  USING (is_tenant_owner(tenant_id));

DROP POLICY IF EXISTS tenant_listings_service_all ON tenant_listings;
CREATE POLICY tenant_listings_service_all
  ON tenant_listings
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── curation_rules ───────────────────────────────────────────────────────────
-- anon:        no access
-- tenant:      SELECT rules for own region + global defaults
-- service_role: all (policy updates without migrations)

ALTER TABLE curation_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS curation_rules_tenant_select ON curation_rules;
CREATE POLICY curation_rules_tenant_select
  ON curation_rules
  FOR SELECT
  TO authenticated
  USING (
    region_id IS NULL
    OR EXISTS (
      SELECT 1 FROM tenants AS t
      WHERE t.user_id = auth.uid()
        AND t.region_id = curation_rules.region_id
    )
  );

DROP POLICY IF EXISTS curation_rules_service_all ON curation_rules;
CREATE POLICY curation_rules_service_all
  ON curation_rules
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── engagement_events ────────────────────────────────────────────────────────
-- anon:        no access
-- tenant:      SELECT own tenant's events only
-- service_role: INSERT + SELECT (telemetry API)

ALTER TABLE engagement_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engagement_events_tenant_select ON engagement_events;
CREATE POLICY engagement_events_tenant_select
  ON engagement_events
  FOR SELECT
  TO authenticated
  USING (is_tenant_owner(tenant_id));

DROP POLICY IF EXISTS engagement_events_service_all ON engagement_events;
CREATE POLICY engagement_events_service_all
  ON engagement_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── ledger_entries ───────────────────────────────────────────────────────────
-- anon:        no access
-- tenant:      SELECT own entries only — no INSERT/UPDATE/DELETE
-- service_role: INSERT + SELECT (append-only; mutation blocked by trigger)

ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ledger_entries_tenant_select ON ledger_entries;
CREATE POLICY ledger_entries_tenant_select
  ON ledger_entries
  FOR SELECT
  TO authenticated
  USING (is_tenant_owner(tenant_id));

DROP POLICY IF EXISTS ledger_entries_service_all ON ledger_entries;
CREATE POLICY ledger_entries_service_all
  ON ledger_entries
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── redemptions ──────────────────────────────────────────────────────────────
-- anon:        no access
-- tenant:      SELECT own redemptions only
-- service_role: INSERT + SELECT

ALTER TABLE redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS redemptions_tenant_select ON redemptions;
CREATE POLICY redemptions_tenant_select
  ON redemptions
  FOR SELECT
  TO authenticated
  USING (is_tenant_owner(tenant_id));

DROP POLICY IF EXISTS redemptions_service_all ON redemptions;
CREATE POLICY redemptions_service_all
  ON redemptions
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
