import cytoscape from "cytoscape";

// 画布桥：Cytoscape 画图，状态由 Gleam 侧 MVU 持有。
// 跨边界只有四种数据：全图 JSON（init 一次）、状态 JSON（每次更新）、
// 概念 id、键盘按键。

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
    {
      // 簇框：淡色底 + 虚线边 + 簇名。它承担「聚类」这件事，
      // 但只做背景，别和节点抢注意力。
      selector: ":parent",
      style: {
        shape: "round-rectangle",
        "background-color": "data(color)",
        "background-opacity": 0.045,
        "border-width": 1,
        "border-style": "dashed",
        "border-color": "data(color)",
        "border-opacity": 0.3,
        label: "data(label)",
        "font-size": 11,
        "font-weight": 600,
        "text-valign": "top",
        "text-halign": "center",
        "text-margin-y": -6,
        color: "data(color)",
        "text-outline-width": 2,
        "text-outline-color": theme.surface,
        padding: 26,
      },
    },
  ];
}

// 布局 -------------------------------------------------------------------
//
// 布局自己算：这张图要同时满足三件事——六簇各自成团、强关系近弱关系远、
// 每次打开形状一致。现成的力导向插件在两点上不合用：fCoSE/cose 的增量模式
// 会把初值（列网格）原样保留下来，随机模式又每次不同；compound 父节点在
// 这张图上会把整体撑到一万多像素。所以这里用一个确定性的小模拟：
// 哈希云做初值，成对斥力 + 按关系类型定长的弹簧 + 簇锚点牵引，迭代固定次数。

const ITERATIONS = 520;
const REPULSION = 950;
const ANCHOR_PULL = 0.032;
const STEP_LIMIT = 26;
const SEED_RX = 440;
const SEED_RY = 280;

// 关系越强，弹簧越硬、静止长度越短。对照关系故意放到 165 且很松：
// 「同一组对象的两个视角」在图上应当明显比「某概念是某概念的一部分」远。
const SPRING = {
  组成: { rest: 58, stiffness: 0.07 },
  上位: { rest: 58, stiffness: 0.07 },
  依赖: { rest: 62, stiffness: 0.06 },
  细化: { rest: 62, stiffness: 0.06 },
  度量: { rest: 78, stiffness: 0.04 },
  对照: { rest: 165, stiffness: 0.012 },
  矩阵: { rest: 95, stiffness: 0.03 },
  选型: { rest: 95, stiffness: 0.03 },
  映射: { rest: 82, stiffness: 0.04 },
  流程: { rest: 90, stiffness: 0.035 },
  演进: { rest: 82, stiffness: 0.04 },
  超边: { rest: 92, stiffness: 0.03 },
};

// splitmix32 的简化版：给定整数，稳定地吐出一个 [0,1) 小数。
// 用它代替 Math.random，同一个节点每次都在同一处出发。
function hash_unit(seed) {
  let value = seed | 0;
  value = (value + 0x9e3779b9) | 0;
  let t = value ^ (value >>> 16);
  t = Math.imul(t, 0x21f0aaad);
  t ^= t >>> 15;
  t = Math.imul(t, 0x735a2d97);
  t ^= t >>> 15;
  return (t >>> 0) / 4294967296;
}

function seed_anchors(graph) {
  const anchors = new Map();
  const total = Math.max(graph.clusters.length, 1);
  graph.clusters.forEach((cluster, index) => {
    const angle = -Math.PI / 2 + (index * 2 * Math.PI) / total;
    anchors.set(cluster.id, {
      x: Math.cos(angle) * SEED_RX,
      y: Math.sin(angle) * SEED_RY,
    });
  });
  return anchors;
}

function relax(positions, links, anchors, cluster_of) {
  const ids = [...positions.keys()];
  const pos = new Map(
    ids.map((id) => [id, { x: positions.get(id).x, y: positions.get(id).y }]),
  );
  const disp = new Map(ids.map((id) => [id, { x: 0, y: 0 }]));
  const plus = (map, id, x, y) => {
    const slot = map.get(id);
    slot.x += x;
    slot.y += y;
  };

  for (let step = 0; step < ITERATIONS; step += 1) {
    const alpha = 1 - step / ITERATIONS;
    for (const id of ids) {
      const slot = disp.get(id);
      slot.x = 0;
      slot.y = 0;
    }

    for (let i = 0; i < ids.length; i += 1) {
      const a = pos.get(ids[i]);
      for (let j = i + 1; j < ids.length; j += 1) {
        const b = pos.get(ids[j]);
        let dx = a.x - b.x;
        let dy = a.y - b.y;
        let d2 = dx * dx + dy * dy;
        if (d2 < 1) {
          dx = 0.5 + hash_unit(i * 7 + j);
          dy = 0.5 + hash_unit(j * 7 + i);
          d2 = dx * dx + dy * dy;
        }
        const d = Math.sqrt(d2);
        const push = REPULSION / d2;
        const fx = (dx / d) * push;
        const fy = (dy / d) * push;
        plus(disp, ids[i], fx, fy);
        plus(disp, ids[j], -fx, -fy);
      }
    }

    for (const link of links) {
      const a = pos.get(link.a);
      const b = pos.get(link.b);
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const d = Math.hypot(dx, dy) || 0.001;
      const pull = (d - link.rest) * link.stiffness;
      const fx = (dx / d) * pull;
      const fy = (dy / d) * pull;
      plus(disp, link.a, fx, fy);
      plus(disp, link.b, -fx, -fy);
    }

    for (const id of ids) {
      const anchor = anchors.get(cluster_of.get(id));
      if (!anchor) continue;
      const p = pos.get(id);
      plus(disp, id, (anchor.x - p.x) * ANCHOR_PULL, (anchor.y - p.y) * ANCHOR_PULL);
    }

    for (const id of ids) {
      const p = pos.get(id);
      const d = disp.get(id);
      const length = Math.hypot(d.x, d.y);
      const cap = STEP_LIMIT * alpha + 1.5;
      const scale = length > cap ? cap / length : 1;
      p.x += d.x * scale;
      p.y += d.y * scale;
    }
  }

  return pos;
}

