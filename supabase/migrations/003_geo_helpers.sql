-- 003_geo_helpers.sql
-- Validates GeoPointSchema shape: { lat: -90..90, lng: -180..180 }

CREATE OR REPLACE FUNCTION is_valid_geo_point(p jsonb)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
  SELECT
    jsonb_typeof(p) = 'object'
    AND p ? 'lat'
    AND p ? 'lng'
    AND (p - 'lat' - 'lng') = '{}'::jsonb
    AND (p ->> 'lat')::double precision BETWEEN -90 AND 90
    AND (p ->> 'lng')::double precision BETWEEN -180 AND 180;
$$;
