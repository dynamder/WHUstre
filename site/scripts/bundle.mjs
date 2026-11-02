import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";

// Bundles the facade, then every course-defined UI entry.
//
//   facade   -> site/public/app.js
//   course   -> courses/<slug>/ui/dist/<out>
//
// Course UI is never written into book/: mdbook clears that directory on every
// build. `scripts/gen-catalog.mjs` must have produced catalog.json, and
// `gleam build` must have run first: entries import the compiled modules.

const site = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const root = path.resolve(site, "..");

async function bundle(entryPoint, outfile, format, options = {}) {
  fs.mkdirSync(path.dirname(outfile), { recursive: true });
  await build({
    entryPoints: [entryPoint],
    bundle: true,
    format,
    target: ["es2020"],
    outfile,
    sourcemap: false,
    logLevel: "info",
    ...options,
  });
}

await bundle(
  path.join(site, "scripts", "entry.js"),
  path.join(site, "public", "app.js"),
  "iife",
);

const catalog_file = path.join(root, "catalog.json");
if (!fs.existsSync(catalog_file)) {
  throw new Error("catalog.json missing: run scripts/gen-catalog.mjs first");
}

const catalog = JSON.parse(fs.readFileSync(catalog_file, "utf8"));
let count = 0;

for (const course of catalog.courses) {
  for (const ui of course.ui ?? []) {
    // Course UI carries a graph library; minify it so only the page that
    // mounts it pays for the download.
    await bundle(
      path.join(site, "scripts", "entries", `${ui.entry}.js`),
      path.join(root, "courses", course.slug, "ui", "dist", ui.out),
      "esm",
      { minify: true },
    );
    count += 1;
  }
}

console.log(`bundle: facade + ${count} course UI entr${count === 1 ? "y" : "ies"}`);
