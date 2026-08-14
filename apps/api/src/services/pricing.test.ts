import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  MEANINGFUL_DWELL_MS,
  isMeaningfulEvent,
  priceEngagementEvent,
} from "./pricing.js";

describe("priceEngagementEvent", () => {
  it("returns 0 for every event type and tier", () => {
    const events = [
      "card_open",
      "modal_dwell",
      "call_click",
      "directions_click",
      "website_click",
      "coupon_redeem",
      "hover_desktop",
    ] as const;
    for (const event of events) {
      assert.equal(priceEngagementEvent(event, "free"), 0);
      assert.equal(priceEngagementEvent(event, "premium"), 0);
      assert.equal(priceEngagementEvent(event, null), 0);
    }
  });
});

describe("isMeaningfulEvent", () => {
  it("treats intent clicks and coupon_redeem as meaningful", () => {
    assert.equal(isMeaningfulEvent("call_click", undefined), true);
    assert.equal(isMeaningfulEvent("directions_click", undefined), true);
    assert.equal(isMeaningfulEvent("coupon_redeem", undefined), true);
  });

  it("requires dwell >= 6000ms for modal_dwell", () => {
    assert.equal(isMeaningfulEvent("modal_dwell", MEANINGFUL_DWELL_MS - 1), false);
    assert.equal(isMeaningfulEvent("modal_dwell", MEANINGFUL_DWELL_MS), true);
    assert.equal(isMeaningfulEvent("modal_dwell", undefined), false);
  });

  it("ignores non-intent browse events", () => {
    assert.equal(isMeaningfulEvent("card_open", undefined), false);
    assert.equal(isMeaningfulEvent("website_click", undefined), false);
    assert.equal(isMeaningfulEvent("hover_desktop", undefined), false);
  });
});
