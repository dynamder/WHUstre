import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// Renders the static table that backs a course UI page's print and no-JS view.
//
// The concepts live in Gleam (site/src/courses/industrial_internet/concepts.gleam),
// so the table is generated from the same data the graph draws instead of being
// written twice. The mount page pulls the fragment in with mdbook's {{#include}}.
//
// There is deliberately no registry here: a second page is a second import.

const site = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const root = path.resolve(site, "..");
const compiled = path.join(
  site,
  "build",
  "dev",
  "javascript",
  "catalog",
  "courses",
  "industrial_internet",
);

const concepts = await import(
  pathToFileURL(path.join(compiled, "concepts.mjs")).href
);

const target = path.join(
  root,
  "courses",
  "industrial-internet",
  "src",
  "graph-table.html",
);

fs.writeFileSync(target, concepts.static_table() + "\n", "utf8");
console.log(`ui table: ${path.relative(root, target)}`);
