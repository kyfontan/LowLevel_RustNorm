#![feature(rustc_private)]

extern crate rustc_ast;
extern crate rustc_lint;
extern crate rustc_session;
extern crate rustc_span;

use rustc_ast::ast::{
    Block, Expr, ExprKind, FieldDef, Item, ItemKind, Local, LocalKind, PatKind, Stmt, StmtKind,
    Ty, TyKind, VariantData,
};
use rustc_ast::token::LitKind as TokenLitKind;
use rustc_lint::{EarlyContext, EarlyLintPass, LintContext};
use rustc_session::{declare_lint, impl_lint_pass};
use rustc_span::{Span, Symbol};
use serde::Deserialize;

dylint_linting::dylint_library!();

const VEC_WITH_CAPACITY_PATHS: &[&[&str]] = &[
    &["Vec", "with_capacity"],
    &["vec", "Vec", "with_capacity"],
];
const VEC_NEW_PATHS: &[&[&str]] = &[&["Vec", "new"], &["vec", "Vec", "new"]];
const LINKED_LIST_NEW_PATHS: &[&[&str]] = &[
    &["LinkedList", "new"],
    &["collections", "LinkedList", "new"],
    &["std", "collections", "LinkedList", "new"],
];

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
struct Config {
    small_vec_capacity_threshold: u64,
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
        lint_small_vec_with_capacity(cx, expr, &self.config);
        lint_linked_list_new(cx, expr);
    }

    fn check_block(&mut self, cx: &EarlyContext<'_>, block: &Block) {
        lint_vec_new_then_push(cx, block, &self.config);
    }

    fn check_item(&mut self, cx: &EarlyContext<'_>, item: &Item) {
        lint_field_order_by_size(cx, item);
    }
}

fn lint_small_vec_with_capacity(cx: &EarlyContext<'_>, expr: &Expr, config: &Config) {
    let Some(capacity) = small_vec_with_capacity_literal(expr) else {
        return;
    };

    if capacity > config.small_vec_capacity_threshold {
        return;
    }

    let mut diag = cx.sess().dcx().struct_span_warn(
        expr.span,
        format!("small constant capacity ({capacity}) in `Vec::with_capacity`"),
    );
    diag.help(
        "for tiny fixed-capacity collections, review `[T; N]`, `SmallVec<[T; N]>`, or `ArrayVec<T, N>` to reduce heap traffic and improve locality",
    );
    diag.emit();
}

fn lint_linked_list_new(cx: &EarlyContext<'_>, expr: &Expr) {
    if !is_linked_list_new(expr) {
        return;
    }

    let mut diag = cx
        .sess()
        .dcx()
        .struct_span_warn(expr.span, "`LinkedList::new()` used here");
    diag.help(
        "prefer contiguous storage (`Vec`, array, `SmallVec`, `VecDeque`) unless you benchmarked and proved a linked list is better",
    );
    diag.emit();
}

