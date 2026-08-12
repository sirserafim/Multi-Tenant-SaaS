-- run_rls_verification.sql — executable suite for RLS_VERIFICATION.md
-- Run after: npx supabase db reset
\set ON_ERROR_STOP off

\echo '=== Test 1: anon published catalogue ==='
SET ROLE anon;

-- Should return Athens
SELECT slug FROM regions WHERE is_published = true;

-- No anon GRANT on ledger_entries → permission denied (defense in depth)
SELECT count(*) AS anon_ledger_count FROM ledger_entries;

RESET ROLE;

\echo '=== Test 1a: anon cannot see unpublished rows ==='
RESET ROLE;
SET ROLE service_role;

UPDATE regions
SET is_published = false
WHERE id = 'a0000000-0000-4000-8000-000000000001';

UPDATE tenants
SET is_published = false
WHERE id = 'c0000000-0000-4000-8000-000000000001';

UPDATE listings
SET is_published = false
WHERE id = 'e0000000-0000-4000-8000-000000000001';

RESET ROLE;
SET ROLE anon;

SELECT count(*) AS unpublished_region_visible
FROM regions
WHERE id = 'a0000000-0000-4000-8000-000000000001';

SELECT count(*) AS unpublished_tenant_visible
FROM tenants
WHERE id = 'c0000000-0000-4000-8000-000000000001';

SELECT count(*) AS unpublished_listing_visible
FROM listings
WHERE id = 'e0000000-0000-4000-8000-000000000001';

RESET ROLE;
SET ROLE service_role;

UPDATE regions
SET is_published = true
WHERE id = 'a0000000-0000-4000-8000-000000000001';

UPDATE tenants
SET is_published = true
WHERE id = 'c0000000-0000-4000-8000-000000000001';

UPDATE listings
SET is_published = true
WHERE id = 'e0000000-0000-4000-8000-000000000001';

RESET ROLE;

\echo '=== Test 1b: anon cannot write tenants/listings/tenant_listings ==='
SET ROLE anon;

INSERT INTO tenants (
  user_id, region_id, property_slug, display_name, location, is_published
) VALUES (
  'b0000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000001',
  'anon-inject',
  'Anon Inject',
  '{"lat": 37.97, "lng": 23.72}'::jsonb,
  true
);

UPDATE tenants
SET display_name = 'hacked'
WHERE id = 'c0000000-0000-4000-8000-000000000001';

DELETE FROM tenants
WHERE id = 'c0000000-0000-4000-8000-000000000001';

INSERT INTO listings (
  region_id, name, category, tier, is_published
) VALUES (
  'a0000000-0000-4000-8000-000000000001',
  'Anon Listing',
  'food_drink',
  'free',
  true
);

UPDATE listings
SET name = 'hacked'
WHERE id = 'e0000000-0000-4000-8000-000000000001';

DELETE FROM listings
WHERE id = 'e0000000-0000-4000-8000-000000000001';

INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000015',
  50,
  true
);

UPDATE tenant_listings
SET display_order = 999
WHERE id = 'f0000000-0000-4000-8000-000000000001';

DELETE FROM tenant_listings
WHERE id = 'f0000000-0000-4000-8000-000000000001';

RESET ROLE;

\echo '=== Test 2: tenant ledger isolation + positive control ==='
BEGIN;

RESET ROLE;
SET ROLE service_role;

INSERT INTO engagement_events (
  id, event_type, tenant_id, listing_id, session_id, idempotency_key
) VALUES (
  '90000000-0000-4000-8000-000000000001',
  'call_click',
  'c0000000-0000-4000-8000-000000000002',
  'e0000000-0000-4000-8000-000000000003',
  '90000000-0000-4000-8000-000000000099',
  'seed-verify-kolonaki-ledger-001'
) ON CONFLICT (idempotency_key) DO NOTHING;

INSERT INTO ledger_entries (
  id, tenant_id, listing_id, engagement_event_id, amount_minor, currency
) VALUES (
  '90000000-0000-4000-8000-000000000002',
  'c0000000-0000-4000-8000-000000000002',
  'e0000000-0000-4000-8000-000000000003',
  '90000000-0000-4000-8000-000000000001',
  0,
  'EUR'
) ON CONFLICT (engagement_event_id) DO NOTHING;

INSERT INTO engagement_events (
  id, event_type, tenant_id, listing_id, session_id, idempotency_key
) VALUES (
  '90000000-0000-4000-8000-000000000011',
  'call_click',
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000088',
  'seed-verify-villa-plaka-ledger-001'
) ON CONFLICT (idempotency_key) DO NOTHING;

INSERT INTO ledger_entries (
  id, tenant_id, listing_id, engagement_event_id, amount_minor, currency
) VALUES (
  '90000000-0000-4000-8000-000000000012',
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000011',
  0,
  'EUR'
) ON CONFLICT (engagement_event_id) DO NOTHING;

RESET ROLE;
SET LOCAL request.jwt.claim.sub = 'b0000000-0000-4000-8000-000000000001';
SET LOCAL role = authenticated;

SELECT count(*) AS kolonaki_visible_to_maria
FROM ledger_entries
WHERE tenant_id = 'c0000000-0000-4000-8000-000000000002';

SELECT count(*) AS villa_plaka_visible_to_maria
FROM ledger_entries
WHERE tenant_id = 'c0000000-0000-4000-8000-000000000001';

RESET ROLE;
COMMIT;

\echo '=== Test 3: tenant cannot write ledger/redemptions ==='
BEGIN;
SET LOCAL request.jwt.claim.sub = 'b0000000-0000-4000-8000-000000000001';
SET LOCAL role = authenticated;

INSERT INTO ledger_entries (
  tenant_id, listing_id, engagement_event_id, amount_minor, currency
) VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000002',
  '90000000-0000-4000-8000-000000000099',
  0,
  'EUR'
);

ROLLBACK;

BEGIN;
SET LOCAL request.jwt.claim.sub = 'b0000000-0000-4000-8000-000000000001';
SET LOCAL role = authenticated;

INSERT INTO redemptions (
  tenant_id, listing_id, session_id, code, discount_pct, idempotency_key
) VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000001',
  gen_random_uuid(),
  'TEST-CODE-001',
  10,
  'tenant-write-attempt-001'
);

ROLLBACK;

\echo '=== Test 4: ledger append-only ==='
SET ROLE service_role;

UPDATE ledger_entries
SET amount_minor = 100
WHERE id = (
  SELECT le.id FROM ledger_entries AS le LIMIT 1
);

DELETE FROM ledger_entries
WHERE id = (
  SELECT le.id FROM ledger_entries AS le LIMIT 1
);

RESET ROLE;

\echo '=== Test 5: curation limits (pass + reorder + fail) ==='
SET ROLE service_role;

INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000010',
  99,
  true
);

UPDATE tenant_listings
SET display_order = 98
WHERE tenant_id = 'c0000000-0000-4000-8000-000000000001'
  AND listing_id = 'e0000000-0000-4000-8000-000000000010';

-- Fill to max_total 12 without exceeding any category max_count:
-- food_drink +1 (...-003→3), venue +1 (...-009→3 at cap), retail (...-015),
-- transport (...-016), activity +1 (...-005→3). Result: 7+5=12.
INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000003', 101, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000009', 102, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000015', 103, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000016', 104, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000005', 105, true);

-- 13th: activity (...-006) still under category cap (3→4) → must hit max_total
INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000006',
  106,
  true
);

RESET ROLE;

\echo '=== Done ==='
