#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARGO_HOME_DIR="${CARGO_HOME:-$HOME/.cargo}"
CONFIG_FILE="$CARGO_HOME_DIR/config.toml"
RUST_TOOLCHAIN_FILE="$ROOT_DIR/rust-toolchain.toml"
LINT_CRATE_DIR="$ROOT_DIR/machine-oriented-lints"
LINT_CARGO_CONFIG_DIR="$LINT_CRATE_DIR/.cargo"
LINT_CARGO_CONFIG_FILE="$LINT_CARGO_CONFIG_DIR/config.toml"
PROJECT_DYLINT_TEMPLATE="$ROOT_DIR/templates/project.dylint.toml"
GENERATED_PROJECT_DYLINT="$ROOT_DIR/templates/project.dylint.generated.toml"

# Pinned nightly for rustc_private stability.
# Change this only when you intentionally upgrade the lint toolchain.
PINNED_NIGHTLY="${PINNED_NIGHTLY:-nightly-2026-03-01}"

if [[ "${OSTYPE:-}" == darwin* ]]; then
  VSCODE_USER_DIR="${HOME}/Library/Application Support/Code/User"
else
  VSCODE_USER_DIR="${HOME}/.config/Code/User"
fi

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$cmd" >&2
    exit 1
  fi
}

append_alias_if_missing() {
  local name="$1"
  local value="$2"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<EOF
[alias]
$name = "$value"
EOF
    return
  fi

  if grep -Eq "^[[:space:]]*$name[[:space:]]*=" "$CONFIG_FILE"; then
    return
  fi

  if grep -Eq '^\[alias\]' "$CONFIG_FILE"; then
    awk -v alias_name="$name" -v alias_value="$value" '
      BEGIN { inserted = 0 }
      {
        print
        if ($0 ~ /^\[alias\]$/ && inserted == 0) {
          print alias_name " = \"" alias_value "\""
          inserted = 1
        }
      }
      END {
        if (inserted == 0) {
          print ""
          print "[alias]"
          print alias_name " = \"" alias_value "\""
        }
      }
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  else
    cat >> "$CONFIG_FILE" <<EOF

[alias]
$name = "$value"
EOF
  fi
}

ensure_cdylib_in_lint_crate() {
  local cargo_toml="$LINT_CRATE_DIR/Cargo.toml"

  if [[ ! -f "$cargo_toml" ]]; then
    printf 'Error: lint crate Cargo.toml not found: %s\n' "$cargo_toml" >&2
    exit 1
  fi

  if ! grep -Eq 'crate-type[[:space:]]*=[[:space:]]*\[[^]]*"cdylib"[^]]*\]' "$cargo_toml"; then
    printf '\nWarning: %s does not appear to declare [lib] crate-type = ["cdylib"]\n' "$cargo_toml" >&2
    printf 'Dylint expects a dynamic library. Add this to machine-oriented-lints/Cargo.toml:\n\n' >&2
    printf '[lib]\ncrate-type = ["cdylib"]\n\n' >&2
  fi
}

write_rust_toolchain_file() {
  cat > "$RUST_TOOLCHAIN_FILE" <<EOF
[toolchain]
channel = "$PINNED_NIGHTLY"
components = ["rust-src", "rustc-dev", "llvm-tools-preview"]
EOF
}

write_lint_cargo_config() {
  mkdir -p "$LINT_CARGO_CONFIG_DIR"

  cat > "$LINT_CARGO_CONFIG_FILE" <<'EOF'
[target.aarch64-apple-darwin]
linker = "dylint-link"

[target.x86_64-apple-darwin]
linker = "dylint-link"

[target.x86_64-unknown-linux-gnu]
linker = "dylint-link"

[target.aarch64-unknown-linux-gnu]
linker = "dylint-link"
EOF
}

generate_project_dylint_template() {
  if [[ -f "$PROJECT_DYLINT_TEMPLATE" ]]; then
    sed "s|__RUST_PERF_NORM_ROOT__|$ROOT_DIR|g" "$PROJECT_DYLINT_TEMPLATE" > "$GENERATED_PROJECT_DYLINT"
  else
    cat > "$GENERATED_PROJECT_DYLINT" <<EOF
[workspace.metadata.dylint]
libraries = [
  { path = "$ROOT_DIR/machine-oriented-lints" },
]

[machine_oriented_lints]
small_vec_capacity_threshold = 64
vec_new_then_push_min_pushes = 2
EOF
  fi
}

printf '==> Checking prerequisites\n'
require_cmd cargo
require_cmd rustup
require_cmd sed
require_cmd awk
require_cmd grep

mkdir -p "$CARGO_HOME_DIR"
mkdir -p "$VSCODE_USER_DIR/snippets"

printf '==> Ensuring pinned nightly toolchain exists: %s\n' "$PINNED_NIGHTLY"
rustup toolchain install "$PINNED_NIGHTLY"

printf '==> Installing nightly components required by Dylint\n'
rustup component add --toolchain "$PINNED_NIGHTLY" rust-src rustc-dev llvm-tools-preview

printf '==> Installing Dylint tools\n'
cargo install cargo-dylint dylint-link

printf '==> Writing pinned rust-toolchain.toml for the lint workspace\n'
write_rust_toolchain_file

printf '==> Writing machine-oriented-lints/.cargo/config.toml for dylint-link\n'
write_lint_cargo_config

printf '==> Checking machine-oriented-lints Cargo.toml\n'
ensure_cdylib_in_lint_crate

printf '==> Updating Cargo aliases in %s\n' "$CONFIG_FILE"
append_alias_if_missing "pc" "clippy --workspace --all-targets --all-features -- -D warnings -W clippy::pedantic -W clippy::perf -D clippy::linkedlist -D clippy::vec_box -D clippy::ptr_arg"
append_alias_if_missing "pd" "dylint --all"

printf '==> Installing VS Code Rust snippet\n'
cp "$ROOT_DIR/snippets/rust.json" "$VSCODE_USER_DIR/snippets/rust.json"

printf '==> Generating project.dylint.toml example with absolute path\n'
generate_project_dylint_template

echo
printf 'Done.\n\n'
printf 'VS Code snippet installed to:\n  %s/snippets/rust.json\n\n' "$VSCODE_USER_DIR"
printf 'Pinned rust-toolchain.toml written to:\n  %s\n\n' "$RUST_TOOLCHAIN_FILE"
printf 'Lint crate Cargo config written to:\n  %s\n\n' "$LINT_CARGO_CONFIG_FILE"
printf 'Generated project template written to:\n  %s\n\n' "$GENERATED_PROJECT_DYLINT"

printf 'To verify the lint workspace builds, run:\n'
printf '  cd "%s"\n' "$ROOT_DIR"
printf '  cargo clean\n'
printf '  cargo dylint --all\n\n'

printf 'Add this to projects that should load the custom lints:\n\n'
cat "$GENERATED_PROJECT_DYLINT"
printf '\n'