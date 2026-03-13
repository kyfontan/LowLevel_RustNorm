# Rustperf

```text
██████╗ ██╗   ██╗███████╗████████╗███╗   ██╗ ██████╗ ██████╗ ███╗   ███╗
██╔══██╗██║   ██║██╔════╝╚══██╔══╝████╗  ██║██╔═══██╗██╔══██╗████╗ ████║
██████╔╝██║   ██║███████╗   ██║   ██╔██╗ ██║██║   ██║██████╔╝██╔████╔██║
██╔══██╗██║   ██║╚════██║   ██║   ██║╚██╗██║██║   ██║██╔══██╗██║╚██╔╝██║
██║  ██║╚██████╔╝███████║   ██║   ██║ ╚████║╚██████╔╝██║  ██║██║ ╚═╝ ██║
╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝
```

```text
                                                                                                                   
                                                                                                                   
                                                        ░░░                                                        
                                           ░░░░░      ░░▒▒░░       ░░░░                                            
                                  ░        ░▒▒▒░░░   ░░▒▒▒▒░░    ░░░▒▒░░                                           
                                 ░░░░░    ░▒▒▒▒▒▒░░░░░▒▓▓▒▒▒▒░▒░░░▒▒▒▒▒░    ░░░░░░                                 
                                 ░▒▒▒▒░░░▒▒▒▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒▒▒▒▒▓▒▓▒▒▓▒▒▒░░░▒▒▓▒░                                 
                                ▒░▓▓▓▒▓▒▒▒▒▒▓▓▒▓▓▓▓▓▓▓▓▒▓▓▓▒▓▓▓▒▓▓▓▓▓▓▓▒▒▒▒▒▓▓▓▓▒░                                 
                        ░░░░░░░▓▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▓▓▓▓▓▓▓▓▓▓▓▒ ░░░░░░░░                        
                        ░▓▓▓▓▓▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▓▓▓▓▓▒░                        
                        ░▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒                         
                 ░░░▒░░▓█▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░▒▒▒░                  
                 ░▒▓▓▓▓▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▓▓▓▓▓░                  
                  ▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░                  
                  ░▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒                   
                   █▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                    
            ░▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓█▓▓▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▓██▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒            
            ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   ▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▓▓  ▓▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒             
              ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓              
               ▓▓▓▓█▓▓▓▓▓▓▓▓▓▓▓▓▓▓   ▓▓▒   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▓   ▒▓▓▓   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓█▓▓▓                
              ▓▓██████▓▓▓▓▓▓▓▓▓▓▓▓   ▒▓▓▓▓▓   ▓▓▓▓▓▓▓█▓▓▓▓▓▓▓▓▓▓▓▓▓▒   ░▓▓▓██    ▓▓▓▓▓▓▓▓▓▓▓███████▓               
            ▓▓▓▓▓▓▓▓▓▓████▓▓▓▓██▓▓▓   ▓▓███▓▓░    ▓▓▒▓ ▓▓▓▓▓ ▓▓▓▒    ▓▓▓███▓▓   ▓▓▓██▓▓▓▓███▓▓▓▓▓▓▓▓▓▓▓            
         ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓████▓▓███▓▒   ▓▓▓███▓               ▓      ░▓████▓▒   ▓▓███▓█████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓         
       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███████▓▓▓   ▒▓▓▓▓▓▓▓▓▒░  ▓▓▓▓▓▓▓  ░▓▒▓▓▓█▓▓▓▒   ▓▓▓██████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       
     ▓▓▓▓▓▓▓▓▓▓    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     ▒▒  █▓▓▓▓▓▓▓▓▓▓▓▓▓█  ▒▓     ▓▓▓▓▓▓▓█▓▓▓▓▓▓▓▓ █▓▓▓▓    ▓▓▓▓▓▓▓▓▓▓     
     ▓▓▓▓▓▓▓▓█  ▓▓▓█  ▓▓▓    ▓▓▓▓▓█   █▓▓▓▓    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   ▓▓▓▓▓▓█  █▓▓▓▓▓     ▓▓▓  █▓▓▓  ▓▓▓▓▓▓▓▓▓     
      ▓▓▓▓▓▓▓▓▓  ▓▓▓▓     ▓▓▓    ▓▓▓▓▒░░░░░░░░▓▓█ █▓▓▓▓▓▓▓▓▓▓▓▓█ █▓░░░░░░░░░░▓▓▓▓    ▓▓▓▓    ▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓      
       ▓▓▓▓▓▓▓▓   ▓▓▓▓     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░▓▓ █▓▓▓▓▓▓▓▓ ▓▓░▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     ▓▓▓▓   ▓▓▓▓▓▓▓▓▓      
        ▓▓▓▓▓▓▓▓   ▓▓▓▓    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓█      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     ▓▓▓    ▓▓▓▓▓▓▓▓        
         ▓▓▓▓▓▓▓▓    ▓▓▓    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     ▓▓▓    ▓▓▓▓▓▓▓▓         
           ▓▓▓▓▓▓▓    ▓▓▓    ▓▓▓▓▓▓▓▓██▓            ▓▓▓▓▓▓▓▓            ▓████▓▓▓▓▓▓▓▓     ▓▓▓    ▓▓▓▓▓▓▓           
             ▓▓▓▓▓▓     ▓▓     ▓▓▓▓▓▓▓▓▓▓▓▓▓                         ▓▓▓▓▓▓▓▓▓▓▓▓▓▓     ▓▓▓     ▓▓▓▓▓▓▓            
               ▓▓▓▓▓             ▓▓▓▓▓████▓▓▓▓▓▓▓▓              ▓▓▓▓▓▓▓▓████▓▓▓▓▓              ▓▓▓▓▓               
                  ▓▓▓▓              ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                ▓▓▓▓                 
                    ▓▓▓                  ▓▓▓▓▓▓▓                 ▓▓▓▓▓▓▓▓                   ▓▓▓▓                   
                      ▓▓                                                                   ▓▓                      
                                                                                                                   
                                                                                                                   
                                                                                                                   
                                                                                                                   
                                                                                                                   
```

