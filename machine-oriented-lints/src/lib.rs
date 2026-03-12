#![feature(rustc_private)]

extern crate rustc_ast;
extern crate rustc_lint;
extern crate rustc_session;
extern crate rustc_span;

use rustc_ast::ast::{Block, Expr, ExprKind, Local, LocalKind, PatKind, Stmt, StmtKind};
use rustc_ast::token::LitKind as TokenLitKind;
use rustc_lint::{EarlyContext, EarlyLintPass, LintContext};
use rustc_session::{declare_lint, impl_lint_pass};
use rustc_span::{Span, Symbol};
use serde::Deserialize;

dylint_linting::dylint_library!();

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
struct Config {
    small_vec_capacity_threshold: u128,
    vec_new_then_push_min_pushes: usize,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            small_vec_capacity_threshold: 64,
            vec_new_then_push_min_pushes: 2,
        }
    }
}

declare_lint! {
    pub SMALL_VEC_WITH_CAPACITY,
    Warn,
    "Vec::with_capacity(N) with a small compile-time constant; review array/SmallVec/ArrayVec instead"
}

declare_lint! {
    pub VEC_NEW_THEN_PUSH,
    Warn,
    "Vec::new() followed by immediate consecutive pushes; reserve capacity up front"
}

declare_lint! {
    pub LINKED_LIST_NEW,
    Warn,
    "construction of LinkedList, which is usually hostile to cache locality"
}

declare_lint! {
    pub FIELD_ORDER_BY_SIZE,
    Warn,
    "struct fields are not ordered by decreasing size, which can introduce padding"
}

#[derive(Default)]
struct MachineOrientedLints {
    config: Config,
}

impl MachineOrientedLints {
    fn new() -> Self {
        Self {
            config: dylint_linting::config_or_default(env!("CARGO_PKG_NAME")),
        }
    }
}

impl_lint_pass!(MachineOrientedLints => [
    SMALL_VEC_WITH_CAPACITY,
    VEC_NEW_THEN_PUSH,
    LINKED_LIST_NEW,
    FIELD_ORDER_BY_SIZE,
]);

#[unsafe(no_mangle)]
pub fn register_lints(sess: &rustc_session::Session, lint_store: &mut rustc_lint::LintStore) {
    dylint_linting::init_config(sess);

    lint_store.register_lints(&[
        SMALL_VEC_WITH_CAPACITY,
        VEC_NEW_THEN_PUSH,
        LINKED_LIST_NEW,
        FIELD_ORDER_BY_SIZE,
    ]);

    lint_store.register_early_pass(|| Box::new(MachineOrientedLints::new()));
}

impl EarlyLintPass for MachineOrientedLints {
    fn check_expr(&mut self, cx: &EarlyContext<'_>, expr: &Expr) {
        if let Some(capacity) = small_vec_with_capacity_literal(expr) {
            if capacity <= self.config.small_vec_capacity_threshold {
                let mut diag = cx.sess().dcx().struct_span_warn(
                    expr.span,
                    format!("small constant capacity ({capacity}) in `Vec::with_capacity`"),
                );
                diag.help(
                    "for tiny fixed-capacity collections, review `[T; N]`, `SmallVec<[T; N]>`, or `ArrayVec<T, N>` to reduce heap traffic and improve locality",
                );
                diag.emit();
            }
        }

        if is_linked_list_new(expr) {
            let mut diag = cx
                .sess()
                .dcx()
                .struct_span_warn(expr.span, "`LinkedList::new()` used here");
            diag.help(
                "prefer contiguous storage (`Vec`, array, `SmallVec`, `VecDeque`) unless you benchmarked and proved a linked list is better",
            );
            diag.emit();
        }
    }

    fn check_block(&mut self, cx: &EarlyContext<'_>, block: &Block) {
        let min_pushes = self.config.vec_new_then_push_min_pushes;
        let stmts = &block.stmts;

        for i in 0..stmts.len() {
            let Some((binding, span)) = local_vec_new_binding(&stmts[i]) else {
                continue;
            };

            let pushes = consecutive_push_count(binding, &stmts[i + 1..]);
            if pushes >= min_pushes {
                let mut diag = cx.sess().dcx().struct_span_warn(
                    span,
                    format!("`Vec::new()` is followed by {pushes} consecutive `push` calls"),
                );
                diag.help(format!(
                    "prefer `Vec::with_capacity({pushes})` or a fixed-capacity stack-backed representation when size is known"
                ));
                diag.emit();
            }
        }
    }

    fn check_item(&mut self, cx: &EarlyContext<'_>, item: &rustc_ast::ast::Item) {
    use rustc_ast::ast::ItemKind;

    let ItemKind::Struct(_, _, def) = &item.kind else {
        return;
    };

    let mut last_size = usize::MAX;

    for field in def.fields() {
        let size = approx_type_size(&field.ty);

        if size > last_size {
            let mut diag = cx.sess().dcx().struct_span_warn(
                field.span,
                "struct fields should be ordered by decreasing size to reduce padding",
            );

            diag.help(
                "reorder fields from largest to smallest types (u64 -> u32 -> u16 -> u8)",
            );

            diag.emit();

            break;
        }

        last_size = size;
    }
}
}

