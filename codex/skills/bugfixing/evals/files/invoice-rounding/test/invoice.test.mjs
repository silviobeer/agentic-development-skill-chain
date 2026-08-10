import assert from "node:assert/strict";
import test from "node:test";

import { totalCHF } from "../src/invoice.mjs";

test("invoice total is numeric", () => {
  assert.equal(typeof totalCHF([0.05]), "number");
});

test("empty invoice totals zero", () => {
  assert.equal(totalCHF([]), 0);
});
