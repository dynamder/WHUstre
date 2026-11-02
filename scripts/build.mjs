import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assemble } from "./assemble.mjs";

// One-command build:
//   catalog.json -> gleam build -> bundle -> static tables -> mdbook -> dist/
//
// `gleam build` and the bundle step run before mdbook because a book page may
// mount a course UI bundle (graph.js) and include a table generated from the
// same Gleam data. UI bundles land in courses/<slug>/ui/dist/, never in book/.
//
// Child processes are used only here. The rest of the build (catalog, tables,
// dist assembly) is plain Node so it can be tested in isolation.

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const site = path.join(root, "site");

function run(command, cwd) {
  console.log(`$ ${command}`);
  execSync(command, { cwd, stdio: "inherit" });
}

run(`"${process.execPath}" "scripts/gen-catalog.mjs"`, root);

run("gleam build", site);
run(`"${process.execPath}" "scripts/bundle.mjs"`, site);
run(`"${process.execPath}" "scripts/gen-graph-table.mjs"`, site);

const catalog = JSON.parse(
  fs.readFileSync(path.join(root, "catalog.json"), "utf8"),
);

for (const course of catalog.courses) {
  const dir = path.join(root, "courses", course.slug);
  const summary = path.join(dir, "src", "SUMMARY.md");
  if (!fs.existsSync(summary)) continue;
  run(`mdbook build "${dir}"`, root);
}

assemble();
