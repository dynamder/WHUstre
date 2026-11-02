import { mount } from "../../build/dev/javascript/catalog/courses/industrial_internet/graph.mjs";

// 课程 UI 入口只有一句：把 MVU 装到页面留好的挂载点上。
// 多一个页面就多一个入口文件，多一门课就多一个模块；没有注册表。
mount("#graph-root");
