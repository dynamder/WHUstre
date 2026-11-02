import cytoscape from "cytoscape";

// 画布桥：Cytoscape 画图，状态由 Gleam 侧 MVU 持有。
// 跨边界只有四种数据：全图 JSON（init 一次）、状态 JSON（每次更新）、
// 概念 id、键盘按键。

const ROW_GAP = 64;
const COL_GAP = 210;
// 一簇超过这么多节点就折到右边一列：98 个节点排成一条竖条时，
// 全览的缩放只有 0.3 上下，图会退化成一条线。
const MAX_ROWS = 14;
// 同一重心上常落着多条超边（五个安全对象既属于「五类威胁」又属于「5×5 矩阵」），
// 按黄金角把它们散开，避免两个菱形完全重叠。
const HYPEREDGE_MIN_GAP = 46;
const LABEL_ZOOM = 0.75;

const CLUSTER_COLORS = {
  intro: "#6b7280",
  basics: "#0f766e",
  architecture: "#7c3aed",
  network: "#1f6feb",
  platform: "#b45309",
  security: "#b91c1c",
};

let cy = null;
let select_callback = null;
let activate_callback = null;
let resize_observer = null;
let theme_listener = null;

// 主题色从 mdbook 的 CSS 变量读，深浅色切换时重取一次。
function palette() {
  const style = getComputedStyle(document.documentElement);
  const pick = (name, fallback) =>
    style.getPropertyValue(name).trim() || fallback;
  return {
    fg: pick("--fg", "#161616"),
    muted: pick("--sidebar-non-existant", "#9ca3af"),
    edge: pick("--table-border-color", "#d4d4d4"),
    accent: pick("--links", "#1f6feb"),
    surface: pick("--bg", "#ffffff"),
  };
}

function style_for(theme) {
  return [
    {
      selector: "node[kind = 'concept']",
      style: {
        "background-color": "data(color)",
        "border-width": 1,
        "border-color": "data(color)",
        width: 26,
        height: 26,
        label: "data(name)",
        "font-size": 10,
        "font-family": "system-ui",
        color: theme.fg,
        "text-valign": "bottom",
        "text-halign": "center",
        "text-margin-y": 6,
        "text-wrap": "wrap",
        "text-max-width": 120,
        "text-outline-width": 2,
        "text-outline-color": theme.surface,
        "underlay-color": theme.accent,
        "underlay-opacity": 0,
        "underlay-padding": 8,
      },
    },
    {
      selector: "node[kind = 'hyperedge']",
      style: {
        shape: "diamond",
        width: 16,
        height: 16,
        "background-color": theme.muted,
        "border-width": 1,
        "border-color": theme.surface,
        label: "data(label)",
        "font-size": 9,
        "font-family": "system-ui",
        color: theme.muted,
        "text-valign": "center",
        "text-halign": "center",
        "text-margin-y": -13,
        "text-outline-width": 2,
        "text-outline-color": theme.surface,
      },
    },
    {
      selector: "edge",
      style: {
        width: 1,
        "line-color": theme.edge,
        "curve-style": "bezier",
        opacity: 0.8,
      },
    },
    {
      // 二元边直接连线并带箭头；超边的连线不带箭头，方向由菱形承担。
      selector: "edge[binary]",
      style: {
        "target-arrow-shape": "triangle",
        "arrow-scale": 0.5,
        opacity: 0.55,
      },
    },
    {
      // 全览时名字只有四五个像素高，是噪点；悬停、选中、放大后才出字。
      selector: "node.label-off",
      style: { "text-opacity": 0 },
    },
    {
      selector: ".folded",
      style: {
        opacity: 0.08,
        "text-opacity": 0.08,
        "underlay-opacity": 0,
      },
    },
    {
      selector: "node.hover",
      style: { "border-width": 2, opacity: 1, "text-opacity": 1 },
    },
    {
      selector: "node.selected",
      style: {
        "border-width": 2,
        "border-color": theme.accent,
        "underlay-opacity": 0.16,
        opacity: 1,
        "text-opacity": 1,
      },
    },
    {
      selector: "node.match",
      style: { "border-width": 2, "border-color": theme.accent },
    },
    {
      selector: "node.cursor",
      style: {
        "border-width": 2,
        "border-color": theme.accent,
        "border-style": "dashed",
        opacity: 1,
        "text-opacity": 1,
      },
    },
  ];
}

