import assert from "node:assert/strict";
import test from "node:test";

import { getProfile, resetProfile, saveProfile } from "../server.mjs";

test.beforeEach(() => resetProfile());

test("save reports success", () => {
  assert.deepEqual(saveProfile({ timezone: "Europe/Zurich" }), { ok: true });
});

test("profile starts in UTC", () => {
  assert.deepEqual(getProfile(), { timezone: "UTC" });
});
