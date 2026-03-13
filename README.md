# rust-perf-norm

Rust performance lint toolkit focused on machine-level efficiency.

`rust-perf-norm` helps Rust developers enforce machine-aware coding practices around:

- CPU cache locality
- allocation cost
- struct layout and padding
- contiguous data structures
- predictable memory access patterns

It combines:

- Clippy for standard Rust lints
- Dylint for custom machine-oriented lints
- VS Code integration for editor feedback

The goal is to make performance-oriented Rust workflows easier to install, easier to run, and harder to misconfigure.

---

# Platform Support

This repository currently supports:

- macOS
- Linux
- Windows

Installation entrypoints:

- macOS / Linux: `bash install.sh`
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File .\install.ps1`
- Windows Command Prompt: `install.cmd`

Recommended Windows setup:

- Rust with the MSVC toolchain
- Visual Studio Build Tools installed

The Windows installer warns if no native C/C++ toolchain is detected, because that is one of the most common causes of compilation failures.

---

# Philosophy

Modern CPUs are extremely fast at arithmetic but much slower at memory access.

Typical latencies:

| Resource | Latency |
| --- | --- |
| L1 cache | ~1-4 cycles |
| L2 cache | ~10 cycles |
| L3 cache | ~40 cycles |
| RAM | ~100-300 cycles |

Many real performance regressions come from:

- heap allocations
- pointer chasing
- poor data locality
- unnecessary indirection
- avoidable padding

`rust-perf-norm` focuses on linting patterns that hurt cache behavior or allocation discipline.

---

# Features

### Cross-platform install

The project now has dedicated install paths for macOS, Linux, and Windows.

### Terminal-friendly

The installer adds a `rustperf` command so you can run:

```text
cargo dylint --all
```

from the current project without retyping it every time.

### Workspace-friendly

The repository now exposes a root Cargo workspace, so commands like:

```bash
cargo check -p machine_oriented_lints
```

work directly from the repository root.

### Safer defaults

The install flow now:

- writes config files more safely
- generates ready-to-copy `Cargo.toml` and `dylint.toml` snippets
- installs Cargo aliases
- installs VS Code snippets
- configures `dylint-link` for supported targets
- warns earlier about likely platform or toolchain issues

---

# Repository Structure

```text
rust-perf-norm/
+-- Cargo.toml
+-- README.md
+-- install.sh
+-- install.ps1
+-- install.cmd
+-- uninstall.sh
+-- uninstall.ps1
+-- uninstall.cmd
+-- install/
¦   +-- common.sh
¦   +-- install.sh
¦   +-- install.ps1
+-- machine-oriented-lints/
¦   +-- Cargo.toml
¦   +-- src/lib.rs
+-- templates/
¦   +-- cargo-home-config.toml
¦   +-- crate_attributes.rs
¦   +-- dylint.toml
¦   +-- dylint.generated.toml
¦   +-- project.dylint.toml
¦   +-- project.dylint.generated.toml
¦   +-- rustperf
¦   +-- rustperf.cmd
+-- snippets/
¦   +-- rust.json
+-- docs/
¦   +-- next_lints.md
+-- rust-toolchain.toml
```

---

# Included Lints

## `small_vec_with_capacity`

Warns on:

```rust
Vec::with_capacity(N)
```

when `N` is a small compile-time constant.

Suggested alternatives:

```text
[T; N]
SmallVec<[T; N]>
ArrayVec<T, N>
```

## `vec_new_then_push`

Warns when:

```rust
let mut v = Vec::new();
v.push(...);
v.push(...);
```

is followed by enough consecutive `push` calls that pre-reserving capacity would be clearer and more allocation-aware.

Typical suggestion:

```rust
let mut v = Vec::with_capacity(2);
```

## `linked_list_new`

Warns on:

```rust
LinkedList::new()
```

because linked lists are usually hostile to cache locality.

Suggested alternatives:

```text
Vec
VecDeque
SmallVec
ArrayVec
```

## `field_order_by_size`

Warns when struct fields appear to be ordered in a way that introduces avoidable padding.

Important note:

This lint is now intentionally conservative. It only reasons about named structs made entirely of known primitive scalar fields, which reduces false positives and misleading diagnostics.

---

# Installation

Clone the repository:

```bash
git clone git@github.com:kyfontan/LowLevel_RustNorm.git
cd LowLevel_RustNorm
```

Install on macOS / Linux:

```bash
bash install.sh
```

Install on Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Install on Windows Command Prompt:

```bat
install.cmd
```

The installer will:

1. install `cargo-dylint`
2. install `dylint-link`
3. install the pinned Rust nightly toolchain
4. install required nightly components
5. add Cargo aliases `pd` and `pc`
6. install the `rustperf` terminal command
7. install the VS Code Rust snippet
8. write `machine-oriented-lints/.cargo/config.toml`
9. generate a `Cargo.toml` snippet and a `dylint.toml` example

---

# Running the Lints

Inside any Rust project that enables the lints, you can run:

```bash
cargo dylint --all
```

Or use the installed shortcut:

```text
rustperf
```

Or the Cargo alias:

```bash
cargo pd
```

You can also run the stricter Clippy profile with:

```bash
cargo pc
```

---

# Enable in a Project

The configuration is split across two files.

In `Cargo.toml`, add:

```toml
[workspace.metadata.dylint]
libraries = [
  { path = "/ABSOLUTE/PATH/TO/rust-perf-norm/machine-oriented-lints" },
]
```

Then create a `dylint.toml` file at the root of the target project with:

```toml
[machine_oriented_lints]
small_vec_capacity_threshold = 64
vec_new_then_push_min_pushes = 2
```

Why split it this way:

- `Cargo.toml` accepts `[workspace.metadata.dylint]`
- custom lint config like `[machine_oriented_lints]` should live in `dylint.toml`
- this avoids schema warnings from VS Code TOML extensions like Even Better TOML

On Windows, use either:

- forward slashes in the Dylint library path
- or escaped backslashes

Then run:

```text
rustperf
```

---

# Verifying This Repository

From the repository root:

```bash
cargo check -p machine_oriented_lints
```

Then, in a Rust project configured for Dylint:

```text
rustperf
```

---

# Installed Assets

After installation, the project sets up:

- a pinned `rust-toolchain.toml`
- `machine-oriented-lints/.cargo/config.toml`
- Cargo aliases in Cargo home config
- a `rustperf` command in Cargo's bin directory
- the VS Code Rust snippet
- a generated `Cargo.toml` snippet
- a generated `dylint.toml` example

On Unix-like systems, the installed command is typically:

```text
~/.cargo/bin/rustperf
```

On Windows, the installed command is typically:

```text
%USERPROFILE%\.cargo\bin\rustperf.cmd
```

---

# Uninstall

On macOS / Linux:

```bash
bash uninstall.sh
```

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

On Windows Command Prompt:

```bat
uninstall.cmd
```

The uninstall flow removes:

- Cargo aliases added by this project
- the `rustperf` command
- the repository `rust-toolchain.toml`
- the Dylint linker config
- the VS Code snippet

It can also optionally uninstall `cargo-dylint` and `dylint-link`.

---

# Future Lints

Potential future additions include:

- allocation inside hot loops
- field ordering and padding analysis using real layout information
- cache-hostile indirection patterns
- `Vec<bool>` usage
- `HashMap` without capacity reservation
- unnecessary cloning
- iterator-heavy patterns in hot paths
- `&Vec<T>` instead of `&[T]`
- stack vs heap allocation heuristics

---

# License

MIT
