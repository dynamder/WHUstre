import courses/industrial_internet/concepts
import courses/industrial_internet/cyto
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// 概念图谱页：一个普通的 Lustre MVU，接进 mdbook 页面的方式只有一条约定——
// 页面留 <div id="graph-root">，入口文件调 mount("#graph-root")。
//
// 画布是 #graph-canvas，归 Cytoscape 所有，不放在 Lustre 的渲染子树里：
// MVU 每次更新都会重画自己的 DOM，imperative 画布放在别处才不会被换掉。

pub type Model {
  Model(
    graph: concepts.Graph,
    selected: Option(String),
    query: String,
    cursor: Int,
    enabled: List(String),
    only_tested: Bool,
    ego: Option(String),
  )
}

pub type Message {
  NodeTapped(String)
  NodeActivated(String)
  QueryTyped(String)
  CursorMoved(Int)
  ClusterToggled(String)
  TestedToggled
  KeyPressed(String)
  Dismissed
}

pub fn mount(selector: String) -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, selector, Nil)
  Nil
}

fn init(_arguments: Nil) -> #(Model, Effect(Message)) {
  let graph = concepts.graph()
  let model =
    Model(
      graph: graph,
      selected: initial_selection(graph, cyto.read_focus()),
      query: "",
      cursor: 0,
      enabled: concepts.cluster_ids(),
      only_tested: False,
      ego: None,
    )
  #(model, effect.batch([listen_keys(), boot_effect(model)]))
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    NodeTapped("") -> dismiss_selection(model)

    NodeTapped(id) ->
      sync(Model(..model, selected: Some(id), ego: None), effect.none())

    NodeActivated(id) -> {
      let ego = case model.ego {
        Some(current) if current == id -> None
        _ -> Some(id)
      }
      sync(Model(..model, selected: Some(id), ego: ego), effect.none())
    }

    QueryTyped(query) ->
      sync(Model(..model, query: query, cursor: 0), effect.none())

    CursorMoved(delta) -> {
      let ids = nav_ids(model)
      let cursor =
        int.clamp(model.cursor + delta, 0, int.max(list.length(ids) - 1, 0))
      let model = Model(..model, cursor: cursor)
      case at(ids, cursor) {
        Ok(id) -> sync(model, focus_effect(id))
        Error(_) -> sync(model, effect.none())
      }
    }

    ClusterToggled(id) -> {
      let enabled = case list.contains(model.enabled, id) {
        True -> list.filter(model.enabled, fn(other) { other != id })
        False ->
          list.filter(concepts.cluster_ids(), fn(other) {
            other == id || list.contains(model.enabled, other)
          })
      }
      sync(Model(..model, enabled: enabled, cursor: 0), effect.none())
    }

    TestedToggled ->
      sync(
        Model(..model, only_tested: !model.only_tested, cursor: 0),
        effect.none(),
      )

    KeyPressed(key) -> key_pressed(model, key)

    Dismissed -> dismiss_selection(model)
  }
}

fn key_pressed(model: Model, key: String) -> #(Model, Effect(Message)) {
  case key {
    "j" -> update(model, CursorMoved(1))
    "k" -> update(model, CursorMoved(-1))
    "enter" ->
      case at(nav_ids(model), model.cursor) {
        Ok(id) -> update(model, NodeTapped(id))
        Error(_) -> sync(model, effect.none())
      }
    "escape" -> escape(model)
    _ -> sync(model, effect.none())
  }
}

fn escape(model: Model) -> #(Model, Effect(Message)) {
  case model.query {
    "" ->
      case model.ego {
        Some(_) -> sync(Model(..model, ego: None), effect.none())
        None -> dismiss_selection(model)
      }
    _ -> sync(Model(..model, query: "", cursor: 0), effect.none())
  }
}

fn dismiss_selection(model: Model) -> #(Model, Effect(Message)) {
  sync(Model(..model, selected: None, ego: None, cursor: 0), effect.none())
}

// 视图 -------------------------------------------------------------------

