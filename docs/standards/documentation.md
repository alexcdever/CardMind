# Fractal Documentation Standard

核心规则：任何功能、架构、写法变更完成后，必须更新对应 `DIR.md` 与相关文件头注释。

目录规则：每个目录必须包含 `DIR.md`（根目录也需要）。首行声明“目录变更需更新本文件”。正文 3 行以内说明定位，随后列出文件清单（文件名 + 地位 + 功能）。

文件规则：仅对 `.dart` 与 `.rs` 文件适用。文件头三行注释说明 `input`、`output`、`pos`，并明确“修改本文件需同步更新文件头与所属 `DIR.md`”。

排除项：构建物与第三方依赖不纳入该规范：`build/`、`rust/target/`、`ios/Pods/`、`android/.gradle/`、`linux/build/`、`macos/Build/`、`windows/build/`、`pubspec.lock`、`lib/**.g.dart`、`lib/**.freezed.dart`。

校验：运行 `dart run tool/fractal_doc_check.dart --base <commit>`。
