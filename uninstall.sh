#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/common.sh
source "$SCRIPT_DIR/install/common.sh"

ROOT_DIR="$SCRIPT_DIR"
CARGO_HOME_DIR="${CARGO_HOME:-$HOME/.cargo}"
CONFIG_FILE="$CARGO_HOME_DIR/config.toml"
RUSTPERF_BIN="$CARGO_HOME_DIR/bin/rustperf"
RUSTPERF_CMD_BIN="$CARGO_HOME_DIR/bin/rustperf.cmd"
RUST_TOOLCHAIN_FILE="$ROOT_DIR/rust-toolchain.toml"
LINT_CARGO_CONFIG="$ROOT_DIR/machine-oriented-lints/.cargo/config.toml"

detect_platform

SNIPPET_FILE="$VSCODE_USER_DIR/snippets/rust.json"

log_section "Removing cargo aliases"
remove_alias_from_cargo_config "$CONFIG_FILE" "pc"
remove_alias_from_cargo_config "$CONFIG_FILE" "pd"

log_section "Removing rustperf command"
rm -f "$RUSTPERF_BIN"
rm -f "$RUSTPERF_CMD_BIN"

log_section "Removing rust-toolchain.toml"
rm -f "$RUST_TOOLCHAIN_FILE"

log_section "Removing dylint linker config"
rm -f "$LINT_CARGO_CONFIG"

log_section "Removing VS Code snippet"
rm -f "$SNIPPET_FILE"

log_section "Optionally uninstall dylint tools"
read -r -p "Remove cargo-dylint and dylint-link? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  cargo uninstall cargo-dylint || true
  cargo uninstall dylint-link || true
fi

echo
log_success "Uninstall complete."
echo
echo "Remaining files:"
echo "  $ROOT_DIR/templates/"
echo "  $ROOT_DIR/machine-oriented-lints/"
echo
echo "You can delete the repo manually if you no longer need it."
