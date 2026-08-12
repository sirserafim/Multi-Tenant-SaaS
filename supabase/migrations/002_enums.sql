-- 002_enums.sql
-- Enum types aligned with packages/contracts Zod enums.

DO $$
BEGIN
  CREATE TYPE listing_category AS ENUM (
    'food_drink',
    'activity',
    'service',
    'retail',
    'transport',
    'venue'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE tier AS ENUM ('free', 'premium');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE engagement_event_type AS ENUM (
    'card_open',
    'modal_dwell',
    'call_click',
    'directions_click',
    'website_click',
    'coupon_redeem',
    'hover_desktop'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
