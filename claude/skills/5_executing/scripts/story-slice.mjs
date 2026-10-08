#!/usr/bin/env node
// Print one story's section of a wave plan verbatim: from its `## <US-ID>`
// heading up to the next `## ` heading (fenced code blocks are skipped).
// Exits 1 when the ID has no section or more than one.
//   node story-slice.mjs <wave-plan.md> <US-ID>
import { readFileSync } from "node:fs";

const [planPath, id] = process.argv.slice(2);
if (!planPath || !id) {
  console.error("usage: node story-slice.mjs <wave-plan.md> <US-ID>");
  process.exit(2);
}

const lines = readFileSync(planPath, "utf8").split("\n");
const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const own = new RegExp(`^## ${escaped}(?::|\\s|$)`);
const starts = [];
let fence = null, end = null;
for (let i = 0; i < lines.length; i++) {
  // CommonMark: a fence closes only on the same char, at least as long, bare.
  const [, marker, info] = lines[i].match(/^ {0,3}(`{3,}|~{3,})(.*)$/) ?? [];
  if (marker && !fence) fence = marker;
  else if (marker && marker[0] === fence[0] && marker.length >= fence.length && !info.trim()) { fence = null; continue; }
  if (fence || !lines[i].startsWith("## ")) continue;
  if (own.test(lines[i])) starts.push(i);
  else if (starts.length === 1 && end === null) end = i;
}

if (starts.length !== 1) {
  console.error(`story-slice: ${id} has ${starts.length} sections in ${planPath} (need exactly 1)`);
  process.exit(1);
}
process.stdout.write(lines.slice(starts[0], end ?? lines.length).join("\n").replace(/\s*$/, "\n"));
