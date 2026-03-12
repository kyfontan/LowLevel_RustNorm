# rust-perf-norm

A global Rust performance lint setup built around:

- **Clippy** for standard lints
- **Dylint** for custom machine-oriented lints
- **VS Code** integration so the checks appear directly in the editor

This starter kit is designed to be:

- **global by default** across your Rust projects
- **easy to disable per project**
- focused on **cache locality, allocation discipline, and data layout awareness**

## What is included

- `machine-oriented-lints/` — a Dylint library with custom lints
- `install/install.sh` — bootstrap script for Unix-like systems
- `templates/` — snippets for per-project activation and disabling
- `snippets/rust.json` — VS Code snippet for crate-level Clippy policy
- `vscode/settings.json` — recommended global VS Code settings

## Custom lints in this starter

### 1. `small_vec_with_capacity`
Warns when code uses `Vec::with_capacity(N)` with a small compile-time constant.

Why: small fixed-size collections often have better locality and lower allocation overhead when represented with:

- `[T; N]`
- `SmallVec<[T; N]>`
- `ArrayVec<T, N>`

### 2. `vec_new_then_push`
Warns when a `Vec::new()` is immediately followed by consecutive `.push(...)` calls in the same block.

Why: that pattern tends to reallocate unless capacity was reserved up front. Even when amortized complexity is good, the hot-path cost includes allocator traffic and copies.

### 3. `linked_list_new`
Warns when `LinkedList::new()` is used.

Why: linked lists are usually hostile to CPU caches because traversal requires pointer chasing instead of contiguous reads.

## Install

```bash
bash install/install.sh
```

That script does three things:

1. installs `cargo-dylint` and `dylint-link`
2. adds a global Cargo alias `cargo pc`
3. installs the VS Code Rust snippet in the right user folder for your OS (`~/.config/Code/User/snippets/` on Linux, `~/Library/Application Support/Code/User/snippets/` on macOS) and prints the Dylint workspace snippet to add to any project that should opt in

## Use globally in VS Code

Copy the contents of `vscode/settings.json` into your user settings.

## Enable in a project

Put this in the target workspace's `dylint.toml`:

```toml
[workspace.metadata.dylint]
libraries = [
  { path = "/ABSOLUTE/PATH/TO/rust-perf-norm/machine-oriented-lints" },
]

[machine_oriented_lints]
small_vec_capacity_threshold = 64
vec_new_then_push_min_pushes = 2
```

Then run:

```bash
cargo dylint --all
```

Or, after the global Cargo alias is installed:

```bash
cargo pc
```

## Disable for one project

Option 1: do not include the Dylint workspace metadata.

Option 2: keep the library loaded but silence a specific lint inside a crate:

```rust
#![allow(small_vec_with_capacity)]
#![allow(vec_new_then_push)]
#![allow(linked_list_new)]
```

Option 3: allow at narrower scope:

```rust
#[allow(vec_new_then_push)]
fn setup() {
    let mut v = Vec::new();
    v.push(1);
    v.push(2);
}
```

## Notes

This repository is a **starter**. The lint code is meant to be extended with more rules over time, especially around:

- allocation inside hot paths
- field ordering and padding
- cache-sensitive indirection patterns
- APIs that take `&Vec<T>` instead of `&[T]`
- fixed-size buffers that should stay on the stack