fn lint_vec_new_then_push(cx: &EarlyContext<'_>, block: &Block, config: &Config) {
    let min_pushes = config.vec_new_then_push_min_pushes;
    let stmts = &block.stmts;

    if min_pushes == 0 {
        return;
    }

    for (index, stmt) in stmts.iter().enumerate() {
        let Some((binding, span)) = local_vec_new_binding(stmt) else {
            continue;
        };

        let pushes = consecutive_push_count(binding, &stmts[index + 1..]);
        if pushes < min_pushes {
            continue;
        }

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

fn lint_field_order_by_size(cx: &EarlyContext<'_>, item: &Item) {
    let ItemKind::Struct(_, _, variant) = &item.kind else {
        return;
    };

    let VariantData::Struct { fields, .. } = variant else {
        return;
    };

    if fields.len() < 2 {
        return;
    }

    let Some(sized_fields) = sized_named_fields(fields) else {
        return;
    };

    let Some((previous, previous_size, current, current_size)) =
        first_field_order_violation(&sized_fields)
    else {
        return;
    };

    let previous_name = field_name(previous);
    let current_name = field_name(current);

    let mut diag = cx.sess().dcx().struct_span_warn(
        current.span,
        format!(
            "field `{current_name}` ({current_size} bytes) comes after larger field `{previous_name}` ({previous_size} bytes)"
        ),
    );
    diag.help(
        "reorder fields from larger fixed-size primitives to smaller ones when representation and API constraints allow it",
    );
    diag.note(
        "this lint is intentionally conservative and currently checks only named structs made entirely of known primitive scalar fields",
    );
    diag.emit();
}

fn small_vec_with_capacity_literal(expr: &Expr) -> Option<u64> {
    let ExprKind::Call(callee, args) = &expr.kind else {
        return None;
    };

    if args.len() != 1 || !matches_any_path_suffix(callee, VEC_WITH_CAPACITY_PATHS) {
        return None;
    }

    integer_literal(&args[0])
}

fn is_linked_list_new(expr: &Expr) -> bool {
    let ExprKind::Call(callee, args) = &expr.kind else {
        return false;
    };

    args.is_empty() && matches_any_path_suffix(callee, LINKED_LIST_NEW_PATHS)
}

fn local_vec_new_binding(stmt: &Stmt) -> Option<(Symbol, Span)> {
    let StmtKind::Let(local) = &stmt.kind else {
        return None;
    };

    let binding = local_binding_name(local)?;
    let init = local_init_expr(local)?;

    is_vec_new_expr(init).then_some((binding, stmt.span))
}

fn local_init_expr(local: &Local) -> Option<&Expr> {
    match &local.kind {
        LocalKind::Decl => None,
        LocalKind::Init(expr) => Some(expr),
        LocalKind::InitElse(expr, _) => Some(expr),
    }
}

fn consecutive_push_count(binding: Symbol, stmts: &[Stmt]) -> usize {
    stmts
        .iter()
        .take_while(|stmt| is_push_stmt_for(stmt, binding))
        .count()
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

    if method_call.seg.ident.name.as_str() != "push" || method_call.args.len() != 1 {
        return false;
    }

    is_path_expr_named(&method_call.receiver, binding)
}

fn is_vec_new_expr(expr: &Expr) -> bool {
    let ExprKind::Call(callee, args) = &expr.kind else {
        return false;
    };

    args.is_empty() && matches_any_path_suffix(callee, VEC_NEW_PATHS)
}

fn integer_literal(expr: &Expr) -> Option<u64> {
    let ExprKind::Lit(token_lit) = &expr.kind else {
        return None;
    };

    match token_lit.kind {
        TokenLitKind::Integer => token_lit.symbol.as_str().replace('_', "").parse::<u64>().ok(),
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

fn matches_any_path_suffix(expr: &Expr, candidates: &[&[&str]]) -> bool {
    candidates.iter().any(|suffix| path_suffix_of_expr(expr, suffix))
}

fn path_suffix_of_expr(expr: &Expr, suffix: &[&str]) -> bool {
    let ExprKind::Path(_, path) = &expr.kind else {
        return false;
    };

    let collected: Vec<&str> = path.segments.iter().map(|seg| seg.ident.name.as_str()).collect();
    collected.len() >= suffix.len() && &collected[collected.len() - suffix.len()..] == suffix
}

fn field_name(field: &FieldDef) -> String {
    field
        .ident
        .as_ref()
        .map(|ident| ident.name.to_string())
        .unwrap_or_else(|| "<field>".to_string())
}

fn sized_named_fields(fields: &[FieldDef]) -> Option<Vec<(&FieldDef, usize)>> {
    fields
        .iter()
        .map(|field| Some((field, primitive_type_size(&field.ty)?)))
        .collect()
}

fn first_field_order_violation<'a>(
    fields: &'a [(&'a FieldDef, usize)],
) -> Option<(&'a FieldDef, usize, &'a FieldDef, usize)> {
    let mut previous = *fields.first()?;

    for current in fields.iter().copied().skip(1) {
        if current.1 > previous.1 {
            return Some((previous.0, previous.1, current.0, current.1));
        }

        previous = current;
    }

    None
}

fn primitive_type_size(ty: &Ty) -> Option<usize> {
    let TyKind::Path(_, path) = &ty.kind else {
        return None;
    };

    let segment = path.segments.last()?;
    match segment.ident.name.as_str() {
        "u128" | "i128" => Some(16),
        "u64" | "i64" | "f64" => Some(8),
        "u32" | "i32" | "f32" => Some(4),
        "u16" | "i16" => Some(2),
        "u8" | "i8" | "bool" => Some(1),
        _ => None,
    }
}


