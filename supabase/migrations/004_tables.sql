-- 004_tables.sql
-- Core tables — column names match packages/contracts Zod schemas exactly.

-- regions (RegionSchema)
CREATE TABLE IF NOT EXISTS regions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL
    CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 128),
  country_code char(2) NOT NULL
    CHECK (country_code ~ '^[A-Z]{2}$'),
  time_zone text NOT NULL
    CHECK (time_zone ~ '^[A-Za-z0-9_+-]+(?:\/[A-Za-z0-9_+-]+)*$'),
  is_published boolean NOT NULL DEFAULT false,
  centre jsonb NOT NULL CHECK (is_valid_geo_point(centre)),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT regions_slug_unique UNIQUE (slug)
);

-- tenants (TenantSchema)
CREATE TABLE IF NOT EXISTS tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  region_id uuid NOT NULL REFERENCES regions (id) ON DELETE RESTRICT,
  property_slug text NOT NULL
    CHECK (property_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 128),
  location jsonb NOT NULL CHECK (is_valid_geo_point(location)),
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenants_region_property_slug_unique UNIQUE (region_id, property_slug)
);

-- listings (ListingSchema)
CREATE TABLE IF NOT EXISTS listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_id uuid NOT NULL REFERENCES regions (id) ON DELETE RESTRICT,
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 256),
  category listing_category NOT NULL,
  tier tier NOT NULL DEFAULT 'free',
  description text CHECK (description IS NULL OR char_length(description) <= 4000),
  phone text CHECK (phone IS NULL OR char_length(phone) <= 32),
  website_url text CHECK (website_url IS NULL OR char_length(website_url) <= 2048),
  address text CHECK (address IS NULL OR char_length(address) <= 512),
  location jsonb CHECK (location IS NULL OR is_valid_geo_point(location)),
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- tenant_listings (TenantListingSchema)
CREATE TABLE IF NOT EXISTS tenant_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES listings (id) ON DELETE RESTRICT,
  display_order integer NOT NULL CHECK (display_order >= 0),
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenant_listings_tenant_listing_unique UNIQUE (tenant_id, listing_id)
);

-- curation_rules — config-driven limits (policy change = UPDATE, not migration)
-- region_id NULL + category NULL  → global max_total default
-- region_id set + category NULL   → regional max_total override
-- region_id NULL/set + category   → per-category min_count / max_count (NULL region = global)
CREATE TABLE IF NOT EXISTS curation_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_id uuid REFERENCES regions (id) ON DELETE CASCADE,
  category listing_category,
  max_total integer CHECK (max_total IS NULL OR max_total >= 0),
  min_count integer CHECK (min_count IS NULL OR min_count >= 0),
  max_count integer CHECK (max_count IS NULL OR max_count >= 0),
  CONSTRAINT curation_rules_category_limits_check CHECK (
    (category IS NULL AND max_total IS NOT NULL AND min_count IS NULL AND max_count IS NULL)
    OR (category IS NOT NULL AND max_total IS NULL AND min_count IS NOT NULL AND max_count IS NOT NULL)
  ),
  CONSTRAINT curation_rules_scope_unique UNIQUE NULLS NOT DISTINCT (region_id, category)
);

-- engagement_events — server-written telemetry (extends TelemetryEventSchema)
CREATE TABLE IF NOT EXISTS engagement_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type engagement_event_type NOT NULL,
  tenant_id uuid NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings (id) ON DELETE SET NULL,
  session_id uuid NOT NULL,
  idempotency_key text NOT NULL CHECK (char_length(idempotency_key) BETWEEN 1 AND 128),
  client_timestamp timestamptz,
  duration_ms integer CHECK (duration_ms IS NULL OR duration_ms >= 0),
  device_type text CHECK (device_type IS NULL OR char_length(device_type) <= 64),
  coarse_ip_hash text CHECK (coarse_ip_hash IS NULL OR char_length(coarse_ip_hash) <= 128),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT engagement_events_idempotency_key_unique UNIQUE (idempotency_key)
);

-- ledger_entries (LedgerEntrySchema) — append-only
CREATE TABLE IF NOT EXISTS ledger_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  listing_id uuid NOT NULL REFERENCES listings (id) ON DELETE RESTRICT,
  engagement_event_id uuid NOT NULL REFERENCES engagement_events (id) ON DELETE RESTRICT,
  amount_minor integer NOT NULL DEFAULT 0 CHECK (amount_minor >= 0),
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ledger_entries_engagement_event_id_unique UNIQUE (engagement_event_id)
);

-- redemptions (RedemptionSchema)
CREATE TABLE IF NOT EXISTS redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
  listing_id uuid NOT NULL REFERENCES listings (id) ON DELETE RESTRICT,
  session_id uuid NOT NULL,
  code text NOT NULL CHECK (code ~ '^[A-Z0-9-]{6,32}$'),
  discount_pct integer NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
  idempotency_key text NOT NULL CHECK (char_length(idempotency_key) BETWEEN 1 AND 128),
  redeemed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT redemptions_code_unique UNIQUE (code),
  CONSTRAINT redemptions_idempotency_key_unique UNIQUE (idempotency_key)
);