Rust performance lint toolkit focused on machine-level efficiency.

`Rustperf` helps enforce machine-aware Rust coding practices around:

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

`Rustperf` focuses on linting patterns that hurt cache behavior or allocation discipline.

---

# Features

### Cross-platform install

The project has dedicated install paths for macOS, Linux, and Windows.

### Faster install and first run

The lint crate now uses a much smaller dependency graph, and the installer skips reinstalling `cargo-dylint` / `dylint-link` when the expected runtime is already present.

If `cargo-binstall` is available, the installer uses it automatically for faster runtime installation.

### Terminal-friendly

The installer adds a `rustperf` command so you can run:

```text
cargo dylint --all
```

from the current project without retyping it every time.

### Project bootstrap

The installed `rustperf` command supports:

```text
rustperf init
rustperf repair
```

When run from a project root containing `Cargo.toml`, `rustperf init`:

- appends the required Dylint library metadata to `Cargo.toml`
- creates or appends `dylint.toml`
- avoids duplicating sections that already exist

And `rustperf repair` can:

- rewrite outdated Dylint library paths after a repo move or rename
- restore missing config blocks in the current project
- repair the installed `rustperf` wrapper itself

### Workspace-friendly

The repository exposes a root Cargo workspace, so commands like:

```bash
cargo check -p machine_oriented_lints
```

work directly from the repository root.

### Safer defaults

The install flow now:

- writes config files more safely
- generates ready-to-copy `Cargo.toml` and `dylint.toml` examples under `assets/generated/`
- installs Cargo aliases
- installs VS Code snippets
- configures `dylint-link` for supported targets
- warns earlier about likely platform or toolchain issues

---

# Repository Structure

```text
Rustperf/
├── Cargo.toml
├── Cargo.lock
├── README.md
├── install.sh
├── install.ps1
├── install.cmd
├── uninstall.sh
├── uninstall.ps1
├── uninstall.cmd
├── .vscode/
│   └── settings.json
├── assets/
│   ├── generated/
│   ├── templates/
│   │   ├── dylint.toml
│   │   ├── project.dylint.toml
│   │   ├── rustperf
│   │   └── rustperf.cmd
│   └── vscode/
│       └── rust.json
├── crates/
│   └── machine-oriented-lints/
│       ├── Cargo.toml
│       └── src/
│           └── lib.rs
├── docs/
│   └── next_lints.md
├── install/
│   ├── common.sh
│   ├── install.ps1
│   └── install.sh
└── rust-toolchain.toml
```

Notes:

- `assets/templates/` contains the source templates committed to the repository
- `assets/generated/` is produced by the installer and ignored by git
- `crates/machine-oriented-lints/` contains the Dylint library

