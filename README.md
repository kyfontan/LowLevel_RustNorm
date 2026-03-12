# rust-perf-norm

**Rust performance lint toolkit focused on machine-level efficiency.**

`rust-perf-norm` provides a global Rust linting setup designed to help developers write code that is closer to the machine and more conscious of:

- CPU cache behavior
- allocation cost
- memory layout
- data locality
- unnecessary indirection

It combines:

- **Clippy** for standard lints
- **Dylint** for custom machine-oriented lints
- **VS Code integration** for real-time feedback inside the editor

The goal is to make performance-oriented practices **the default** across Rust projects.

---

# Philosophy

Modern CPUs are extremely fast at arithmetic but **slow at memory access**.

Typical latencies:

| Resource | Latency |
|---------|--------|
| L1 cache | ~1–4 cycles |
| L2 cache | ~10 cycles |
| L3 cache | ~40 cycles |
| RAM | ~100–300 cycles |

Many performance issues in modern software come from:

- heap allocations
- pointer chasing
- poor data locality
- unnecessary copies

`rust-perf-norm` focuses on **linting patterns that harm cache locality or allocation behavior**.

---

# Features

### Global by default

The setup is designed to work **across all Rust projects** using Cargo aliases and Dylint.

### Easy to disable per project

You can opt out entirely or silence specific lints locally.

### Editor integration

Warnings appear directly in **VS Code** during development.

---

# Repository Structure

```
rust-perf-norm/
│
├─ install/
│  ├─ install.sh
│  └─ uninstall.sh
│
├─ machine-oriented-lints/
│  ├─ Cargo.toml
│  └─ src/lib.rs
│
├─ templates/
│  ├─ cargo-home-config.toml
│  ├─ crate_attributes.rs
│  └─ project.dylint.toml
│
├─ snippets/
│  └─ rust.json
│
└─ rust-toolchain.toml
```

---

# Included Lints

## 1. `small_vec_with_capacity`

Warns when code uses:

```rust
Vec::with_capacity(N)
```

with a **small compile-time constant**.

### Example triggering the lint

```rust
fn main() {
    let mut v = Vec::with_capacity(8);

    v.push(1);
    v.push(2);
}
```

### Why this matters

For very small collections, heap allocation is often unnecessary.

Better options:

```
[T; N]
SmallVec<[T; N]>
ArrayVec<T, N>
```

These keep data **contiguous and often stack-allocated**, improving cache locality.

---

## 2. `vec_new_then_push`

Warns when a vector is created with:

```rust
Vec::new()
```

and immediately followed by multiple `.push()` calls.

### Example triggering the lint

```rust
fn main() {
    let mut v = Vec::new();

    v.push(1);
    v.push(2);
    v.push(3);
}
```

### Better approach

```rust
let mut v = Vec::with_capacity(3);
```

### Why this matters

Without capacity reservation:

- multiple reallocations may occur
- memory copies may happen
- allocator traffic increases

Even if amortized complexity is good, **hot-path allocations are expensive**.

---

## 3. `linked_list_new`

Warns when `LinkedList::new()` is used.

### Example triggering the lint

```rust
use std::collections::LinkedList;

fn main() {
    let mut list = LinkedList::new();

    list.push_back(1);
}
```

### Why this matters

Linked lists cause **pointer chasing**.

Instead of reading contiguous memory, the CPU must follow pointers between nodes.

Consequences:

- poor spatial locality
- more cache misses
- more branch mispredictions

Better alternatives:

```
Vec
VecDeque
SmallVec
ArrayVec
```

---

# Installation

Clone the repository:

```bash
git clone git@github.com:kyfontan/LowLevel_RustNorm.git
cd LowLevel_RustNorm
```

Run the installation script:

```bash
bash install/install.sh
```

The script will:

1. install `cargo-dylint` and `dylint-link`
2. install the pinned Rust nightly toolchain
3. add Cargo aliases
4. install VS Code snippets
5. configure the Dylint linker
6. generate a `project.dylint.toml` example

---

# Running the Lints

Inside any Rust project that enables the lints:

```bash
cargo dylint --all
```

Or with the installed alias:

```bash
cargo pd
```

You can also run the Clippy policy:

```bash
cargo pc
```

---

# Enable in a Project

Add this to the project's configuration:

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

---

# Testing the Lints

You can verify that the lints work using a simple test project.

Create a test project:

```bash
cargo new lint_test
cd lint_test
```

Add the dylint configuration and run:

```bash
cargo dylint --all
```

### Test Code

```rust
use std::collections::LinkedList;

fn main() {
    let mut small = Vec::with_capacity(4);

    small.push(1);
    small.push(2);

    let mut v = Vec::new();

    v.push(1);
    v.push(2);
    v.push(3);

    let mut list = LinkedList::new();

    list.push_back(1);
}
```

This should trigger all three lints.

Expected warnings:

```
warning: small constant capacity in Vec::with_capacity
warning: Vec::new() followed by push calls
warning: LinkedList::new() used here
```

---

# Disable for One Project

Option 1: remove the Dylint workspace metadata.

Option 2: disable a lint in the crate:

```rust
#![allow(small_vec_with_capacity)]
#![allow(vec_new_then_push)]
#![allow(linked_list_new)]
```

Option 3: disable in a local scope:

```rust
#[allow(vec_new_then_push)]
fn setup() {
    let mut v = Vec::new();
    v.push(1);
    v.push(2);
}
```

---

# Future Lints

This repository is intended to grow with additional machine-oriented rules such as:

- allocation inside hot loops
- field ordering and padding issues
- cache-hostile indirection patterns
- `Vec<bool>` usage
- `HashMap` without capacity reservation
- unnecessary cloning
- inefficient iterator usage in hot paths
- passing `&Vec<T>` instead of `&[T]`
- stack vs heap allocation heuristics

---

# License

MIT