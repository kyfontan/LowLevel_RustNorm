#!/usr/bin/env bash
set -euo pipefail

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  COLOR_RESET=$'\033[0m'
  COLOR_BOLD=$'\033[1m'
  COLOR_BLUE=$'\033[34m'
  COLOR_CYAN=$'\033[36m'
  COLOR_GREEN=$'\033[32m'
  COLOR_YELLOW=$'\033[33m'
else
  COLOR_RESET=''
  COLOR_BOLD=''
  COLOR_BLUE=''
  COLOR_CYAN=''
  COLOR_GREEN=''
  COLOR_YELLOW=''
fi

resolve_root_dir() {
  local script_path="$1"
  cd "$(dirname "$script_path")/.." && pwd
}

detect_platform() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    PLATFORM_NAME="macOS"
    PLATFORM_FAMILY="unix"
    VSCODE_USER_DIR="${HOME}/Library/Application Support/Code/User"
  elif [[ "${OSTYPE:-}" == linux* ]]; then
    PLATFORM_NAME="Linux"
    PLATFORM_FAMILY="unix"
    VSCODE_USER_DIR="${HOME}/.config/Code/User"
  elif [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${OSTYPE:-}" == win32* ]]; then
    PLATFORM_NAME="Windows"
    PLATFORM_FAMILY="windows"
    local appdata_root="${APPDATA:-${USERPROFILE:-$HOME/AppData/Roaming}}"
    VSCODE_USER_DIR="$appdata_root/Code/User"
  else
    printf 'Error: unsupported platform: %s\n' "${OSTYPE:-unknown}" >&2
    printf 'This installer currently supports macOS, Linux, and Windows.\n' >&2
    exit 1
  fi
}

log_section() {
  printf '\n%s%s==>%s %s\n' "$COLOR_BOLD" "$COLOR_BLUE" "$COLOR_RESET" "$1"
}

log_step() {
  printf '  %s-%s %s\n' "$COLOR_CYAN" "$COLOR_RESET" "$1"
}

log_success() {
  printf '%s%s%s\n' "$COLOR_GREEN" "$1" "$COLOR_RESET"
}

log_warning() {
  printf '%sWarning:%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$1"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$cmd" >&2
    exit 1
  fi
}

write_file_atomically() {
  local destination="$1"
  local destination_dir
  local destination_name
  local tmp_file

  destination_dir="$(dirname "$destination")"
  destination_name="$(basename "$destination")"
  mkdir -p "$destination_dir"
  tmp_file="$(mktemp "$destination_dir/${destination_name}.XXXXXX")"
  cat > "$tmp_file"
  mv "$tmp_file" "$destination"
}

remove_alias_from_cargo_config() {
  local config_file="$1"
  local alias_name="$2"
  local tmp_file

  if [[ ! -f "$config_file" ]]; then
    return
  fi

  tmp_file="$(mktemp "$(dirname "$config_file")/$(basename "$config_file").XXXXXX")"

  awk -v alias="$alias_name" '
    BEGIN { in_alias = 0 }
    /^\[alias\]/ { in_alias = 1; print; next }
    /^\[/ && $0 != "[alias]" { in_alias = 0 }
    {
      if (in_alias && $1 ~ alias"=") next
      print
    }
  ' "$config_file" > "$tmp_file"

  mv "$tmp_file" "$config_file"
}
