import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pathToFileURL } from "node:url";

// Assembles dist/ from the facade, every built book and every course UI bundle.
// Pure file operations: no subprocesses, so it can run anywhere Node runs.

export function assemble() {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const dist = path.join(root, "dist");
  const public_dir = path.join(root, "site", "public");

  fs.rmSync(dist, { recursive: true, force: true });
  fs.mkdirSync(dist, { recursive: true });
  fs.cpSync(public_dir, dist, { recursive: true });
  fs.writeFileSync(path.join(dist, ".nojekyll"), "");

  const catalog_file = path.join(root, "catalog.json");
  if (!fs.existsSync(catalog_file)) {
    throw new Error("catalog.json missing: run scripts/gen-catalog.mjs first");
  }

  const catalog = JSON.parse(fs.readFileSync(catalog_file, "utf8"));
  let books = 0;
  let ui_bundles = 0;

  for (const course of catalog.courses) {
    const book = path.join(root, "courses", course.slug, "book");
    if (!fs.existsSync(path.join(book, "index.html"))) continue;
    const target = path.join(dist, "courses", course.slug);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.cpSync(book, target, { recursive: true });
    books += 1;

    // UI bundles sit next to the book rather than inside it, so mdbook can
    // rebuild book/ without dropping them. The book pages link them relatively:
    // courses/<slug>/graph.html -> courses/<slug>/ui/graph.js
    const ui = path.join(root, "courses", course.slug, "ui", "dist");
    if (fs.existsSync(ui)) {
      fs.cpSync(ui, path.join(target, "ui"), { recursive: true });
      ui_bundles += 1;
    }
  }

  console.log(
    `dist/: facade + ${books} book(s) + ${ui_bundles} ui bundle(s) -> ${path.relative(root, dist)}`,
  );
  return dist;
}

const is_cli =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (is_cli) {
  assemble();
}
