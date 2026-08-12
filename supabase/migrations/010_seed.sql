-- 010_seed.sql
-- Realistic Athens demo data: 1 region, 2 tenants (with auth.users), ~15 listings.
-- Idempotent via ON CONFLICT / fixed UUIDs.

-- ── auth users (tenant owners) ───────────────────────────────────────────────
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    'b0000000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    'maria.plaka@example.com',
    crypt('seed-password-change-me', gen_salt('bf')),
    now(), now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0000000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    'nikos.kolonaki@example.com',
    crypt('seed-password-change-me', gen_salt('bf')),
    now(), now(), now(), '', '', '', ''
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id,
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
VALUES
  (
    'b0000000-0000-4000-8000-000000000011',
    'b0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    jsonb_build_object(
      'sub', 'b0000000-0000-4000-8000-000000000001',
      'email', 'maria.plaka@example.com'
    ),
    'email',
    now(), now(), now()
  ),
  (
    'b0000000-0000-4000-8000-000000000022',
    'b0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000002',
    jsonb_build_object(
      'sub', 'b0000000-0000-4000-8000-000000000002',
      'email', 'nikos.kolonaki@example.com'
    ),
    'email',
    now(), now(), now()
  )
ON CONFLICT (provider_id, provider) DO NOTHING;

-- ── region ───────────────────────────────────────────────────────────────────
INSERT INTO regions (
  id, slug, name, country_code, time_zone, is_published, centre, created_at
)
VALUES (
  'a0000000-0000-4000-8000-000000000001',
  'athens',
  'Athens',
  'GR',
  'Europe/Athens',
  true,
  '{"lat": 37.9838, "lng": 23.7275}'::jsonb,
  now()
)
ON CONFLICT (id) DO NOTHING;

-- ── curation rules (global defaults + Athens override) ───────────────────────
INSERT INTO curation_rules (id, region_id, category, max_total, min_count, max_count)
VALUES
  ('d0000000-0000-4000-8000-000000000001', NULL, NULL, 10, NULL, NULL),
  ('d0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', NULL, 12, NULL, NULL),
  ('d0000000-0000-4000-8000-000000000010', NULL, 'food_drink', NULL, 1, 4),
  ('d0000000-0000-4000-8000-000000000011', NULL, 'activity', NULL, 1, 4),
  ('d0000000-0000-4000-8000-000000000012', NULL, 'service', NULL, 0, 2),
  ('d0000000-0000-4000-8000-000000000013', NULL, 'retail', NULL, 0, 2),
  ('d0000000-0000-4000-8000-000000000014', NULL, 'venue', NULL, 0, 3),
  ('d0000000-0000-4000-8000-000000000015', NULL, 'transport', NULL, 0, 2)
ON CONFLICT (region_id, category) DO NOTHING;

-- ── tenants ────────────────────────────────────────────────────────────────────
INSERT INTO tenants (
  id, user_id, region_id, property_slug, display_name, location, is_published, created_at
)
VALUES
  (
    'c0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'villa-plaka',
    'Villa Plaka',
    '{"lat": 37.9715, "lng": 23.7267}'::jsonb,
    true,
    now()
  ),
  (
    'c0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000002',
    'a0000000-0000-4000-8000-000000000001',
    'kolonaki-loft',
    'Kolonaki Loft',
    '{"lat": 37.9778, "lng": 23.7418}'::jsonb,
    true,
    now()
  )
ON CONFLICT (id) DO NOTHING;

