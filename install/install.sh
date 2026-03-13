#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/common.sh
source "$SCRIPT_DIR/common.sh"

ROOT_DIR="$(resolve_root_dir "${BASH_SOURCE[0]}")"
CARGO_HOME_DIR="${CARGO_HOME:-$HOME/.cargo}"
CONFIG_FILE="$CARGO_HOME_DIR/config.toml"
CARGO_BIN_DIR="$CARGO_HOME_DIR/bin"
RUSTPERF_BIN="$CARGO_BIN_DIR/rustperf"
RUSTPERF_CMD_BIN="$CARGO_BIN_DIR/rustperf.cmd"
RUSTPERF_TEMPLATE="$ROOT_DIR/templates/rustperf"
RUSTPERF_CMD_TEMPLATE="$ROOT_DIR/templates/rustperf.cmd"
RUST_TOOLCHAIN_FILE="$ROOT_DIR/rust-toolchain.toml"
LINT_CRATE_DIR="$ROOT_DIR/machine-oriented-lints"
LINT_CARGO_CONFIG_DIR="$LINT_CRATE_DIR/.cargo"
LINT_CARGO_CONFIG_FILE="$LINT_CARGO_CONFIG_DIR/config.toml"
PROJECT_DYLINT_TEMPLATE="$ROOT_DIR/templates/project.dylint.toml"
GENERATED_PROJECT_DYLINT="$ROOT_DIR/templates/project.dylint.generated.toml"
DYLINT_CONFIG_TEMPLATE="$ROOT_DIR/templates/dylint.toml"
GENERATED_DYLINT_CONFIG="$ROOT_DIR/templates/dylint.generated.toml"

PINNED_NIGHTLY="${PINNED_NIGHTLY:-nightly-2026-03-01}"

detect_platform

append_alias_if_missing() {
  local name="$1"
  local value="$2"
  local tmp_file

  if [[ ! -f "$CONFIG_FILE" ]]; then
    write_file_atomically "$CONFIG_FILE" <<EOF
[alias]
$name = "$value"
EOF
    return
  fi

  if grep -Eq "^[[:space:]]*$name[[:space:]]*=" "$CONFIG_FILE"; then
    return
  fi

  tmp_file="$(mktemp "$(dirname "$CONFIG_FILE")/$(basename "$CONFIG_FILE").XXXXXX")"

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
    ' "$CONFIG_FILE" > "$tmp_file"
  else
    cat "$CONFIG_FILE" > "$tmp_file"
    cat >> "$tmp_file" <<EOF

[alias]
$name = "$value"
EOF
  fi

  mv "$tmp_file" "$CONFIG_FILE"
}

ensure_cdylib_in_lint_crate() {
  local cargo_toml="$LINT_CRATE_DIR/Cargo.toml"

  if [[ ! -f "$cargo_toml" ]]; then
    printf 'Error: lint crate Cargo.toml not found: %s\n' "$cargo_toml" >&2
    exit 1
  fi

  if ! grep -Eq 'crate-type[[:space:]]*=[[:space:]]*\[[^]]*"cdylib"[^]]*\]' "$cargo_toml"; then
    printf '\n' >&2
    log_warning "$cargo_toml does not appear to declare [lib] crate-type = [\"cdylib\"]" >&2
    printf 'Dylint expects a dynamic library. Add this to machine-oriented-lints/Cargo.toml:\n\n' >&2
    printf '[lib]\ncrate-type = ["cdylib"]\n\n' >&2
  fi
}

write_rust_toolchain_file() {
  write_file_atomically "$RUST_TOOLCHAIN_FILE" <<EOF
[toolchain]
channel = "$PINNED_NIGHTLY"
components = ["rust-src", "rustc-dev", "llvm-tools-preview"]
profile = "minimal"
EOF
}

write_lint_cargo_config() {
  mkdir -p "$LINT_CARGO_CONFIG_DIR"

  write_file_atomically "$LINT_CARGO_CONFIG_FILE" <<'EOF'
[target.aarch64-apple-darwin]
linker = "dylint-link"

[target.x86_64-apple-darwin]
linker = "dylint-link"

[target.x86_64-unknown-linux-gnu]
linker = "dylint-link"

[target.aarch64-unknown-linux-gnu]
linker = "dylint-link"

[target.x86_64-pc-windows-msvc]
linker = "dylint-link"

[target.aarch64-pc-windows-msvc]
linker = "dylint-link"

[target.x86_64-pc-windows-gnu]
linker = "dylint-link"
EOF
}

