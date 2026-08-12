# RLS verification

Run these checks in the Supabase SQL editor or `psql` after applying migrations
and seed data. They prove tenant isolation on sensitive tables.

Or run the full suite in one shot:

```bash
npx supabase db reset
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/scripts/run_rls_verification.sql
```

## Setup

Use the seed tenants:

| Tenant | User email | User UUID |
|--------|-----------|-----------|
| Villa Plaka | maria.plaka@example.com | `b0000000-0000-4000-8000-000000000001` |
| Kolonaki Loft | nikos.kolonaki@example.com | `b0000000-0000-4000-8000-000000000002` |

## 1. Anon can read published catalogue only

```sql
SET ROLE anon;

-- Should return Athens
SELECT slug FROM regions WHERE is_published = true;

-- No anon GRANT on ledger_entries → permission denied (defense in depth)
SELECT count(*) FROM ledger_entries;

RESET ROLE;
```

### 1a. Anon cannot see unpublished catalogue rows

Temporarily unpublish seed rows via `service_role`, query as `anon` (expect 0), then restore.

```sql
-- Flip published → unpublished
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
-- Expected: 0

SELECT count(*) AS unpublished_tenant_visible
FROM tenants
WHERE id = 'c0000000-0000-4000-8000-000000000001';
-- Expected: 0

SELECT count(*) AS unpublished_listing_visible
FROM listings
WHERE id = 'e0000000-0000-4000-8000-000000000001';
-- Expected: 0

-- Restore
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
```

### 1b. Anon cannot write tenants / listings / tenant_listings

```sql
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
-- Expected: permission denied

UPDATE tenants
SET display_name = 'hacked'
WHERE id = 'c0000000-0000-4000-8000-000000000001';
-- Expected: permission denied (or 0 rows / RLS)

DELETE FROM tenants
WHERE id = 'c0000000-0000-4000-8000-000000000001';
-- Expected: permission denied (or 0 rows / RLS)

INSERT INTO listings (
  region_id, name, category, tier, is_published
) VALUES (
  'a0000000-0000-4000-8000-000000000001',
  'Anon Listing',
  'food_drink',
  'free',
  true
);
-- Expected: permission denied

UPDATE listings
SET name = 'hacked'
WHERE id = 'e0000000-0000-4000-8000-000000000001';
-- Expected: permission denied (or 0 rows / RLS)

DELETE FROM listings
WHERE id = 'e0000000-0000-4000-8000-000000000001';
-- Expected: permission denied (or 0 rows / RLS)

INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000015',
  50,
  true
);
-- Expected: permission denied

UPDATE tenant_listings
SET display_order = 999
WHERE id = 'f0000000-0000-4000-8000-000000000001';
-- Expected: permission denied (or 0 rows / RLS)

DELETE FROM tenant_listings
WHERE id = 'f0000000-0000-4000-8000-000000000001';
-- Expected: permission denied (or 0 rows / RLS)

RESET ROLE;
```

## 2. Tenant A cannot read Tenant B's ledger (with positive control)

Setup ledger rows for **both** tenants via `service_role`, then verify isolation
and that Maria's own row is visible (guards against broken `auth.uid()` returning
NULL, which would make the negative test pass for the wrong reason).

```sql
BEGIN;

-- Setup: ledger rows for Kolonaki Loft and Villa Plaka
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

-- Negative control: Maria must NOT see Kolonaki's ledger
RESET ROLE;
SET LOCAL request.jwt.claim.sub = 'b0000000-0000-4000-8000-000000000001';
SET LOCAL role = authenticated;

SELECT count(*) AS kolonaki_visible_to_maria
FROM ledger_entries
WHERE tenant_id = 'c0000000-0000-4000-8000-000000000002';
-- Expected: 0

-- Positive control: Maria MUST see her own Villa Plaka ledger
SELECT count(*) AS villa_plaka_visible_to_maria
FROM ledger_entries
WHERE tenant_id = 'c0000000-0000-4000-8000-000000000001';
-- Expected: 1

RESET ROLE;
COMMIT;
```

## 3. Tenant cannot write ledger or redemptions

```sql
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
-- Expected: permission denied

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
-- Expected: permission denied

RESET ROLE;
```

## 4. Ledger append-only trigger

```sql
SET ROLE service_role;

UPDATE ledger_entries
SET amount_minor = 100
WHERE id = (
  SELECT le.id FROM ledger_entries AS le LIMIT 1
);
-- Expected: ERROR ledger_entries is append-only: UPDATE is forbidden

DELETE FROM ledger_entries
WHERE id = (
  SELECT le.id FROM ledger_entries AS le LIMIT 1
);
-- Expected: ERROR ledger_entries is append-only: DELETE is forbidden

RESET ROLE;
```

## 5. Curation limit trigger (pass, reorder bypass, and fail)

Villa Plaka starts with **6** shortlist rows. Athens regional `max_total` = **12**.

