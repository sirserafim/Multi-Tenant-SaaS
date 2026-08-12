-- 006_indexes.sql
-- Performance indexes required by Phase 2 spec.

CREATE INDEX IF NOT EXISTS listings_region_category_published_idx
  ON listings (region_id, category, is_published);

CREATE INDEX IF NOT EXISTS tenant_listings_tenant_display_order_idx
  ON tenant_listings (tenant_id, display_order);

CREATE INDEX IF NOT EXISTS engagement_events_tenant_created_at_idx
  ON engagement_events (tenant_id, created_at);

CREATE INDEX IF NOT EXISTS redemptions_tenant_redeemed_at_idx
  ON redemptions (tenant_id, redeemed_at);

-- Supporting indexes for RLS join paths
CREATE INDEX IF NOT EXISTS tenants_user_id_idx ON tenants (user_id);
CREATE INDEX IF NOT EXISTS tenants_region_id_idx ON tenants (region_id);
CREATE INDEX IF NOT EXISTS listings_region_id_idx ON listings (region_id);
CREATE INDEX IF NOT EXISTS tenant_listings_listing_id_idx ON tenant_listings (listing_id);
CREATE INDEX IF NOT EXISTS ledger_entries_tenant_id_idx ON ledger_entries (tenant_id);
CREATE INDEX IF NOT EXISTS redemptions_tenant_id_idx ON redemptions (tenant_id);
