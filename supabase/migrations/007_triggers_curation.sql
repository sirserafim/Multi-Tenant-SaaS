-- 007_triggers_curation.sql
-- Enforces tenant_listings limits from curation_rules.

CREATE OR REPLACE FUNCTION enforce_tenant_listing_curation_limits()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_region_id uuid;
  v_category listing_category;
  v_max_total integer;
  v_min_count integer;
  v_max_count integer;
  v_total_count integer;
  v_category_count integer;
BEGIN
  /*
   * (c) Reorders must skip the check.
   * display_order-only UPDATEs do not change membership; re-running limits would
   * block harmless reordering and create false positives under concurrent edits.
   */
  IF TG_OP = 'UPDATE'
    AND NEW.tenant_id = OLD.tenant_id
    AND NEW.listing_id = OLD.listing_id
  THEN
    RETURN NEW;
  END IF;

  /*
   * (a) Naive COUNT(*) without a row lock is broken under concurrency.
   * Two transactions can both read count = N-1, both pass the limit check, and
   * both INSERT — ending at N+1 selections. The check and the insert are not
   * atomic unless the counted rows are locked.
   *
   * (b) SELECT ... FOR UPDATE on the tenant row beats advisory locks here because:
   * - It serializes all curation mutations for one tenant through one well-known row.
   * - It needs no custom lock-key scheme and releases automatically on commit/rollback.
   * - Advisory locks are easier to leak or double-acquire across code paths.
   */
  SELECT t.region_id
  INTO v_region_id
  FROM tenants AS t
  WHERE t.id = NEW.tenant_id
  FOR UPDATE;

  IF v_region_id IS NULL THEN
    RAISE EXCEPTION 'tenant % not found', NEW.tenant_id;
  END IF;

  SELECT l.category
  INTO v_category
  FROM listings AS l
  WHERE l.id = NEW.listing_id;

  IF v_category IS NULL THEN
    RAISE EXCEPTION 'listing % not found', NEW.listing_id;
  END IF;

  -- max_total: regional override, then global default
  SELECT cr.max_total
  INTO v_max_total
  FROM curation_rules AS cr
  WHERE cr.region_id = v_region_id
    AND cr.category IS NULL;

  IF v_max_total IS NULL THEN
    SELECT cr.max_total
    INTO v_max_total
    FROM curation_rules AS cr
    WHERE cr.region_id IS NULL
      AND cr.category IS NULL;
  END IF;

  IF v_max_total IS NOT NULL THEN
    SELECT count(*)
    INTO v_total_count
    FROM tenant_listings AS tl
    WHERE tl.tenant_id = NEW.tenant_id
      AND tl.id <> NEW.id;

    IF v_total_count >= v_max_total THEN
      RAISE EXCEPTION
        'curation max_total exceeded for tenant % (limit %, current %)',
        NEW.tenant_id, v_max_total, v_total_count;
    END IF;
  END IF;

  -- per-category max_count: regional override, then global default
  SELECT cr.min_count, cr.max_count
  INTO v_min_count, v_max_count
  FROM curation_rules AS cr
  WHERE cr.region_id = v_region_id
    AND cr.category = v_category;

  IF v_max_count IS NULL AND v_min_count IS NULL THEN
    SELECT cr.min_count, cr.max_count
    INTO v_min_count, v_max_count
    FROM curation_rules AS cr
    WHERE cr.region_id IS NULL
      AND cr.category = v_category;
  END IF;

  IF v_max_count IS NOT NULL THEN
    SELECT count(*)
    INTO v_category_count
    FROM tenant_listings AS tl
    INNER JOIN listings AS l ON l.id = tl.listing_id
    WHERE tl.tenant_id = NEW.tenant_id
      AND l.category = v_category
      AND tl.id <> NEW.id;

    IF v_category_count >= v_max_count THEN
      RAISE EXCEPTION
        'curation max_count exceeded for tenant % category % (limit %, current %)',
        NEW.tenant_id, v_category, v_max_count, v_category_count;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tenant_listings_curation_limits ON tenant_listings;

CREATE TRIGGER tenant_listings_curation_limits
  BEFORE INSERT OR UPDATE ON tenant_listings
  FOR EACH ROW
  EXECUTE FUNCTION enforce_tenant_listing_curation_limits();