// 超边的菱形找不到不压节点的位置时，就放在成员重心上——宁可压一次，
// 也不要把它甩到一个没有关系指向的地方。
function place_diamond(center, nodes, placed) {
  let angle = -0.7;
  let radius = 34;
  for (let attempt = 0; attempt < 80; attempt += 1) {
    const candidate = {
      x: center.x + Math.cos(angle) * radius,
      y: center.y + Math.sin(angle) * radius,
    };
    const clear_of_nodes = nodes.every(
      (point) => Math.hypot(point.x - candidate.x, point.y - candidate.y) > 30,
    );
    const clear_of_diamonds = placed.every(
      (point) => Math.hypot(point.x - candidate.x, point.y - candidate.y) > 42,
    );
    if (clear_of_nodes && clear_of_diamonds) {
      placed.push(candidate);
      return candidate;
    }
    angle += 2.399963229728653;
    if (attempt % 4 === 3) radius += 18;
  }
  placed.push(center);
  return center;
}

export function build_elements(graph) {
  const anchors = seed_anchors(graph);
  const seeds = new Map();
  const cluster_of = new Map();
  const rows = new Map();

  for (const concept of graph.concepts) {
    const anchor = anchors.get(concept.cluster) ?? { x: 0, y: 0 };
    const index = rows.get(concept.cluster) ?? 0;
    rows.set(concept.cluster, index + 1);
    // 初值必须是「云」而不是网格：从网格出发，迭代后会保留网格的痕迹。
    const angle = hash_unit(index * 2 + 1) * 2 * Math.PI;
    const radius = 30 + hash_unit(index * 2 + 2) * 210;
    seeds.set(concept.id, {
      x: anchor.x + Math.cos(angle) * radius,
      y: anchor.y + Math.sin(angle) * radius,
    });
    cluster_of.set(concept.id, concept.cluster);
  }

  const links = [];
  for (const edge of graph.hyperedges) {
    const members = [
      ...new Set([...(edge.members ?? []), edge.result].filter(Boolean)),
    ];
    const spring = SPRING[edge.kind] ?? SPRING.超边;
    if (edge.binary && members.length === 2) {
      links.push({ a: members[0], b: members[1], ...spring });
      continue;
    }
    // 超边没有菱形节点参与布局：成员之间用「超边」这一档的弹簧互相牵引，
    // 菱形稍后落在成员重心旁边。
    for (let i = 0; i < members.length; i += 1) {
      for (let j = i + 1; j < members.length; j += 1) {
        links.push({ a: members[i], b: members[j], ...SPRING.超边 });
      }
    }
  }

  const positions = relax(seeds, links, anchors, cluster_of);

  const elements = [];

  // 簇框：parent 只负责把同簇节点框在一起，位置仍由上面的模拟决定。
  // 用 compound 而不是画装饰矩形，是因为折叠、ego 与打印都要跟着它走。
  for (const cluster of graph.clusters) {
    const members = graph.concepts.filter((concept) => concept.cluster === cluster.id);
    const points = members.map((concept) => positions.get(concept.id)).filter(Boolean);
    const center = points.length
      ? {
          x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
          y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
        }
      : anchors.get(cluster.id) ?? { x: 0, y: 0 };
    elements.push({
      data: {
        id: `cluster:${cluster.id}`,
        kind: "cluster",
        label: cluster.label,
        color: CLUSTER_COLORS[cluster.id] ?? "#6b7280",
      },
      position: center,
    });
  }

  for (const concept of graph.concepts) {
    elements.push({
      data: {
        id: concept.id,
        kind: "concept",
        name: concept.name,
        cluster: concept.cluster,
        parent: `cluster:${concept.cluster}`,
        tested: concept.tested,
        color: CLUSTER_COLORS[concept.cluster] ?? "#6b7280",
      },
      position: positions.get(concept.id),
    });
  }

  const node_points = [...positions.values()];
  const placed = [];

  for (const hyperedge of graph.hyperedges) {
    const members = [
      ...new Set([...(hyperedge.members ?? []), hyperedge.result].filter(Boolean)),
    ];

    if (hyperedge.binary && members.length === 2) {
      elements.push({
        data: {
          id: `b:${hyperedge.id}`,
          source: members[0],
          target: members[1],
          binary: 1,
          kind: hyperedge.kind,
        },
      });
      continue;
    }

    const points = members.map((id) => positions.get(id)).filter(Boolean);
    const centroid = points.length
      ? {
          x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
          y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
        }
      : { x: 0, y: 0 };
    const position = place_diamond(centroid, node_points, placed);

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
        data: {
          id: `e:${hyperedge.id}:${id}`,
          source: hyperedge.id,
          target: id,
          kind: "超边",
        },
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
    minZoom: 0.25,
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
    cy.nodes("[kind = 'concept'], [kind = 'hyperedge']").toggleClass(
      "label-off",
      !show,
    );
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

    // 簇框随簇一起让位：簇被关掉、或进入 ego 模式时，框里没有东西可框。
    cy.nodes("[kind = 'cluster']").forEach((node) => {
      const id = node.id().slice("cluster:".length);
      if (!enabled.has(id) || current.ego) node.addClass("folded");
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
