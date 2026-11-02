// 图谱页的浏览器边界。画布归 Cytoscape（cyto_ffi.mjs），状态归 MVU（graph.gleam）。
// 这里只声明外部函数，不含状态；唯一的长期对象是 Cytoscape 实例本身。

@external(javascript, "./cyto_ffi.mjs", "init")
pub fn init(
  container: String,
  data: String,
  on_select: fn(String) -> Nil,
  on_activate: fn(String) -> Nil,
) -> Nil

@external(javascript, "./cyto_ffi.mjs", "apply")
pub fn apply(state: String) -> Nil

@external(javascript, "./cyto_ffi.mjs", "focus")
pub fn focus(id: String) -> Nil

@external(javascript, "./cyto_ffi.mjs", "destroy")
pub fn destroy() -> Nil

@external(javascript, "./cyto_ffi.mjs", "read_focus")
pub fn read_focus() -> String

@external(javascript, "./cyto_ffi.mjs", "replace_focus")
pub fn replace_focus(id: String) -> Nil

@external(javascript, "./cyto_ffi.mjs", "focus_search")
pub fn focus_search() -> Nil

@external(javascript, "./cyto_ffi.mjs", "register_keys")
pub fn register_keys(on_key: fn(String) -> Nil) -> Nil
