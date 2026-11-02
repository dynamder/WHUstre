import courses/industrial_internet/concepts
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should

// 引用完整性与内容约束用普通测试兜住：超边指向不存在的概念、id 重复、空定义、
// 题号越界、题号漏挂、矩阵没有格子，都在这里失败，不在构建期再加一层校验。

pub fn hyperedges_reference_existing_concepts_test() {
  concepts.graph()
  |> concepts.dangling_refs()
  |> should.equal([])
}

pub fn concept_ids_are_unique_test() {
  concepts.graph()
  |> concepts.duplicate_ids()
  |> should.equal([])
}

pub fn every_concept_has_a_definition_test() {
  concepts.graph().concepts
  |> list.filter(fn(concept) { string.trim(concept.def) == "" })
  |> list.map(fn(concept) { concept.id })
  |> should.equal([])
}

pub fn every_concept_has_a_mechanism_test() {
  concepts.graph().concepts
  |> list.filter(fn(concept) { string.trim(concept.mechanism) == "" })
  |> list.map(fn(concept) { concept.id })
  |> should.equal([])
}

pub fn every_concept_links_back_to_a_page_test() {
  concepts.graph().concepts
  |> list.filter(fn(concept) { !string.ends_with(concept.chapter, ".html") })
  |> list.map(fn(concept) { concept.id })
  |> should.equal([])
}

pub fn question_refs_use_known_chapters_test() {
  concepts.graph().concepts
  |> list.flat_map(fn(concept) { concept.questions })
  |> list.filter(fn(question) {
    question.chapter < 0 || question.chapter > 6 || question.item < 1
  })
  |> should.equal([])
}

pub fn every_exercise_is_attached_test() {
  let attached = attached_exercises()
  let missing =
    all_exercises()
    |> list.filter(fn(id) { !list.contains(attached, id) })

  missing |> should.equal([])
}

pub fn no_unknown_exercises_test() {
  let expected = all_exercises()
  let unknown =
    attached_exercises()
    |> list.filter(fn(id) { !list.contains(expected, id) })

  unknown |> should.equal([])
}

// 一题可以挂在多个概念下，但同一个概念不能把同一题记两遍。
pub fn a_concept_lists_each_exercise_once_test() {
  concepts.graph().concepts
  |> list.filter(fn(concept) {
    let ids = list.map(concept.questions, concepts.question_id)
    list.length(ids) != list.length(list.unique(ids))
  })
  |> list.map(fn(concept) { concept.id })
  |> should.equal([])
}

pub fn matrix_edges_carry_cells_test() {
  concepts.graph().hyperedges
  |> list.filter(fn(edge) {
    edge.kind == concepts.Matrix && list.is_empty(edge.cells)
  })
  |> list.map(fn(edge) { edge.id })
  |> should.equal([])
}

pub fn cells_are_well_formed_test() {
  concepts.graph().hyperedges
  |> list.flat_map(fn(edge) { edge.cells })
  |> list.filter(fn(cell) {
    string.trim(cell.row) == ""
    || string.trim(cell.col) == ""
    || string.trim(cell.text) == ""
  })
  |> should.equal([])
}

// 同一张表里，一个行列交点只能有一个格子；重复即作者录错。
pub fn a_cell_appears_at_most_once_test() {
  concepts.graph().hyperedges
  |> list.filter(fn(edge) {
    let keys =
      list.map(edge.cells, fn(cell) { cell.row <> "\u{0000}" <> cell.col })
    list.length(keys) != list.length(list.unique(keys))
  })
  |> list.map(fn(edge) { edge.id })
  |> should.equal([])
}

// 节点数上限按「可单独考」定：超过一百个，画布与侧栏都不再可读。
pub fn node_budget_test() {
  let count = list.length(concepts.graph().concepts)
  { count >= 80 && count <= 100 } |> should.equal(True)
}

// 只有两个节点允许是孤点：一个术语辨析、一个事件案例。
fn orphan_allowlist() -> List(String) {
  ["internet-vs-web", "stuxnet"]
}

pub fn no_unexpected_orphans_test() {
  concepts.graph()
  |> concepts.orphan_ids()
  |> list.filter(fn(id) { !list.contains(orphan_allowlist(), id) })
  |> should.equal([])
}

pub fn every_cluster_has_a_label_test() {
  concepts.all_clusters()
  |> list.filter(fn(cluster) {
    string.trim(concepts.cluster_label(cluster)) == ""
  })
  |> should.equal([])
}

// 画布一簇一段列、静态表按数据顺序，两者都依赖「同簇节点连在一起」。
pub fn concepts_are_grouped_by_cluster_test() {
  let ids =
    concepts.graph().concepts
    |> list.map(fn(concept) { concepts.cluster_id(concept.cluster) })

  // 去掉相邻重复后，每个簇只该出现一次。
  let compact =
    list.fold(ids, [], fn(acc, id) {
      case acc {
        [last, ..] if last == id -> acc
        _ -> [id, ..acc]
      }
    })
    |> list.reverse

  compact |> should.equal(list.unique(compact))

  // 段的先后顺序要与 all_clusters 一致，否则画布上的列会乱跳。
  let expected =
    list.filter(concepts.cluster_ids(), fn(id) { list.contains(compact, id) })

  compact |> should.equal(expected)
}

pub fn every_cluster_has_concepts_test() {
  let used =
    concepts.graph().concepts
    |> list.map(fn(concept) { concepts.cluster_id(concept.cluster) })
    |> list.unique

  concepts.cluster_ids()
  |> list.filter(fn(id) { !list.contains(used, id) })
  |> should.equal([])
}

pub fn search_finds_alias_test() {
  concepts.search(concepts.graph(), "TSN")
  |> list.contains("tsn")
  |> should.equal(True)
}

// 67 道课后习题：第 1—6 章依次为 12、12、9、11、15、8。
fn exercise_count(chapter: Int) -> Int {
  case chapter {
    1 -> 12
    2 -> 12
    3 -> 9
    4 -> 11
    5 -> 15
    6 -> 8
    _ -> 0
  }
}

fn all_exercises() -> List(String) {
  [1, 2, 3, 4, 5, 6]
  |> list.flat_map(fn(chapter) {
    list.map(
      list.take(
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        exercise_count(chapter),
      ),
      fn(item) { int.to_string(chapter) <> "-" <> int.to_string(item) },
    )
  })
}

fn attached_exercises() -> List(String) {
  concepts.graph().concepts
  |> list.flat_map(fn(concept) { concept.questions })
  |> list.map(concepts.question_id)
  |> list.unique
}
