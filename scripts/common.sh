#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/manifests/sources.json"

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

hash_file() {
  local algorithm="$1"
  local file="$2"
  case "$algorithm" in
    sha256) sha256sum "$file" | awk '{print $1}' ;;
    md5) md5sum "$file" | awk '{print $1}' ;;
    *) die "unsupported hash algorithm: $algorithm" ;;
  esac
}

verify_hash() {
  local algorithm="$1"
  local expected="$2"
  local file="$3"
  local actual
  actual="$(hash_file "$algorithm" "$file")"
  if [[ "$actual" != "$expected" ]]; then
    die "hash mismatch for $file (expected $expected, got $actual)"
  fi
}

json_get() {
  local query="$1"
  jq -er "$query" "$MANIFEST_PATH"
}

create_zip_from_dir() {
  local src_dir="$1"
  local out_zip="$2"

  if have_cmd zip; then
    (
      cd "$src_dir"
      zip -q -r "$out_zip" .
    )
    return
  fi

  if have_cmd bsdtar; then
    bsdtar -a -cf "$out_zip" -C "$src_dir" .
    return
  fi

  die "missing zip creator: install zip or bsdtar"
}