fn small_vec_with_capacity_literal(expr: &Expr) -> Option<u128> {
    let ExprKind::Call(callee, args) = &expr.kind else {
        return None;
    };

    if args.len() != 1 {
        return None;
    }

    if !path_suffix_of_expr(callee, &["Vec", "with_capacity"])
        && !path_suffix_of_expr(callee, &["vec", "Vec", "with_capacity"])
    {
        return None;
    }

    integer_literal(&args[0])
}

fn is_linked_list_new(expr: &Expr) -> bool {
    let ExprKind::Call(callee, args) = &expr.kind else {
        return false;
    };

    if !args.is_empty() {
        return false;
    }

    path_suffix_of_expr(callee, &["LinkedList", "new"])
        || path_suffix_of_expr(callee, &["collections", "LinkedList", "new"])
        || path_suffix_of_expr(callee, &["std", "collections", "LinkedList", "new"])
}

fn local_vec_new_binding(stmt: &Stmt) -> Option<(Symbol, Span)> {
    let StmtKind::Let(local) = &stmt.kind else {
        return None;
    };

    let binding = local_binding_name(local)?;
    let init = local_init_expr(local)?;

    if is_vec_new_expr(init) {
        Some((binding, stmt.span))
    } else {
        None
    }
}

fn local_init_expr(local: &Local) -> Option<&Expr> {
    match &local.kind {
        LocalKind::Decl => None,
        LocalKind::Init(expr) => Some(&**expr),
        LocalKind::InitElse(expr, _) => Some(&**expr),
    }
}

fn consecutive_push_count(binding: Symbol, stmts: &[Stmt]) -> usize {
    let mut count = 0;

    for stmt in stmts {
        if is_push_stmt_for(stmt, binding) {
            count += 1;
        } else {
            break;
        }
    }

    count
}

fn is_push_stmt_for(stmt: &Stmt, binding: Symbol) -> bool {
    match &stmt.kind {
        StmtKind::Expr(expr) | StmtKind::Semi(expr) => is_push_call_for(expr, binding),
        _ => false,
    }
}

fn is_push_call_for(expr: &Expr, binding: Symbol) -> bool {
    let ExprKind::MethodCall(method_call) = &expr.kind else {
        return false;
    };

    if method_call.seg.ident.name != Symbol::intern("push") {
        return false;
    }

    if method_call.args.len() != 1 {
        return false;
    }

    is_path_expr_named(&method_call.receiver, binding)
}

fn is_vec_new_expr(expr: &Expr) -> bool {
    let ExprKind::Call(callee, args) = &expr.kind else {
        return false;
    };

    args.is_empty()
        && (path_suffix_of_expr(callee, &["Vec", "new"])
            || path_suffix_of_expr(callee, &["vec", "Vec", "new"]))
}

fn integer_literal(expr: &Expr) -> Option<u128> {
    let ExprKind::Lit(token_lit) = &expr.kind else {
        return None;
    };

    match token_lit.kind {
        TokenLitKind::Integer => {
            let raw = token_lit.symbol.as_str();
            let cleaned = raw.replace('_', "");
            cleaned.parse::<u128>().ok()
        }
        _ => None,
    }
}

fn local_binding_name(local: &Local) -> Option<Symbol> {
    let PatKind::Ident(_, ident, _) = &local.pat.kind else {
        return None;
    };

    Some(ident.name)
}

fn is_path_expr_named(expr: &Expr, name: Symbol) -> bool {
    let ExprKind::Path(_, path) = &expr.kind else {
        return false;
    };

    path.segments.len() == 1 && path.segments[0].ident.name == name
}

fn path_suffix_of_expr(expr: &Expr, suffix: &[&str]) -> bool {
    let ExprKind::Path(_, path) = &expr.kind else {
        return false;
    };

    path_suffix(path.segments.iter().map(|seg| seg.ident.name.as_str()), suffix)
}

fn path_suffix<'a>(segments: impl Iterator<Item = &'a str>, suffix: &[&str]) -> bool {
    let collected: Vec<&str> = segments.collect();
    collected.len() >= suffix.len()
        && &collected[collected.len() - suffix.len()..] == suffix
}

fn approx_type_size(ty: &rustc_ast::ast::Ty) -> usize {
    use rustc_ast::ast::TyKind;

    match &ty.kind {
        TyKind::Path(_, path) => {
            if let Some(seg) = path.segments.last() {
                match seg.ident.name.as_str() {
                    "u128" | "i128" => 16,
                    "u64" | "i64" | "f64" => 8,
                    "u32" | "i32" | "f32" => 4,
                    "u16" | "i16" => 2,
                    "u8" | "i8" | "bool" => 1,
                    _ => 8,
                }
            } else {
                8
            }
        }
        _ => 8,
    }
}