generate_project_dylint_templates() {
  if [[ -f "$PROJECT_DYLINT_TEMPLATE" ]]; then
    sed "s|__RUST_PERF_NORM_ROOT__|$ROOT_DIR|g" "$PROJECT_DYLINT_TEMPLATE" > "$GENERATED_PROJECT_DYLINT"
  else
    write_file_atomically "$GENERATED_PROJECT_DYLINT" <<EOF
[workspace.metadata.dylint]
libraries = [
  { path = "$ROOT_DIR/machine-oriented-lints" },
]
EOF
  fi

  if [[ -f "$DYLINT_CONFIG_TEMPLATE" ]]; then
    cp "$DYLINT_CONFIG_TEMPLATE" "$GENERATED_DYLINT_CONFIG"
  else
    write_file_atomically "$GENERATED_DYLINT_CONFIG" <<EOF
[machine_oriented_lints]
small_vec_capacity_threshold = 64
vec_new_then_push_min_pushes = 2
EOF
  fi
}

install_rustperf_command() {
  mkdir -p "$CARGO_BIN_DIR"

  if [[ "$PLATFORM_FAMILY" == "windows" ]]; then
    if [[ ! -f "$RUSTPERF_CMD_TEMPLATE" ]]; then
      printf 'Error: rustperf command template not found: %s\n' "$RUSTPERF_CMD_TEMPLATE" >&2
      exit 1
    fi

    cp "$RUSTPERF_CMD_TEMPLATE" "$RUSTPERF_CMD_BIN"
  else
    if [[ ! -f "$RUSTPERF_TEMPLATE" ]]; then
      printf 'Error: rustperf command template not found: %s\n' "$RUSTPERF_TEMPLATE" >&2
      exit 1
    fi

    cp "$RUSTPERF_TEMPLATE" "$RUSTPERF_BIN"
    chmod +x "$RUSTPERF_BIN"
  fi
}

log_section "Checking prerequisites"
log_step "Target platform: $PLATFORM_NAME"
require_cmd cargo
require_cmd rustup
require_cmd sed
require_cmd awk
require_cmd grep
require_cmd cp
if [[ "$PLATFORM_FAMILY" != "windows" ]]; then
  require_cmd bash
  require_cmd chmod
fi

mkdir -p "$CARGO_HOME_DIR"
mkdir -p "$VSCODE_USER_DIR/snippets"

log_section "Installing Rust toolchain support"
log_step "Ensuring pinned nightly exists: $PINNED_NIGHTLY"
rustup toolchain install "$PINNED_NIGHTLY" --profile minimal

log_step "Installing nightly components required by Dylint"
rustup component add --toolchain "$PINNED_NIGHTLY" rust-src rustc-dev llvm-tools-preview

log_section "Installing lint runtime"
log_step "Installing cargo-dylint and dylint-link"
cargo install cargo-dylint dylint-link

log_section "Configuring this repository"
log_step "Writing pinned rust-toolchain.toml"
write_rust_toolchain_file

log_step "Writing machine-oriented-lints/.cargo/config.toml"
write_lint_cargo_config

log_step "Checking machine-oriented-lints/Cargo.toml"
ensure_cdylib_in_lint_crate

log_section "Configuring user shortcuts"
log_step "Updating Cargo aliases in $CONFIG_FILE"
append_alias_if_missing "pc" "clippy --workspace --all-targets --all-features -- -D warnings -W clippy::pedantic -W clippy::perf -D clippy::linkedlist -D clippy::vec_box -D clippy::ptr_arg"
append_alias_if_missing "pd" "dylint --all"

if [[ "$PLATFORM_FAMILY" == "windows" ]]; then
  log_step "Installing rustperf command into $RUSTPERF_CMD_BIN"
else
  log_step "Installing rustperf command into $RUSTPERF_BIN"
fi
install_rustperf_command

log_section "Installing editor assets"
log_step "Installing VS Code Rust snippet"
cp "$ROOT_DIR/snippets/rust.json" "$VSCODE_USER_DIR/snippets/rust.json"

log_step "Generating Cargo.toml and dylint.toml examples"
generate_project_dylint_templates

printf '\n'
log_success "Installation complete."
printf '\n'
printf 'Installed assets:\n'
printf '  VS Code snippet: %s/snippets/rust.json\n' "$VSCODE_USER_DIR"
printf '  rust-toolchain:  %s\n' "$RUST_TOOLCHAIN_FILE"
printf '  lint config:     %s\n' "$LINT_CARGO_CONFIG_FILE"
if [[ "$PLATFORM_FAMILY" == "windows" ]]; then
  printf '  rustperf cmd:    %s\n' "$RUSTPERF_CMD_BIN"
else
  printf '  rustperf cmd:    %s\n' "$RUSTPERF_BIN"
fi
printf '  Cargo.toml snippet: %s\n' "$GENERATED_PROJECT_DYLINT"
printf '  dylint.toml:        %s\n\n' "$GENERATED_DYLINT_CONFIG"

printf 'Quick checks:\n'
printf '  cd "%s"\n' "$ROOT_DIR"
printf '  cargo check -p machine_oriented_lints\n'
printf '  rustperf\n\n'

printf 'Add this to Cargo.toml:\n\n'
cat "$GENERATED_PROJECT_DYLINT"
printf '\n\n'
printf 'Add this to dylint.toml:\n\n'
cat "$GENERATED_DYLINT_CONFIG"
printf '\n'
