import gleeunit

// gleeunit 的约定入口模块：test/<package>_test.gleam。
// 具体用例放在同目录的其它 *_test.gleam 里。
pub fn main() {
  gleeunit.main()
}