-- ── listings (~15 across all categories) ───────────────────────────────────────
INSERT INTO listings (
  id, region_id, name, category, tier, description, phone, website_url, address,
  location, is_published, created_at
)
VALUES
  -- food_drink
  (
    'e0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'Ta Karamanlidika tou Fani',
    'food_drink', 'premium',
    'Meze and cured meats in a restored market deli near Athinas Street.',
    '+30 210 325 0184',
    'https://karamanlidika.gr',
    'Sokratous 1, Athens 105 51',
    '{"lat": 37.9795, "lng": 23.7267}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000002',
    'a0000000-0000-4000-8000-000000000001',
    'O Kostas Souvlaki',
    'food_drink', 'free',
    'Tiny Plaka institution — order the koulouri souvlaki before the lunch rush.',
    '+30 210 322 8500',
    NULL,
    'Pentelis 5, Athens 105 58',
    '{"lat": 37.9719, "lng": 23.7303}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000003',
    'a0000000-0000-4000-8000-000000000001',
    'Dionysos Zonar''s',
    'food_drink', 'premium',
    'Fine dining with Acropolis views — ideal for a special evening.',
    '+30 210 922 1040',
    'https://dionysosrestaurants.gr',
    'Rovertou Galli 43, Athens 117 42',
    '{"lat": 37.9695, "lng": 23.7284}'::jsonb,
    true, now()
  ),
  -- activity
  (
    'e0000000-0000-4000-8000-000000000004',
    'a0000000-0000-4000-8000-000000000001',
    'Athens Riviera Sunset Cruise',
    'activity', 'premium',
    'Small-group catamaran from Alimos Marina with swim stop at Tridentis Bay.',
    '+30 694 812 3456',
    'https://athensrivieracruise.example.com',
    'Alimos Marina, Athens',
    '{"lat": 37.9142, "lng": 23.7094}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000005',
    'a0000000-0000-4000-8000-000000000001',
    'Saronic Day Sail',
    'activity', 'free',
    'Shared sailing to Aegina with onboard lunch and snorkelling gear included.',
    '+30 210 428 9900',
    NULL,
    'Marina Zeas, Piraeus',
    '{"lat": 37.9365, "lng": 23.6478}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000006',
    'a0000000-0000-4000-8000-000000000001',
    'Parnitha National Park Hike',
    'activity', 'free',
    'Guided 6 km loop from Bafi Refuge through pine forest with city views.',
    '+30 210 246 0902',
    NULL,
    'Acharnes, Mount Parnitha',
    '{"lat": 38.1612, "lng": 23.7189}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000007',
    'a0000000-0000-4000-8000-000000000001',
    'Mount Hymettus Ridge Walk',
    'activity', 'free',
    'Morning guided walk to Evzonon peak — wild thyme and panoramic Athens views.',
    '+30 697 123 4567',
    NULL,
    'Kaisariani Gate, Hymettus',
    '{"lat": 37.9634, "lng": 23.7891}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000011',
    'a0000000-0000-4000-8000-000000000001',
    'Acropolis Skip-the-Line Tour',
    'activity', 'premium',
    'Licensed archaeologist guide, 3 hours, small groups, includes Parthenon.',
    '+30 210 922 4030',
    'https://acropolistours.example.com',
    'Meeting point: Acropolis Metro exit',
    '{"lat": 37.9687, "lng": 23.7281}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000012',
    'a0000000-0000-4000-8000-000000000001',
    'Athens Street Food Walk',
    'activity', 'free',
    'Evening tasting tour through Psiri and Monastiraki — 6 stops, 4 hours.',
    '+30 694 555 0198',
    NULL,
    'Monastiraki Square, Athens',
    '{"lat": 37.9764, "lng": 23.7256}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000013',
    'a0000000-0000-4000-8000-000000000001',
    'Cape Sounion Temple of Poseidon',
    'activity', 'premium',
    'Half-day coach trip with sunset at the temple cliffs.',
    '+30 210 882 9981',
    'https://souniontours.example.com',
    'Pickup: Syntagma Square',
    '{"lat": 37.9755, "lng": 23.7348}'::jsonb,
    true, now()
  ),
  -- venue
  (
    'e0000000-0000-4000-8000-000000000008',
    'a0000000-0000-4000-8000-000000000001',
    'Baba Au Rum',
    'venue', 'premium',
    'World-class cocktail bar on Stoa Kouvelou — expect a wait, worth it.',
    '+30 210 323 2117',
    'https://babaaurum.gr',
    'Stoa Kouvelou 6, Athens 105 60',
    '{"lat": 37.9772, "lng": 23.7289}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000009',
    'a0000000-0000-4000-8000-000000000001',
    'The Clumsies',
    'venue', 'premium',
    'Award-winning bar in a restored townhouse — creative cocktails and garden seating.',
    '+30 210 361 0163',
    'https://theclumsies.gr',
    'Praxitelous 30, Athens 105 61',
    '{"lat": 37.9788, "lng": 23.7315}'::jsonb,
    true, now()
  ),
  (
    'e0000000-0000-4000-8000-000000000010',
    'a0000000-0000-4000-8000-000000000001',
    'Six D.O.G.S',
    'venue', 'free',
    'Courtyard bar and cultural space — live music most summer evenings.',
    '+30 210 321 0515',
    'https://sixdogs.gr',
    'Avramiotou 6-8, Athens 105 51',
    '{"lat": 37.9781, "lng": 23.7276}'::jsonb,
    true, now()
  ),
  -- service
  (
    'e0000000-0000-4000-8000-000000000014',
    'a0000000-0000-4000-8000-000000000001',
    'Welcome Pickups Athens',
    'service', 'premium',
    'Pre-booked airport transfers with flight tracking and meet-and-greet.',
    '+30 210 300 5000',
    'https://welcomepickups.com/athens',
    'Athens International Airport',
    '{"lat": 37.9364, "lng": 23.9445}'::jsonb,
    true, now()
  ),
  -- retail
  (
    'e0000000-0000-4000-8000-000000000015',
    'a0000000-0000-4000-8000-000000000001',
    'Monastiraki Artisan Market',
    'retail', 'free',
    'Curated local ceramics, textiles, and olive-oil products steps from the metro.',
    '+30 210 321 7046',
    NULL,
    'Ifestou 2, Athens 105 55',
    '{"lat": 37.9762, "lng": 23.7259}'::jsonb,
    true, now()
  ),
  -- transport
  (
    'e0000000-0000-4000-8000-000000000016',
    'a0000000-0000-4000-8000-000000000001',
    'Beat Electric Scooter Rental',
    'transport', 'free',
    'App-based e-scooter hire — pickup hubs in Plaka and Syntagma.',
    '+30 211 999 4400',
    'https://beat.example.com',
    'Adrianou 45, Athens 105 56',
    '{"lat": 37.9736, "lng": 23.7298}'::jsonb,
    true, now()
  )
ON CONFLICT (id) DO NOTHING;

-- ── tenant shortlists ────────────────────────────────────────────────────────
INSERT INTO tenant_listings (id, tenant_id, listing_id, display_order, is_published, created_at)
VALUES
  -- Villa Plaka shortlist
  ('f0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000002', 0, true, now()),
  ('f0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 1, true, now()),
  ('f0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000011', 2, true, now()),
  ('f0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000008', 3, true, now()),
  ('f0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000004', 4, true, now()),
  ('f0000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000014', 5, true, now()),
  -- Kolonaki Loft shortlist
  ('f0000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000003', 0, true, now()),
  ('f0000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000009', 1, true, now()),
  ('f0000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000012', 2, true, now()),
  ('f0000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000006', 3, true, now()),
  ('f0000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000013', 4, true, now()),
  ('f0000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000016', 5, true, now())
ON CONFLICT (id) DO NOTHING;
