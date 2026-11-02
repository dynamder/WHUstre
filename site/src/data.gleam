import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some, from_result}

// The catalog is generated at build time from courses/*/meta.json and each
// book's SUMMARY.md. The facade never fetches it: it is bundled into app.js.

pub type Chapter {
  Chapter(title: String, file: String, href: String)
}

pub type Part {
  Part(title: String, kind: String, chapters: List(Chapter))
}

pub type Course {
  Course(
    slug: String,
    title: String,
    code: String,
    summary: String,
    tags: List(String),
    status: String,
    order: Int,
    maintainers: List(String),
    updated: String,
    parts: List(Part),
  )
}

pub type Site {
  Site(name: String, repo: String, branch: String)
}

pub type Catalog {
  Catalog(courses: List(Course))
}

// Decoding ---------------------------------------------------------------

pub fn decode_site(data: Dynamic) -> Result(Site, List(decode.DecodeError)) {
  decode.run(data, site_decoder())
}

pub fn decode_catalog(
  data: Dynamic,
) -> Result(Catalog, List(decode.DecodeError)) {
  decode.run(data, catalog_decoder())
}

fn site_decoder() -> decode.Decoder(Site) {
  use name <- decode.field("name", decode.string)
  use repo <- decode.field("repo", decode.string)
  use branch <- decode.field("branch", decode.string)
  decode.success(Site(name, repo, branch))
}

fn catalog_decoder() -> decode.Decoder(Catalog) {
  use courses <- decode.field("courses", decode.list(course_decoder()))
  decode.success(Catalog(courses))
}

fn course_decoder() -> decode.Decoder(Course) {
  use slug <- decode.field("slug", decode.string)
  use title <- decode.field("title", decode.string)
  use code <- decode.optional_field("code", "", decode.string)
  use summary <- decode.optional_field("summary", "", decode.string)
  use tags <- decode.optional_field("tags", [], decode.list(decode.string))
  use status <- decode.optional_field("status", "active", decode.string)
  use order <- decode.optional_field("order", 0, decode.int)
  use maintainers <- decode.optional_field(
    "maintainers",
    [],
    decode.list(decode.string),
  )
  use updated <- decode.optional_field("updated", "", decode.string)
  use parts <- decode.optional_field("parts", [], decode.list(part_decoder()))
  decode.success(Course(
    slug: slug,
    title: title,
    code: code,
    summary: summary,
    tags: tags,
    status: status,
    order: order,
    maintainers: maintainers,
    updated: updated,
    parts: parts,
  ))
}

fn part_decoder() -> decode.Decoder(Part) {
  use title <- decode.field("title", decode.string)
  use kind <- decode.field("kind", decode.string)
  use chapters <- decode.optional_field(
    "chapters",
    [],
    decode.list(chapter_decoder()),
  )
  decode.success(Part(title: title, kind: kind, chapters: chapters))
}

fn chapter_decoder() -> decode.Decoder(Chapter) {
  use title <- decode.field("title", decode.string)
  use file <- decode.field("file", decode.string)
  use href <- decode.field("href", decode.string)
  decode.success(Chapter(title: title, file: file, href: href))
}

// Queries ----------------------------------------------------------------

pub fn chapter_count(course: Course) -> Int {
  list.fold(course.parts, 0, fn(total, part) {
    total + list.length(part.chapters)
  })
}

pub fn kinds(course: Course) -> List(String) {
  course.parts
  |> list.map(fn(part) { part.kind })
  |> list.unique()
}

pub fn find_course(courses: List(Course), slug: String) -> Option(Course) {
  from_result(list.find(courses, fn(course) { course.slug == slug }))
}

pub fn visible_courses(
  courses: List(Course),
  filter: Option(String),
) -> List(Course) {
  case filter {
    None -> courses
    Some(kind) ->
      list.filter(courses, fn(course) { list.contains(kinds(course), kind) })
  }
}

pub fn default_slug(courses: List(Course)) -> String {
  case list.find(courses, fn(course) { course.status == "active" }) {
    Ok(course) -> course.slug
    Error(_) ->
      case courses {
        [first, ..] -> first.slug
        [] -> ""
      }
  }
}

pub fn kind_label(kind: String) -> String {
  case kind {
    "intro" -> "开始"
    "notes" -> "讲义"
    "map" -> "图谱"
    "cheatsheet" -> "速查"
    "exam" -> "真题"
    "appendix" -> "附录"
    _ -> kind
  }
}

pub fn status_label(status: String) -> String {
  case status {
    "active" -> "已发布"
    "planned" -> "待认领"
    _ -> status
  }
}
