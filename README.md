# 课程资料库

按课程组织的复习资料：**每门课是一本独立的 mdbook**，外面套一个用
[Gleam](https://gleam.run/) + [Lustre](https://lustre.build/) 写的门面，负责
在课程之间导航、筛选、跳章节。

- 在线：<https://dynamder.github.io/WHUstre/>
- 当前课程：工业互联网基础、互换性与技术测量
- 门面不渲染正文；正文由每本书自己的 mdbook 负责

![课程资料库](docs/screenshots/home.png)

## 它长什么样

左边是课程列表，右边是选中课程的目录地图；点任意章节直接进入 mdbook 的对应页。

```
┌──────────────────────────────────────────────────────────────────────┐
│ 课程资料库        [ 搜索课程、章节或动作        Ctrl K ]        GitHub │
├────────────────────┬─────────────────────────────────────────────────┤
│ 课程 6             │  工业互联网基础                                 │
│ ▌工业互联网基础 9  │  II-201 · 9 页 · 更新 2026-11-03                │
│ 互换性与技术测量 7 │  ME-204 · 7 页 · 更新 2026-11-01                │
│  理论力学   待认领 │  机构 · 四杆 · 电机 · 齿轮                      │
│  材料力学   待认领 │  [开始] [讲义] [速查] [真题] [附录]             │
│  机械原理   待认领 │  ─────────────────────────────────────────────    │
│  机械设计   待认领 │  讲义                                           │
│                    │  L1 机构学基础与四杆机构                    ↗   │
│                    │  L2 四杆机构的分析与综合                    ↗   │
│                    │  ...                                            │
└────────────────────┴─────────────────────────────────────────────────┘
```

命令面板把「找东西」和「做动作」收在同一个入口：`Ctrl K` / `⌘K` 打开，
`/` 也可以。里面只有三类结果——**章节、课程、动作**。

![命令面板](docs/screenshots/palette.png)

深浅色跟随系统，门面和书一起切换（没有单独的开关）：

![深色模式](docs/screenshots/dark-home.png)

手机上退化成两屏：课程列表 → 课程地图，返回按钮回到列表。

<p>
  <img src="docs/screenshots/mobile.png" width="260" alt="手机课程列表" />
  <img src="docs/screenshots/mobile-detail.png" width="260" alt="手机课程地图" />
</p>

## 目录结构

```text
.
├── courses/
│   ├── industrial-internet/    # 一门课 = 一本 mdbook
│   │   ├── meta.json           # 门面读：标题、代码、标签、状态、维护者、ui
│   │   ├── book.toml           # mdbook 配置
│   │   ├── theme/              # 与门面对齐的 mdbook 主题 + 返回胶囊 + 图页样式
│   │   ├── ui/dist/            # 课程 UI 构建产物（被 .gitignore）
│   │   └── src/
│   │       ├── SUMMARY.md      # 目录（Part 标题决定内容类型）
│   │       ├── ch01.md ...     # 章节
│   │       ├── graph.md        # 课程 UI 的挂载页 + 静态总表
│   │       └── assets/figs/    # 图片
│   ├── mechanics/              # 只有 meta.json 的“待认领”课程
│   └── ...
├── site/                       # Gleam + Lustre 门面
│   ├── src/                    # catalog / data / results / view / ffi
│   │   └── courses/<slug>/     # 课程 UI 的 Gleam 模块（数据 + MVU + FFI）
│   ├── test/                   # 引用完整性等测试
│   ├── public/                 # index.html、styles.css、vendor/mathjax
│   └── scripts/                # esbuild 打包、课程 UI 入口、静态页面片段
├── scripts/                    # 构建编排 + 插图脚本
├── docs/                       # 设计文档 + 截图
└── dist/                       # 构建产物（被 .gitignore）
```

## 构建

依赖：

- [Gleam](https://gleam.run/) 1.19+
- [mdbook](https://rust-lang.github.io/mdBook/) 0.5.4
- Node.js 18+

第一次先装门面的依赖：

```bash
cd site
gleam deps download
node scripts/strip-priv.mjs   # Windows 无开发者模式时去掉 priv 软链接
npm install                   # esbuild + cytoscape（课程 UI 用）
cd ..
```

然后：

```bash
npm run build      # catalog -> gleam -> bundle -> 静态表 -> mdbook -> dist/
npm run serve      # http://127.0.0.1:5173/
npm run dev        # build + serve
```

`npm run build` 做五件事：

1. `scripts/gen-catalog.mjs`：扫 `courses/*/meta.json` 和 `src/SUMMARY.md`，
   生成 `catalog.json`（门面在构建期内联，运行时零请求）；
2. `site/` 里 `gleam build`，编译门面与各课程 UI 模块；
3. esbuild 打包门面 `app.js`，并按每门课的 `ui` 字段把课程 UI 入口打进
   `courses/<slug>/ui/dist/`；`site/scripts/gen-graph-table.mjs` 从同一份 Gleam
   数据生成图页的静态总表；
4. 对每门有 `src/SUMMARY.md` 的课执行 `mdbook build`；
5. `scripts/assemble.mjs` 把门面、所有书和课程 UI 产物组装进 `dist/`。

课程 UI 的产物**不写进 `book/`**：mdbook 每次重建都会清空输出目录。产物落在
`courses/<slug>/ui/dist/`，由 assemble 拷到 `dist/courses/<slug>/ui/`，书的页面用
相对路径 `ui/graph.js` 引用。

## 加一门课

1. 建目录 `courses/<slug>/`，写 `meta.json`：

   ```json
   {
     "slug": "mechanics",
     "title": "理论力学",
     "code": "ME-102",
     "summary": "静力学 · 运动学 · 动力学",
     "tags": ["静力学", "运动学"],
     "status": "active",
     "order": 2,
     "maintainers": ["@your-handle"],
     "updated": "2025-10-24"
   }
   ```

   有 `src/SUMMARY.md` 的课会被构建；`status: "planned"` 且没有 SUMMARY 的
   课只出现在门面里，显示“待认领”，主按钮变成 GitHub Issue 认领入口。

2. 写 `book.toml`（可以直接复制 `courses/industrial-internet/book.toml`，改标题和
   `edit-url-template`）。

3. 写 `src/SUMMARY.md`。**Part 标题决定门面里的内容类型标签**：

   | Part | kind | 门面显示 |
   | --- | --- | --- |
   | `# 开始` | `intro` | 开始 |
   | `# 讲义` | `notes` | 讲义 |
   | `# 图谱` | `map` | 图谱 |
   | `# 速查` | `cheatsheet` | 速查 |
   | `# 真题` / `# 练习` | `exam` | 真题 |
   | `# 附录` | `appendix` | 附录 |

   没有 `SUMMARY.md` 的课按“待认领”处理。

4. `npm run build`。门面会自动出现新课程，不需要改 Gleam 代码。

## 课程自定义 UI

课程可以带自己的页面：一个 Lustre 程序 + 一个 mdbook 挂载页。没有视图注册表——
多一个页面就多一个入口文件，多一门课就多一个模块。

1. 在 `meta.json` 里声明入口：

   ```json
   "ui": [{ "entry": "industrial-internet-graph", "out": "graph.js" }]
   ```

   `entry` 对应 `site/scripts/entries/<entry>.js`，`out` 是 `ui/dist/` 下的文件名。
   `gen-catalog.mjs` 把 `ui` 带进 `catalog.json`，`bundle.mjs` 按它逐个打包。

2. 入口只有一句 `mount`：

   ```js
   import { mount } from "../../build/dev/javascript/catalog/courses/industrial_internet/graph.mjs";

   mount("#graph-root");
   ```

3. Gleam 模块放在 `site/src/courses/<slug>/`：

   | 文件 | 作用 |
   | --- | --- |
   | `concepts.gleam` | 概念、超边、题号数据 + 查询 + 序列化 |
   | `graph.gleam` | MVU（init / update / view）与 `mount` |
   | `cyto.gleam` / `cyto_ffi.mjs` | Cytoscape 边界：画布、状态、键盘 |

   数据写在 Gleam 里，类型即校验；超边引用完整性、id 唯一、空定义、题号越界由
   `site/test/concepts_test.gleam` 兜住，`cd site && npm test` 可跑。

4. 挂载页是 `courses/<slug>/src/graph.md`：留 `<div id="graph-root">` 和画布
   `<div id="graph-canvas">`，加一行 `<script type="module" src="ui/graph.js">`。
   画布不放进 Lustre 的渲染子树，MVU 重画时不会把 Cytoscape 的 DOM 换掉。

5. 打印与无 JS 用的总表由 `site/scripts/gen-graph-table.mjs` 从同一份 Gleam 数据
   生成到 `src/graph-table.html`（被 `.gitignore`），页面用 mdbook 的
   `{{#include}}` 引入。所以构建顺序是先 `gleam build`、再 `bundle` / 生成片段、
   最后 `mdbook build`。图页样式在 `courses/<slug>/theme/graph.css`。

当前只接了工业互联网的图谱页，数据还是占位的一小片：六簇约 90 个概念、题号与
完整超边是下一轮内容工作。设计取舍见 [docs/course-ui.md](docs/course-ui.md)。

## 交互与 URL

门面只做三件事：选课、筛选、跳章节。所有状态都在 URL 里，**不写任何本地存储**
（没有 localStorage、没有 cookie、没有进度上报）：

| 参数 | 含义 | 例子 |
| --- | --- | --- |
| `?c=<slug>` | 选中的课程 | `?c=industrial-internet` |
| `?q=<text>` | 打开命令面板并带上查询 | `?q=齿轮` |
| `?kind=<kind>` | 只看含某类内容的课程 | `?kind=exam` |

刷新会还原；把链接发给同学，对方看到的是同一屏。关闭面板会清掉 `?q=`。

深浅色跟随系统，门面和书保持一致；没有主题开关（门面不写存储）。

键盘只有四个：`Ctrl K` / `⌘K` / `/` 打开，`↑↓` 选择，`↵` 打开，`Esc` 关闭。
其余动作（只看真题、复制链接、编辑、报告问题、打印）都在命令面板里，不铺快捷键。

更完整的设计说明见 [docs/design.md](docs/design.md)。

## 内容写作

- 章节是 `courses/<slug>/src/*.md`，在 `SUMMARY.md` 里排序
- 图片放 `src/assets/figs/`，Markdown 里写 `![说明](assets/figs/xxx.png)`
- 公式用 `$...$` / `$$...$$`；书内使用仓库自带的 MathJax（`site/public/vendor/`），
  不依赖 CDN
- 打印/存 PDF 由 mdbook 自带样式负责
- 书页右下角有一个返回门面的浮动胶囊，由 `theme/course.js` 注入

## 部署

`main` 分支推送到 GitHub Actions，构建 `dist/` 后由 Pages 发布。
仓库 **Settings → Pages → Source** 选 **GitHub Actions** 即可。

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。一句话版本：开目录、写 SUMMARY、写
markdown、跑构建；门面会自动收录。
