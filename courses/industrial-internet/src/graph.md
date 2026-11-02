# 概念图谱

概念在这里有唯一入口：一个节点一处定义、一组关系、一串题号。点节点看细节，双击只看邻居，滚轮放大显示名称，`/` 搜索，`j` `k` 移动，`Esc` 返回。定位用查询串 `?focus=<id>`，分享链接就能落到同一个概念。

<div class="graph-page">
<div id="graph-canvas" role="img" aria-label="概念图谱画布"></div>
<div id="graph-root"></div>
</div>

<script type="module" src="ui/graph.js"></script>

<noscript>
<p>图谱需要 JavaScript。下面这张总表是同一份数据，可以照常读、照常链接。</p>
</noscript>

## 概念与关系总表

打印时画布和侧栏隐藏，只留这两张表：概念表给出定义、机制与题号，关系总表给出每条超边的类型、成员与格子。它们和图出自同一份 Gleam 数据，不需要手工同步。

{{#include graph-table.html}}