pub fn view(model: Model) -> Element(Message) {
  html.div([attribute.class("graph-ui")], [
    tools(model),
    results_panel(model),
    detail_panel(model),
  ])
}

fn tools(model: Model) -> Element(Message) {
  html.div([attribute.class("graph-tools")], [
    html.input([
      attribute.id("graph-search"),
      attribute.type_("search"),
      attribute.class("graph-search"),
      attribute.value(model.query),
      attribute.placeholder("搜索概念 / 别名"),
      attribute.aria_label("搜索概念与别名，回车定位"),
      event.on_input(QueryTyped),
    ]),
    html.div(
      [attribute.class("graph-chips"), attribute.aria_label("按簇过滤")],
      list.map(concepts.all_clusters(), fn(cluster) {
        cluster_chip(model, cluster)
      }),
    ),
    tested_toggle(model),
    html.p([attribute.class("graph-help")], [
      html.text("点节点看细节 · 双击只看邻居 · 滚轮放大显示名称 · / 搜索 · j/k 移动 · Esc 返回"),
    ]),
  ])
}

fn cluster_chip(model: Model, cluster: concepts.Cluster) -> Element(Message) {
  let id = concepts.cluster_id(cluster)
  let is_on = list.contains(model.enabled, id)
  html.button(
    [
      attribute.type_("button"),
      attribute.class(
        "graph-chip cluster-"
        <> id
        <> case is_on {
          True -> " is-on"
          False -> ""
        },
      ),
      attribute.aria_pressed(case is_on {
        True -> "true"
        False -> "false"
      }),
      event.on_click(ClusterToggled(id)),
    ],
    [html.text(concepts.cluster_label(cluster))],
  )
}

fn tested_toggle(model: Model) -> Element(Message) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(
        "graph-chip"
        <> case model.only_tested {
          True -> " is-on"
          False -> ""
        },
      ),
      attribute.aria_pressed(case model.only_tested {
        True -> "true"
        False -> "false"
      }),
      event.on_click(TestedToggled),
    ],
    [html.text("只看考过")],
  )
}

fn results_panel(model: Model) -> Element(Message) {
  case concepts.search(model.graph, model.query) {
    [] ->
      case model.query {
        "" -> html.text("")
        _ ->
          html.p([attribute.class("graph-muted")], [
            html.text("没有匹配的概念。"),
          ])
      }
    ids ->
      html.div(
        [attribute.class("graph-results"), attribute.aria_label("搜索结果")],
        list.index_map(ids, fn(id, index) { result_row(model, id, index) }),
      )
  }
}

fn result_row(model: Model, id: String, index: Int) -> Element(Message) {
  let is_active = index == model.cursor
  let name = case concepts.find_concept(model.graph, id) {
    Some(concept) -> concept.name
    None -> id
  }
  let cluster = case concepts.find_concept(model.graph, id) {
    Some(concept) -> concepts.cluster_label(concept.cluster)
    None -> ""
  }
  html.button(
    [
      attribute.type_("button"),
      attribute.class(
        "graph-result"
        <> case is_active {
          True -> " is-active"
          False -> ""
        },
      ),
      event.on_click(NodeTapped(id)),
    ],
    [
      html.span([attribute.class("graph-result-name")], [html.text(name)]),
      html.span([attribute.class("graph-result-cluster")], [
        html.text(cluster),
      ]),
    ],
  )
}

fn detail_panel(model: Model) -> Element(Message) {
  case model.selected {
    None ->
      html.p([attribute.class("graph-hint")], [
        html.text("还没选中概念。点一个节点，或按 / 搜索。"),
      ])
    Some(id) ->
      case concepts.find_concept(model.graph, id) {
        Some(concept) -> concept_detail(model, concept)
        None ->
          html.p([attribute.class("graph-muted")], [
            html.text("选中的概念不在数据里。"),
          ])
      }
  }
}

