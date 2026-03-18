use serde::{Deserialize, Serialize};
use std::fs;
use syn::visit::Visit;
use syn::{parse_file, Expr, File, Item, ReturnType, Type};
use walkdir::WalkDir;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Boundary {
    boundary_type: String,
    file_path: String,
    line_number: usize,
    code_snippet: String,
    description: String,
}

struct BoundaryVisitor {
    boundaries: Vec<Boundary>,
    file_path: String,
}

impl BoundaryVisitor {
    fn new(file_path: String) -> Self {
        BoundaryVisitor {
            boundaries: Vec::new(),
            file_path,
        }
    }

    fn add_boundary(&mut self, boundary_type: &str, line: usize, code: &str, desc: &str) {
        let snippet = if code.len() > 50 {
            format!("{}...", &code[..50])
        } else {
            code.to_string()
        };

        self.boundaries.push(Boundary {
            boundary_type: boundary_type.to_string(),
            file_path: self.file_path.clone(),
            line_number: line,
            code_snippet: snippet,
            description: desc.to_string(),
        });
    }
}

impl<'ast> Visit<'ast> for BoundaryVisitor {
    fn visit_expr(&mut self, expr: &'ast Expr) {
        match expr {
            // if 表达式
            Expr::If(expr_if) => {
                let line = expr_if.if_token.span.start().line;
                self.add_boundary("condition", line, "if", "If statement condition");
            }
            // match 表达式
            Expr::Match(expr_match) => {
                let line = expr_match.match_token.span.start().line;
                self.add_boundary("condition", line, "match", "Match expression");
            }
            // ? 操作符 (Try)
            Expr::Try(expr_try) => {
                let line = expr_try.question_token.span.start().line;
                self.add_boundary(
                    "exception",
                    line,
                    "?",
                    "Try operator (?), may return early on error",
                );
            }
            // 方法调用（检查 is_none, is_ok 等）
            Expr::MethodCall(expr_call) => {
                let method_name = expr_call.method.to_string();
                match method_name.as_str() {
                    "is_none" | "is_some" | "is_ok" | "is_err" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "null",
                            line,
                            &method_name,
                            &format!("Null/Option check: {}", method_name),
                        );
                    }
                    "unwrap" | "expect" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "null",
                            line,
                            &method_name,
                            &format!("Potential panic: {}", method_name),
                        );
                    }
                    _ => {}
                }
            }
            _ => {}
        }

        // 继续遍历子表达式
        syn::visit::visit_expr(self, expr);
    }
}

fn type_contains_result_or_option(_ty: &Type) -> bool {
    // 简化的检查：暂时不深入检测类型
    // 实际应该递归检查类型结构
    false
}

fn scan_file(file_path: &str) -> Vec<Boundary> {
    let content = match fs::read_to_string(file_path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Warning: Failed to read {}: {}", file_path, e);
            return Vec::new();
        }
    };

    let syntax_tree = match parse_file(&content) {
        Ok(tree) => tree,
        Err(e) => {
            eprintln!("Warning: Failed to parse {}: {}", file_path, e);
            return Vec::new();
        }
    };

    let mut visitor = BoundaryVisitor::new(file_path.to_string());
    visitor.visit_file(&syntax_tree);

    // 额外扫描：检查函数参数中的 Result/Option 类型
    scan_items_for_types(&syntax_tree, &mut visitor);

    visitor.boundaries
}

fn scan_items_for_types(file: &File, visitor: &mut BoundaryVisitor) {
    for item in &file.items {
        match item {
            Item::Fn(item_fn) => {
                // 检查函数返回类型
                match &item_fn.sig.output {
                    ReturnType::Default => {}
                    ReturnType::Type(_, ty) => {
                        if type_contains_result_or_option(ty) {
                            let line = item_fn.sig.fn_token.span.start().line;
                            visitor.add_boundary(
                                "exception",
                                line,
                                "Result/Option",
                                "Function returns Result/Option, caller must handle",
                            );
                        }
                    }
                }

                // 检查函数参数（简化版）
                for _input in &item_fn.sig.inputs {
                    // TODO: 更精确地检测 Result/Option 参数类型
                    // 暂时跳过，避免复杂的类型匹配
                }
            }
            _ => {}
        }
    }
}

fn main() {
    // 获取项目根目录
    // 如果在 cargo 运行环境中，从 manifest 目录开始找
    let current_dir = std::env::current_dir().unwrap();

    // 尝试找到包含 rust/src 的目录
    let project_root = if current_dir.join("rust/src").exists() {
        current_dir
    } else if current_dir.parent().unwrap().join("rust/src").exists() {
        current_dir.parent().unwrap().to_path_buf()
    } else if current_dir.ancestors().any(|p| p.join("rust/src").exists()) {
        current_dir
            .ancestors()
            .find(|p| p.join("rust/src").exists())
            .unwrap()
            .to_path_buf()
    } else {
        // 默认使用当前目录
        current_dir
    };

    let rust_src = project_root.join("rust/src");

    if !rust_src.exists() {
        eprintln!("Error: rust/src directory not found at {:?}", rust_src);
        std::process::exit(1);
    }

    let mut all_boundaries: Vec<Boundary> = Vec::new();

    // 遍历 rust/src 目录
    for entry in WalkDir::new(&rust_src)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .filter(|e| e.path().extension().map(|ext| ext == "rs").unwrap_or(false))
    {
        let path = entry.path();
        let relative_path = path.strip_prefix(&project_root).unwrap_or(path);
        let file_boundaries = scan_file(path.to_str().unwrap());

        // 更新路径为相对路径
        let boundaries: Vec<Boundary> = file_boundaries
            .into_iter()
            .map(|mut b| {
                b.file_path = relative_path.to_string_lossy().to_string();
                b
            })
            .collect();

        all_boundaries.extend(boundaries);
    }

    // 输出 JSON
    let output = serde_json::to_string_pretty(&all_boundaries).unwrap();
    println!("{}", output);
}