```sql
SET ROLE service_role;

-- PASS: 7th selection (under max_total 12)
INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000010',
  99,
  true
);

-- PASS: reorder only — must not hit limits
UPDATE tenant_listings
SET display_order = 98
WHERE tenant_id = 'c0000000-0000-4000-8000-000000000001'
  AND listing_id = 'e0000000-0000-4000-8000-000000000010';

-- After 7th (...-010 venue): food_drink 2, activity 2, venue 2, service 1.
-- Fill to max_total 12 without exceeding category caps:
-- food_drink +1 (...-003→3), venue +1 (...-009→3 at cap), retail (...-015),
-- transport (...-016), activity +1 (...-005→3).
INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000003', 101, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000009', 102, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000015', 103, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000016', 104, true),
  ('c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000005', 105, true);

-- FAIL: 13th (...-006 activity, under its own cap) exceeds max_total
INSERT INTO tenant_listings (tenant_id, listing_id, display_order, is_published)
VALUES (
  'c0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000006',
  106,
  true
);
-- Expected: ERROR curation max_total exceeded for tenant ...

RESET ROLE;
```

## Actual output (`supabase db reset` then suite)

Clean rebuild from migrations only (2026-08-12). No manual GRANTs.

```
=== Test 1: anon published catalogue ===
  slug
--------
 athens
(1 row)

ERROR:  permission denied for table ledger_entries
HINT:  Grant the required privileges to the current role with: GRANT SELECT ON public.ledger_entries TO anon;

=== Test 1a: anon cannot see unpublished rows ===
UPDATE 1
UPDATE 1
UPDATE 1

 unpublished_region_visible
----------------------------
                          0
(1 row)

 unpublished_tenant_visible
----------------------------
                          0
(1 row)

 unpublished_listing_visible
-----------------------------
                           0
(1 row)

UPDATE 1
UPDATE 1
UPDATE 1

=== Test 1b: anon cannot write tenants/listings/tenant_listings ===
ERROR:  permission denied for table tenants
HINT:  Grant the required privileges to the current role with: GRANT INSERT ON public.tenants TO anon;
ERROR:  permission denied for table tenants
HINT:  Grant the required privileges to the current role with: GRANT UPDATE ON public.tenants TO anon;
ERROR:  permission denied for table tenants
HINT:  Grant the required privileges to the current role with: GRANT DELETE ON public.tenants TO anon;
ERROR:  permission denied for table listings
HINT:  Grant the required privileges to the current role with: GRANT INSERT ON public.listings TO anon;
ERROR:  permission denied for table listings
HINT:  Grant the required privileges to the current role with: GRANT UPDATE ON public.listings TO anon;
ERROR:  permission denied for table listings
HINT:  Grant the required privileges to the current role with: GRANT DELETE ON public.listings TO anon;
ERROR:  permission denied for table tenant_listings
HINT:  Grant the required privileges to the current role with: GRANT INSERT ON public.tenant_listings TO anon;
ERROR:  permission denied for table tenant_listings
HINT:  Grant the required privileges to the current role with: GRANT UPDATE ON public.tenant_listings TO anon;
ERROR:  permission denied for table tenant_listings
HINT:  Grant the required privileges to the current role with: GRANT DELETE ON public.tenant_listings TO anon;

=== Test 2: tenant ledger isolation + positive control ===
 kolonaki_visible_to_maria
---------------------------
                         0
(1 row)

 villa_plaka_visible_to_maria
------------------------------
                            1
(1 row)

=== Test 3: tenant cannot write ledger/redemptions ===
ERROR:  permission denied for table ledger_entries
HINT:  Grant the required privileges to the current role with: GRANT INSERT ON public.ledger_entries TO authenticated;
ERROR:  permission denied for table redemptions
HINT:  Grant the required privileges to the current role with: GRANT INSERT ON public.redemptions TO authenticated;

=== Test 4: ledger append-only ===
ERROR:  ledger_entries is append-only: UPDATE is forbidden
CONTEXT:  PL/pgSQL function prevent_ledger_entry_mutation() line 3 at RAISE
ERROR:  ledger_entries is append-only: DELETE is forbidden
CONTEXT:  PL/pgSQL function prevent_ledger_entry_mutation() line 3 at RAISE

=== Test 5: curation limits (pass + reorder + fail) ===
INSERT 0 1
UPDATE 1
INSERT 0 5
ERROR:  curation max_total exceeded for tenant c0000000-0000-4000-8000-000000000001 (limit 12, current 12)
CONTEXT:  PL/pgSQL function enforce_tenant_listing_curation_limits() line 76 at RAISE
```

## Policy matrix

| Table | anon | authenticated tenant | service_role |
|-------|------|---------------------|--------------|
| `regions` | SELECT published | SELECT published + own region | ALL |
| `tenants` | SELECT published | SELECT/UPDATE own rows (all properties) | ALL |
| `listings` | SELECT published | SELECT published in own region | ALL |
| `tenant_listings` | SELECT published chain | CRUD own shortlist | ALL |
| `curation_rules` | — | SELECT global + own region | ALL |
| `engagement_events` | — | SELECT own tenant | ALL (write) |
| `ledger_entries` | — | SELECT own tenant | ALL (write; trigger blocks UPDATE/DELETE) |
| `redemptions` | — | SELECT own tenant | ALL (write) |
