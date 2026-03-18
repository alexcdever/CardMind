use serde::{Deserialize, Serialize};
use std::fs;
use syn::spanned::Spanned;
use syn::visit::Visit;
use syn::{parse_file, BinOp, Expr, File, Item, Local, ReturnType, Stmt, Type};
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
                    "is_none" | "is_some" | "is_ok" | "is_err" | "is_empty" | "is_not_empty" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "null",
                            line,
                            &method_name,
                            &format!("Null/Option check: {}", method_name),
                        );
                    }
                    "unwrap" | "expect" | "unwrap_or" | "unwrap_or_else" | "unwrap_or_default" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "null",
                            line,
                            &method_name,
                            &format!("Potential panic: {}", method_name),
                        );
                    }
                    "clone" | "to_string" | "to_owned" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "lifecycle",
                            line,
                            &method_name,
                            &format!("Ownership operation: {}", method_name),
                        );
                    }
                    "push" | "pop" | "insert" | "remove" | "extend" | "append" | "clear" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "collection",
                            line,
                            &method_name,
                            &format!("Collection mutation: {}", method_name),
                        );
                    }
                    "len" | "capacity" | "get" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "collection",
                            line,
                            &method_name,
                            &format!("Collection access: {}", method_name),
                        );
                    }
                    "await" | "then" | "map" | "and_then" | "or_else" => {
                        let line = expr_call.method.span().start().line;
                        self.add_boundary(
                            "async",
                            line,
                            &method_name,
                            &format!("Async/Future operation: {}", method_name),
                        );
                    }
                    _ => {}
                }
            }
            // for 循环
            Expr::ForLoop(expr_for) => {
                let line = expr_for.for_token.span.start().line;
                self.add_boundary("condition", line, "for", "For loop");
            }
            // while 循环
            Expr::While(expr_while) => {
                let line = expr_while.while_token.span.start().line;
                self.add_boundary("condition", line, "while", "While loop");
            }
            // loop 循环
            Expr::Loop(expr_loop) => {
                let line = expr_loop.loop_token.span.start().line;
                self.add_boundary("condition", line, "loop", "Infinite loop");
            }
            // 闭包
            Expr::Closure(expr_closure) => {
                let line = expr_closure.span().start().line;
                self.add_boundary("lifecycle", line, "closure", "Closure expression");
            }
            // 数组/元组索引访问
            Expr::Index(expr_index) => {
                let line = expr_index.span().start().line;
                self.add_boundary("collection", line, "index", "Index access");
            }
            // 引用
            Expr::Reference(expr_ref) => {
                let line = expr_ref.span().start().line;
                self.add_boundary("lifecycle", line, "&", "Borrow operation");
            }
            // 结构体实例化
            Expr::Struct(expr_struct) => {
                let line = expr_struct.span().start().line;
                self.add_boundary("lifecycle", line, "struct", "Struct instantiation");
            }
            // 数组字面量
            Expr::Array(expr_array) => {
                let line = expr_array.span().start().line;
                self.add_boundary("collection", line, "[]", "Array literal");
            }
            // 块表达式
            Expr::Block(expr_block) => {
                let line = expr_block.span().start().line;
                self.add_boundary("lifecycle", line, "{}", "Block expression");
            }
            // 异步块
            Expr::Async(expr_async) => {
                let line = expr_async.async_token.span.start().line;
                self.add_boundary("async", line, "async", "Async block");
            }
            // await 表达式
            Expr::Await(expr_await) => {
                let line = expr_await.span().start().line;
                self.add_boundary("async", line, ".await", "Await expression");
            }
            // 二元表达式（运算、比较等）
            Expr::Binary(expr_binary) => {
                let line = expr_binary.span().start().line;
                match expr_binary.op {
                    BinOp::Div(_) | BinOp::Rem(_) => {
                        self.add_boundary(
                            "condition",
                            line,
                            "/ or %",
                            "Arithmetic operation - potential divide by zero",
                        );
                    }
                    BinOp::And(_) | BinOp::Or(_) => {
                        self.add_boundary("condition", line, "&& or ||", "Logical expression");
                    }
                    BinOp::Eq(_) | BinOp::Ne(_) => {
                        self.add_boundary("null", line, "== or !=", "Equality comparison");
                    }
                    BinOp::Lt(_) | BinOp::Gt(_) | BinOp::Le(_) | BinOp::Ge(_) => {
                        self.add_boundary("condition", line, "< > <= >=", "Comparison expression");
                    }
                    _ => {}
                }
            }
            // 类型转换
            Expr::Cast(expr_cast) => {
                let line = expr_cast.span().start().line;
                self.add_boundary("null", line, "as", "Type cast");
            }
            // 范围表达式
            Expr::Range(expr_range) => {
                let line = expr_range.span().start().line;
                self.add_boundary("collection", line, "..", "Range expression");
            }
            // 元组
            Expr::Tuple(expr_tuple) => {
                let line = expr_tuple.span().start().line;
                self.add_boundary("collection", line, "()", "Tuple literal");
            }
            // 字段访问
            Expr::Field(expr_field) => {
                let line = expr_field.span().start().line;
                self.add_boundary("collection", line, ".", "Field access");
            }
            // 函数调用
            Expr::Call(expr_call) => {
                let line = expr_call.span().start().line;
                self.add_boundary("lifecycle", line, "fn()", "Function call");
            }
            // 赋值操作
            Expr::Assign(expr_assign) => {
                let line = expr_assign.span().start().line;
                self.add_boundary("input", line, "=", "Assignment");
            }

            // 一元操作符 (!, -, *)
            Expr::Unary(expr_unary) => {
                let line = expr_unary.span().start().line;
                match expr_unary.op {
                    syn::UnOp::Deref(_) => {
                        self.add_boundary("lifecycle", line, "*", "Dereference");
                    }
                    syn::UnOp::Not(_) => {
                        self.add_boundary("condition", line, "!", "Logical not");
                    }
                    syn::UnOp::Neg(_) => {
                        self.add_boundary("condition", line, "-", "Negation");
                    }
                    _ => {}
                }
            }
            // 字面量
            Expr::Lit(expr_lit) => {
                let line = expr_lit.span().start().line;
                self.add_boundary("input", line, "literal", "Literal value");
            }
            // 路径表达式 (变量、常量等)
            Expr::Path(expr_path) => {
                let line = expr_path.span().start().line;
                self.add_boundary("input", line, "path", "Path expression");
            }
            // 数组重复 [x; n]
            Expr::Repeat(expr_repeat) => {
                let line = expr_repeat.span().start().line;
                self.add_boundary("collection", line, "[x; n]", "Array repeat");
            }
            // unsafe 块
            Expr::Unsafe(expr_unsafe) => {
                let line = expr_unsafe.span().start().line;
                self.add_boundary("exception", line, "unsafe", "Unsafe block");
            }
            // const 块
            Expr::Const(expr_const) => {
                let line = expr_const.span().start().line;
                self.add_boundary("lifecycle", line, "const", "Const block");
            }
            // 括号表达式
            Expr::Paren(expr_paren) => {
                let line = expr_paren.span().start().line;
                self.add_boundary("lifecycle", line, "()", "Parenthesized expression");
            }
            // 生成器表达式 (yield)
            Expr::Yield(expr_yield) => {
                let line = expr_yield.span().start().line;
                self.add_boundary("async", line, "yield", "Yield expression");
            }
            // break 表达式
            Expr::Break(expr_break) => {
                let line = expr_break.span().start().line;
                self.add_boundary("condition", line, "break", "Break statement");
            }
            // continue 表达式
            Expr::Continue(expr_continue) => {
                let line = expr_continue.span().start().line;
                self.add_boundary("condition", line, "continue", "Continue statement");
            }
            // if let 表达式
            Expr::Let(expr_let) => {
                let line = expr_let.span().start().line;
                self.add_boundary("null", line, "let", "Let expression");
            }
            // 宏调用
            Expr::Macro(expr_macro) => {
                let line = expr_macro.span().start().line;
                self.add_boundary("lifecycle", line, "macro!", "Macro invocation");
            }
            // try 块（实验性特性）
            Expr::TryBlock(expr_try_block) => {
                let line = expr_try_block.span().start().line;
                self.add_boundary("exception", line, "try {}", "Try block (experimental)");
            }
            // 原始地址操作符
            Expr::RawAddr(expr_raw_addr) => {
                let line = expr_raw_addr.span().start().line;
                self.add_boundary("lifecycle", line, "&raw", "Raw address-of operator");
            }
            // 推断的 const 泛型参数
            Expr::Infer(expr_infer) => {
                let line = expr_infer.span().start().line;
                self.add_boundary("input", line, "_", "Inferred const generic");
            }
            // 分组表达式
            Expr::Group(expr_group) => {
                let line = expr_group.span().start().line;
                self.add_boundary("lifecycle", line, "{}", "Expression grouping");
            }
            // return 表达式
            Expr::Return(expr_return) => {
                let line = expr_return.span().start().line;
                self.add_boundary("condition", line, "return", "Return expression");
            }
            // 原始 token 流
            Expr::Verbatim(_) => {
                // 无法获取准确 span，跳过
            }
            // include! 或其他内置宏
            _ => {}
        }

        // 继续遍历子表达式
        syn::visit::visit_expr(self, expr);
    }

    // 检测 return 语句
    fn visit_stmt(&mut self, stmt: &'ast Stmt) {
        match stmt {
            Stmt::Local(local) => {
                // 变量绑定
                let line = local.span().start().line;
                self.add_boundary("input", line, "let", "Variable binding");
            }
            Stmt::Item(item) => {
                // 处理内嵌的 item
                match item {
                    Item::Fn(item_fn) => {
                        let line = item_fn.sig.fn_token.span.start().line;
                        self.add_boundary("lifecycle", line, "fn", "Function definition");
                    }
                    Item::Struct(item_struct) => {
                        let line = item_struct.span().start().line;
                        self.add_boundary("lifecycle", line, "struct", "Struct definition");
                    }
                    Item::Enum(item_enum) => {
                        let line = item_enum.span().start().line;
                        self.add_boundary("lifecycle", line, "enum", "Enum definition");
                    }
                    Item::Impl(item_impl) => {
                        let line = item_impl.span().start().line;
                        self.add_boundary("lifecycle", line, "impl", "Implementation block");
                    }
                    Item::Trait(item_trait) => {
                        let line = item_trait.span().start().line;
                        self.add_boundary("lifecycle", line, "trait", "Trait definition");
                    }
                    Item::Const(item_const) => {
                        let line = item_const.span().start().line;
                        self.add_boundary("lifecycle", line, "const", "Constant definition");
                    }
                    Item::Static(item_static) => {
                        let line = item_static.span().start().line;
                        self.add_boundary("lifecycle", line, "static", "Static definition");
                    }
                    Item::Type(item_type) => {
                        let line = item_type.span().start().line;
                        self.add_boundary("lifecycle", line, "type", "Type alias");
                    }
                    Item::Mod(item_mod) => {
                        let line = item_mod.span().start().line;
                        self.add_boundary("lifecycle", line, "mod", "Module definition");
                    }
                    Item::Use(item_use) => {
                        let line = item_use.span().start().line;
                        self.add_boundary("lifecycle", line, "use", "Use declaration");
                    }
                    Item::ExternCrate(item_extern) => {
                        let line = item_extern.span().start().line;
                        self.add_boundary("lifecycle", line, "extern crate", "External crate");
                    }
                    Item::Macro(item_macro) => {
                        let line = item_macro.span().start().line;
                        self.add_boundary("lifecycle", line, "macro_rules!", "Macro definition");
                    }
                    Item::ForeignMod(item_foreign) => {
                        let line = item_foreign.span().start().line;
                        self.add_boundary("lifecycle", line, "extern {}", "Foreign module block");
                    }
                    Item::TraitAlias(item_trait_alias) => {
                        let line = item_trait_alias.span().start().line;
                        self.add_boundary("lifecycle", line, "trait", "Trait alias");
                    }
                    Item::Union(item_union) => {
                        let line = item_union.span().start().line;
                        self.add_boundary("lifecycle", line, "union", "Union definition");
                    }
                    Item::Verbatim(_) => {
                        // 无法获取准确 span，跳过
                    }
                    _ => {}
                }
            }
            Stmt::Expr(expr, _) => {
                // 表达式语句
                if matches!(expr, Expr::Return(_)) {
                    let line = expr.span().start().line;
                    self.add_boundary("condition", line, "return", "Return statement");
                }
            }
            _ => {}
        }
        syn::visit::visit_stmt(self, stmt);
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

                // 检查函数参数
                for input in &item_fn.sig.inputs {
                    if let syn::FnArg::Typed(pat_type) = input {
                        if type_contains_result_or_option(&pat_type.ty) {
                            let line = item_fn.sig.fn_token.span.start().line;
                            visitor.add_boundary(
                                "exception",
                                line,
                                "Result/Option param",
                                "Function parameter is Result/Option",
                            );
                        }
                    }
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