fn concept_detail(model: Model, concept: concepts.Concept) -> Element(Message) {
  html.article([attribute.class("graph-card")], [
    html.header([attribute.class("graph-card-head")], [
      html.h2([attribute.class("graph-card-title")], [html.text(concept.name)]),
      html.span([attribute.class("graph-tag")], [
        html.text(concepts.cluster_label(concept.cluster)),
      ]),
    ]),
    aliases(concept),
    field("定义", [html.p([], [html.text(concept.def)])]),
    field("机制", [html.p([], [html.text(concept.mechanism)])]),
    caliber_field(concept),
    questions_field(concept),
    relations_field(model, concept),
    html.footer([attribute.class("graph-card-foot")], [
      html.a([attribute.href(concept.chapter)], [
        html.text("去这一章读上下文 →"),
      ]),
    ]),
  ])
}

fn field(title: String, content: List(Element(Message))) -> Element(Message) {
  html.section(
    [attribute.class("graph-block")],
    list.append(
      [html.h3([attribute.class("graph-block-title")], [html.text(title)])],
      content,
    ),
  )
}

fn aliases(concept: concepts.Concept) -> Element(Message) {
  case concept.aliases {
    [] -> html.text("")
    aliases ->
      html.p([attribute.class("graph-aliases")], [
        html.text("别名：" <> string.join(aliases, " · ")),
      ])
  }
}

fn caliber_field(concept: concepts.Concept) -> Element(Message) {
  case concept.caliber {
    "" -> html.text("")
    caliber -> field("口径", [html.p([], [html.text(caliber)])])
  }
}

fn questions_field(concept: concepts.Concept) -> Element(Message) {
  case concept.questions {
    [] ->
      field("题号", [
        html.p([attribute.class("graph-muted")], [
          html.text("课件习题里没有直接考过。"),
        ]),
      ])
    questions ->
      field("题号", [
        html.p(
          [],
          list.map(questions, fn(question) {
            html.a(
              [
                attribute.class("graph-question"),
                attribute.href(concepts.question_href(question)),
                attribute.title(concepts.question_label(question)),
              ],
              [html.text(concepts.question_label(question))],
            )
          }),
        ),
      ])
  }
}

fn relations_field(
  model: Model,
  concept: concepts.Concept,
) -> Element(Message) {
  case concepts.hyperedges_of(model.graph, concept.id) {
    [] ->
      field("关系", [
        html.p([attribute.class("graph-muted")], [html.text("暂无超边。")]),
      ])
    edges ->
      field("关系", list.map(edges, fn(edge) { hyperedge_card(model, edge) }))
  }
}

fn hyperedge_card(model: Model, edge: concepts.Hyperedge) -> Element(Message) {
  html.div([attribute.class("graph-edge-card")], [
    html.div([attribute.class("graph-edge-head")], [
      html.span([attribute.class("graph-edge-kind")], [
        html.text(concepts.edge_kind_label(edge.kind)),
      ]),
      html.span([attribute.class("graph-edge-label")], [
        html.text(edge.label),
      ]),
    ]),
    // 角色清单在表格之前：矩阵的行列标签也是节点，点一下就能跳过去。
    roles_list(model, edge),
    case edge.cells {
      [] -> html.text("")
      _ -> cells_table(edge)
    },
    case edge.result {
      Some(id) ->
        html.p([attribute.class("graph-edge-result")], [
          html.text("结果："),
          concept_chip(model, id),
        ])
      None -> html.text("")
    },
    case edge.note {
      "" -> html.text("")
      note -> html.p([attribute.class("graph-edge-note")], [html.text(note)])
    },
  ])
}

// 矩阵与选型：cells 直接落成表格，行列顺序即数据的录入顺序。
// 表格是超边的正式形态，角色清单只留给没有格子的二元超边。
fn cells_table(edge: concepts.Hyperedge) -> Element(Message) {
  let columns = concepts.cell_columns(edge)
  html.table([attribute.class("graph-edge-table")], [
    html.thead([], [
      html.tr(
        [],
        list.append(
          [html.th([attribute.scope("col")], [])],
          list.map(columns, fn(column) {
            html.th([attribute.scope("col")], [html.text(column)])
          }),
        ),
      ),
    ]),
    html.tbody(
      [],
      list.map(concepts.cell_rows(edge), fn(row) {
        html.tr(
          [],
          list.append(
            [html.th([attribute.scope("row")], [html.text(row)])],
            list.map(columns, fn(column) {
              html.td([], [
                html.text(concepts.cell_text(edge, row, column)),
              ])
            }),
          ),
        )
      }),
    ),
  ])
}

