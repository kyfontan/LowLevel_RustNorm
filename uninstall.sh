#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARGO_HOME_DIR="${CARGO_HOME:-$HOME/.cargo}"
CONFIG_FILE="$CARGO_HOME_DIR/config.toml"
RUST_TOOLCHAIN_FILE="$ROOT_DIR/rust-toolchain.toml"
LINT_CARGO_CONFIG="$ROOT_DIR/machine-oriented-lints/.cargo/config.toml"

if [[ "${OSTYPE:-}" == darwin* ]]; then
  VSCODE_USER_DIR="${HOME}/Library/Application Support/Code/User"
else
  VSCODE_USER_DIR="${HOME}/.config/Code/User"
fi

SNIPPET_FILE="$VSCODE_USER_DIR/snippets/rust.json"

remove_alias() {
  local name="$1"

  if [[ -f "$CONFIG_FILE" ]]; then
    tmp=$(mktemp)

    awk -v alias="$name" '
      BEGIN { in_alias = 0 }
      /^\[alias\]/ { in_alias = 1; print; next }
      /^\[/ && $0 != "[alias]" { in_alias = 0 }
      {
        if (in_alias && $1 ~ alias"=") next
        print
      }
    ' "$CONFIG_FILE" > "$tmp"

    mv "$tmp" "$CONFIG_FILE"
  fi
}

printf '==> Removing cargo aliases\n'
remove_alias "pc"
remove_alias "pd"

printf '==> Removing rust-toolchain.toml\n'
rm -f "$RUST_TOOLCHAIN_FILE"

printf '==> Removing dylint linker config\n'
rm -f "$LINT_CARGO_CONFIG"

printf '==> Removing VS Code snippet\n'
rm -f "$SNIPPET_FILE"

printf '==> Optionally uninstall dylint tools\n'

read -r -p "Remove cargo-dylint and dylint-link? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  cargo uninstall cargo-dylint || true
  cargo uninstall dylint-link || true
fi

echo
echo "Uninstall complete."
echo
echo "Remaining files:"
echo "  $ROOT_DIR/templates/"
echo "  $ROOT_DIR/machine-oriented-lints/"
echo
echo "You can delete the repo manually if you no longer need it."