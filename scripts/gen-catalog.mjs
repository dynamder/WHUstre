import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Builds catalog.json from courses/*/meta.json plus each book's SUMMARY.md.
// The facade bundles this file, so the catalog costs zero requests at runtime.

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const coursesDir = path.join(root, "courses");
const output = path.join(root, "catalog.json");

const PART_KINDS = {
  开始: "intro",
  讲义: "notes",
  图谱: "map",
  速查: "cheatsheet",
  真题: "exam",
  练习: "exam",
  附录: "appendix",
};

function kind_of(title) {
  if (PART_KINDS[title]) return PART_KINDS[title];
  const ascii = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  return ascii || "other";
}

function read_summary(file, slug) {
  const text = fs.readFileSync(file, "utf8");
  const parts = [];
  let current = null;

  for (const line of text.split(/\r?\n/)) {
    const part = /^#\s+(.+?)\s*$/.exec(line);
    if (part) {
      const title = part[1].trim();
      if (title.toLowerCase() === "summary") continue;
      current = { title, kind: kind_of(title), chapters: [] };
      parts.push(current);
      continue;
    }

    const chapter = /^\s*[-*]\s+\[([^\]]+)\]\(([^)]+)\)/.exec(line);
    if (!chapter) continue;

    const target = chapter[2].trim();
    if (/^[a-z]+:/i.test(target)) continue; // external link
    if (!target.split("#")[0].endsWith(".md")) continue;

    if (!current) {
      current = { title: "开始", kind: "intro", chapters: [] };
      parts.push(current);
    }

    const file = target.split("#")[0].replace(/\.md$/, ".html");
    current.chapters.push({
      title: chapter[1].trim(),
      file: target.split("#")[0],
      href: `courses/${slug}/${file}`,
    });
  }

  return parts.filter((part) => part.chapters.length > 0);
}

function read_ui(meta) {
  const ui = Array.isArray(meta.ui) ? meta.ui : [];
  return ui
    .filter(
      (entry) =>
        entry &&
        typeof entry.entry === "string" &&
        typeof entry.out === "string",
    )
    .map((entry) => ({ entry: entry.entry, out: entry.out }));
}

function read_course(slug) {
  const dir = path.join(coursesDir, slug);
  const meta_file = path.join(dir, "meta.json");
  if (!fs.existsSync(meta_file)) return null;

  const meta = JSON.parse(fs.readFileSync(meta_file, "utf8"));
  const summary_file = path.join(dir, "src", "SUMMARY.md");
  const parts = fs.existsSync(summary_file)
    ? read_summary(summary_file, meta.slug ?? slug)
    : [];

  return {
    slug: meta.slug ?? slug,
    title: meta.title ?? slug,
    code: meta.code ?? "",
    summary: meta.summary ?? "",
    tags: meta.tags ?? [],
    status: meta.status ?? "planned",
    order: meta.order ?? 999,
    maintainers: meta.maintainers ?? [],
    updated: meta.updated ?? "",
    ui: read_ui(meta),
    parts,
  };
}

function main() {
  if (!fs.existsSync(coursesDir)) {
    throw new Error(`no courses directory: ${coursesDir}`);
  }

  const courses = fs
    .readdirSync(coursesDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => read_course(entry.name))
    .filter(Boolean)
    .sort((a, b) => a.order - b.order || a.title.localeCompare(b.title, "zh"));

  fs.writeFileSync(output, JSON.stringify({ courses }, null, 2) + "\n", "utf8");

  const chapters = courses.reduce(
    (total, course) =>
      total +
      course.parts.reduce((sum, part) => sum + part.chapters.length, 0),
    0,
  );
  console.log(
    `catalog.json: ${courses.length} courses, ${chapters} chapters -> ${path.relative(root, output)}`,
  );
}

main();