// 布局是确定性的：一簇一段列，簇内按数据顺序排；超边落在其成员的重心附近。
// 图是索引，不是展示品，所以不用力导向布局的随机形状。
function build_elements(graph) {
  const by_cluster = new Map();
  for (const concept of graph.concepts) {
    const items = by_cluster.get(concept.cluster) ?? [];
    items.push(concept);
    by_cluster.set(concept.cluster, items);
  }

  const positions = new Map();
  let column = 0;
  for (const cluster of graph.clusters) {
    const items = by_cluster.get(cluster.id) ?? [];
    by_cluster.delete(cluster.id);
    for (let start = 0; start < items.length; start += MAX_ROWS) {
      const slice = items.slice(start, start + MAX_ROWS);
      slice.forEach((concept, row) => {
        positions.set(concept.id, { x: column * COL_GAP, y: row * ROW_GAP });
      });
      column += 1;
    }
  }
  // clusters 里没登记到的簇也要有位置，不能让节点掉在 (0,0)。
  for (const items of by_cluster.values()) {
    items.forEach((concept, row) => {
      positions.set(concept.id, { x: column * COL_GAP, y: row * ROW_GAP });
    });
    column += 1;
  }

  const elements = graph.concepts.map((concept) => ({
    data: {
      id: concept.id,
      kind: "concept",
      name: concept.name,
      cluster: concept.cluster,
      tested: concept.tested,
      color: CLUSTER_COLORS[concept.cluster] ?? "#6b7280",
    },
    position: positions.get(concept.id),
  }));

  const placed = [];
  const place_hyperedge = (center) => {
    let angle = -0.7;
    let radius = 54;
    for (let attempt = 0; attempt < 60; attempt += 1) {
      const candidate = {
        x: center.x + Math.cos(angle) * radius,
        y: center.y + Math.sin(angle) * radius,
      };
      const free = placed.every(
        (point) =>
          Math.hypot(point.x - candidate.x, point.y - candidate.y) >
          HYPEREDGE_MIN_GAP,
      );
      if (free) {
        placed.push(candidate);
        return candidate;
      }
      angle += 2.399963229728653; // 黄金角
      if (attempt % 3 === 2) radius += 22;
    }
    placed.push(center);
    return center;
  };

  for (const hyperedge of graph.hyperedges) {
    const members = [
      ...new Set([...(hyperedge.members ?? []), hyperedge.result].filter(Boolean)),
    ];

    // 二元边画成一条线：六类二元关系有六十多条，每条都配一个菱形节点会盖住节点。
    if (hyperedge.binary && members.length === 2) {
      elements.push({
        data: {
          id: `b:${hyperedge.id}`,
          source: members[0],
          target: members[1],
          binary: 1,
        },
      });
      continue;
    }
    const points = members
      .map((id) => positions.get(id))
      .filter((point) => point !== undefined);
    const center = points.length
      ? {
          x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
          y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
        }
      : { x: 0, y: 0 };
    const position = place_hyperedge(center);
    positions.set(hyperedge.id, position);

    elements.push({
      data: {
        id: hyperedge.id,
        kind: "hyperedge",
        label: hyperedge.kind,
        name: hyperedge.label,
      },
      position,
    });

    for (const id of members) {
      elements.push({
        data: { id: `e:${hyperedge.id}:${id}`, source: hyperedge.id, target: id },
      });
    }
  }

  return elements;
}

export function init(container, data, on_select, on_activate) {
  destroy();
  select_callback = on_select;
  activate_callback = on_activate;

  const element = document.querySelector(container);
  if (!element) return;

  const graph = JSON.parse(data);
  cy = cytoscape({
    container: element,
    elements: build_elements(graph),
    style: style_for(palette()),
    layout: { name: "preset" },
    minZoom: 0.3,
    maxZoom: 2.4,
    boxSelectionEnabled: false,
  });

  cy.ready(() => {
    cy.fit(undefined, 40);
    sync_labels();
  });
  cy.on("zoom", sync_labels);

  cy.on("tap", "node", (event) => {
    const node = event.target;
    if (node.hasClass("folded")) return;
    if (node.data("kind") === "concept") select_callback?.(node.id());
  });
  cy.on("dbltap", "node[kind = 'concept']", (event) => {
    if (event.target.hasClass("folded")) return;
    activate_callback?.(event.target.id());
  });
  cy.on("tap", (event) => {
    if (event.target === cy) select_callback?.("");
  });
  cy.on("dbltap", (event) => {
    if (event.target === cy) cy.fit(undefined, 40);
  });
  cy.on("mouseover", "node", (event) => {
    if (!event.target.hasClass("folded")) event.target.addClass("hover");
  });
  cy.on("mouseout", "node", (event) => event.target.removeClass("hover"));

  if (typeof ResizeObserver !== "undefined") {
    resize_observer = new ResizeObserver(() => {
      if (cy) cy.resize();
    });
    resize_observer.observe(element);
  }

  theme_listener = () => {
    if (cy) cy.style(style_for(palette()));
  };
  window
    .matchMedia("(prefers-color-scheme: dark)")
    .addEventListener("change", theme_listener);
}