---

# Included Lints

## Collection sizing and allocation

- `small_vec_with_capacity`
- `vec_new_then_push`
- `hash_map_new_then_insert`
- `hash_set_new_then_insert`
- `string_new_then_push_str`
- `vec_new_then_reserve`

These lints warn on patterns like:

```rust
let mut v = Vec::new();
v.push(a);
v.push(b);

let mut map = HashMap::new();
map.insert(k1, v1);
map.insert(k2, v2);

let mut s = String::new();
s.push_str("foo");
s.push_str("bar");
```

and suggest pre-reserving capacity when the approximate size is already known.

## Cache-hostile data structures

- `linked_list_new`
- `btree_map_new`
- `btree_set_new`

These lints warn on constructions such as:

```rust
LinkedList::new()
BTreeMap::new()
BTreeSet::new()
```

when a more contiguous layout may be preferable for hot traversal-heavy paths.

## Front-heavy `Vec` operations

- `vec_remove_first`
- `vec_insert_front`

These lints catch patterns like:

```rust
v.remove(0);
v.insert(0, value);
```

because both shift the entire tail and are often a poor fit for queue-like workloads.

## Struct layout

- `field_order_by_size`

This lint warns when named structs made entirely of known primitive scalar fields appear to be ordered in a way that introduces avoidable padding.

It is intentionally conservative to reduce false positives.

---

# Configuration

Project configuration is split across two files.

In `Cargo.toml`, add:

```toml
[workspace.metadata.dylint]
libraries = [
  { path = "/ABSOLUTE/PATH/TO/Rustperf/crates/machine-oriented-lints" },
]
```

Then create a `dylint.toml` file at the root of the target project with:

```toml
[machine_oriented_lints]
small_vec_capacity_threshold = 64
vec_new_then_push_min_pushes = 2
hash_map_new_then_insert_min_inserts = 2
hash_set_new_then_insert_min_inserts = 2
string_new_then_push_str_min_calls = 2
```

Why split it this way:

- `Cargo.toml` accepts `[workspace.metadata.dylint]`
- custom lint config like `[machine_oriented_lints]` should live in `dylint.toml`
- this avoids schema warnings from VS Code TOML extensions like Even Better TOML

On Windows, use either:

- forward slashes in the Dylint library path
- or escaped backslashes

---

# Installation

Clone the repository:

```bash
git clone <your-repo-url> Rustperf
cd Rustperf
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

1. install the pinned Rust nightly toolchain if needed
2. install required nightly components
3. install or reuse `cargo-dylint`
4. install or reuse `dylint-link`
5. add Cargo aliases `pd` and `pc`
6. install the `rustperf` terminal command
7. install the VS Code Rust snippet
8. write `crates/machine-oriented-lints/.cargo/config.toml`
9. generate a `Cargo.toml` example and a `dylint.toml` example under `assets/generated/`

`rustperf`, `rustperf init`, and `rustperf repair` are intended to behave consistently on macOS, Linux, and Windows.

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

To bootstrap the current project automatically:

```text
rustperf init
```

To repair a project or wrapper after a path change, repo rename, or stale installation:

```text
rustperf repair
rustperf repair project
rustperf repair self
```

---

# Enable in a Project

From the target project root, the simplest flow is:

```text
rustperf init
rustperf
```

If the project was initialized with an older Rustperf path, or the repo was moved or renamed, run:

```text
rustperf repair
```

If you prefer manual setup, use the configuration shown above in the `Configuration` section.

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

# Repair Commands

Rustperf includes a built-in repair flow for stale setups:

- `rustperf repair` repairs the current project when possible and refreshes the installed wrapper
- `rustperf repair project` repairs only the current project
- `rustperf repair self` repairs only the installed wrapper in Cargo's bin directory

This is especially useful after:

- moving the repository
- renaming the repository
- keeping an older `Cargo.toml` that still points to a stale Dylint library path

---

# Installed Assets

After installation, the project sets up:

- a pinned `rust-toolchain.toml`
- `crates/machine-oriented-lints/.cargo/config.toml`
- Cargo aliases in Cargo home config
- a `rustperf` command in Cargo's bin directory
- the VS Code Rust snippet
- generated examples in `assets/generated/`

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
- unnecessary cloning
- iterator-heavy patterns in hot paths
- `&Vec<T>` instead of `&[T]`
- stack vs heap allocation heuristics

---

# License

MIT