fn roles_list(model: Model, edge: concepts.Hyperedge) -> Element(Message) {
  html.div(
    [attribute.class("graph-roles")],
    list.map(edge.roles, fn(role) {
      html.p([], [
        html.strong([], [html.text(role.name <> "：")]),
        html.span(
          [attribute.class("graph-role-members")],
          list.map(role.members, fn(id) { concept_chip(model, id) }),
        ),
      ])
    }),
  )
}

fn concept_chip(model: Model, id: String) -> Element(Message) {
  let label = case concepts.find_concept(model.graph, id) {
    Some(concept) -> concept.name
    None -> id <> "（缺失）"
  }
  html.button(
    [
      attribute.type_("button"),
      attribute.class("graph-linkish"),
      event.on_click(NodeTapped(id)),
    ],
    [html.text(label)],
  )
}

// 状态与副作用 -----------------------------------------------------------

fn initial_selection(graph: concepts.Graph, focus: String) -> Option(String) {
  case focus {
    "" -> None
    id ->
      case concepts.find_concept(graph, id) {
        Some(concept) -> Some(concept.id)
        None -> None
      }
  }
}

fn nav_ids(model: Model) -> List(String) {
  case string.trim(model.query) {
    "" -> concepts.visible_ids(model.graph, model.enabled, model.only_tested)
    _ -> concepts.search(model.graph, model.query)
  }
}

fn cursor_id(model: Model) -> Option(String) {
  case at(nav_ids(model), model.cursor) {
    Ok(id) -> Some(id)
    Error(_) -> None
  }
}

fn at(ids: List(String), index: Int) -> Result(String, Nil) {
  case list.drop(ids, index) {
    [id, ..] -> Ok(id)
    [] -> Error(Nil)
  }
}

fn state_json(model: Model) -> String {
  json.object([
    #("selected", json.nullable(from: model.selected, of: json.string)),
    #("cursor", json.nullable(from: cursor_id(model), of: json.string)),
    #("ego", json.nullable(from: model.ego, of: json.string)),
    #("clusters", json.array(from: model.enabled, of: json.string)),
    #("tested_only", json.bool(model.only_tested)),
    #("query", json.string(model.query)),
    #(
      "matches",
      json.array(
        from: concepts.search(model.graph, model.query),
        of: json.string,
      ),
    ),
  ])
  |> json.to_string
}

fn sync(model: Model, extra: Effect(Message)) -> #(Model, Effect(Message)) {
  #(model, effect.batch([apply_effect(model), url_effect(model), extra]))
}

fn apply_effect(model: Model) -> Effect(Message) {
  effect.after_paint(fn(_dispatch, _root) {
    cyto.apply(state_json(model))
    Nil
  })
}

fn url_effect(model: Model) -> Effect(Message) {
  effect.from(fn(_dispatch) {
    cyto.replace_focus(case model.selected {
      Some(id) -> id
      None -> ""
    })
    Nil
  })
}

fn focus_effect(id: String) -> Effect(Message) {
  effect.after_paint(fn(_dispatch, _root) {
    cyto.focus(id)
    Nil
  })
}

fn boot_effect(model: Model) -> Effect(Message) {
  effect.after_paint(fn(dispatch, _root) {
    cyto.init(
      "#graph-canvas",
      concepts.to_json(model.graph),
      fn(id) { dispatch(NodeTapped(id)) },
      fn(id) { dispatch(NodeActivated(id)) },
    )
    cyto.apply(state_json(model))
    case model.selected {
      Some(id) -> cyto.focus(id)
      None -> Nil
    }
  })
}

fn listen_keys() -> Effect(Message) {
  effect.from(fn(dispatch) {
    cyto.register_keys(fn(key) { dispatch(KeyPressed(key)) })
    Nil
  })
}