// 名字只在该看清的缩放下出现：全览是索引，放大才是阅读。
// 悬停、选中、键盘游标的样式在 style_for 里排在 label-off 之后，会自动压过它。
function sync_labels() {
  if (!cy) return;
  const show = cy.zoom() >= LABEL_ZOOM;
  cy.batch(() => {
    cy.nodes().toggleClass("label-off", !show);
  });
}

export function apply(state) {
  if (!cy) return;

  const current = JSON.parse(state);
  const enabled = new Set(current.clusters ?? []);
  const matches = new Set(current.matches ?? []);

  let ego_scope = null;
  if (current.ego) {
    ego_scope = new Set(
      cy
        .getElementById(current.ego)
        .closedNeighborhood()
        .map((element) => element.id()),
    );
    ego_scope.add(current.ego);
  }

  const folded = new Set();

  cy.batch(() => {
    cy.elements().removeClass("folded selected match cursor");

    cy.nodes("[kind = 'concept']").forEach((node) => {
      const data = node.data();
      const hidden =
        !enabled.has(data.cluster) ||
        (current.tested_only && !data.tested) ||
        (ego_scope && !ego_scope.has(data.id)) ||
        (current.query && !matches.has(data.id));
      if (hidden) {
        node.addClass("folded");
        folded.add(data.id);
      }
      if (data.id === current.selected) node.addClass("selected");
      if (data.id === current.cursor) node.addClass("cursor");
      if (matches.has(data.id)) node.addClass("match");
    });

    cy.nodes("[kind = 'hyperedge']").forEach((node) => {
      const visible = node
        .neighborhood()
        .filter("[kind = 'concept']")
        .some((member) => !folded.has(member.id()));
      const in_ego = !ego_scope || ego_scope.has(node.id());
      if (!visible || !in_ego) {
        node.addClass("folded");
        folded.add(node.id());
      }
    });

    cy.edges().forEach((edge) => {
      if (
        folded.has(edge.source().id()) ||
        folded.has(edge.target().id())
      ) {
        edge.addClass("folded");
      }
    });
  });
}

export function focus(id) {
  if (!cy) return;
  const node = cy.getElementById(id);
  if (!node || node.empty()) return;
  cy.animate(
    { center: { eles: node }, zoom: Math.min(Math.max(cy.zoom(), 0.8), 1.3) },
    { duration: 250 },
  );
}

export function destroy() {
  if (resize_observer) {
    resize_observer.disconnect();
    resize_observer = null;
  }
  if (theme_listener) {
    window
      .matchMedia("(prefers-color-scheme: dark)")
      .removeEventListener("change", theme_listener);
    theme_listener = null;
  }
  if (cy) {
    cy.destroy();
    cy = null;
  }
  select_callback = null;
  activate_callback = null;
}

// 定位用查询串，不用 hash：mdbook 的 book.js 会接管 # 锚点。
export function read_focus() {
  return new URLSearchParams(window.location.search).get("focus") || "";
}

export function replace_focus(id) {
  const params = new URLSearchParams(window.location.search);
  if (id) params.set("focus", id);
  else params.delete("focus");
  const search = params.toString();
  window.history.replaceState(
    null,
    "",
    window.location.pathname + (search ? "?" + search : ""),
  );
}

export function focus_search() {
  const input = document.getElementById("graph-search");
  if (input) {
    input.focus();
    input.select();
  }
}

export function register_keys(callback) {
  window.addEventListener("keydown", (event) => {
    const target = event.target;
    const typing =
      target &&
      (target.tagName === "INPUT" ||
        target.tagName === "TEXTAREA" ||
        target.isContentEditable);

    if (event.key === "/" && !typing) {
      event.preventDefault();
      focus_search();
      return;
    }
    if (typing && event.key !== "Escape" && event.key !== "Enter") return;

    switch (event.key) {
      case "j":
      case "ArrowDown":
        event.preventDefault();
        callback("j");
        break;
      case "k":
      case "ArrowUp":
        event.preventDefault();
        callback("k");
        break;
      case "Enter":
        callback("enter");
        break;
      case "Escape":
        callback("escape");
        break;
    }
  });
}
