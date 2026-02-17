#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

need_cmd jq
need_cmd curl
need_cmd unzip

version="${1:-}"
platform="${2:-}"

[[ -n "$version" ]] || die "usage: ./scripts/verify.sh <version> <platform>"
[[ -n "$platform" ]] || die "usage: ./scripts/verify.sh <version> <platform>"

status="$(json_get ".versions[\"$version\"][\"$platform\"].status")" || die "entry not found for $version/$platform"
[[ "$status" == "ready" ]] || die "entry $version/$platform is not ready (status=$status)"

binary_url="$(json_get ".versions[\"$version\"][\"$platform\"].source.binaryUrl")"
archive_algo="$(json_get ".versions[\"$version\"][\"$platform\"].archive.hash.algorithm")"
archive_hash="$(json_get ".versions[\"$version\"][\"$platform\"].archive.hash.value")"
archive_type="$(json_get ".versions[\"$version\"][\"$platform\"].archive.type")"
file_hash_algo="$(json_get ".versions[\"$version\"][\"$platform\"].fileHashes.algorithm // \"sha256\"")"

[[ "$archive_type" == "zip" || "$archive_type" == "jar" ]] || die "only zip/jar archives are supported now"

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

archive_path="$tmp_dir/source.zip"
extract_dir="$tmp_dir/extracted"
mkdir -p "$extract_dir"

curl -fsSL "$binary_url" -o "$archive_path"
verify_hash "$archive_algo" "$archive_hash" "$archive_path"
unzip -q "$archive_path" -d "$extract_dir"

jq -er ".versions[\"$version\"][\"$platform\"].requiredFiles[]" "$MANIFEST_PATH" | while read -r required; do
  [[ "$required" != /* ]] || die "requiredFiles must be relative paths: $required"
  target="$extract_dir/$required"
  [[ -f "$target" ]] || die "required file not found in archive: $required"

  base_name="$(basename "$required")"
  expected_file_hash="$(jq -er ".versions[\"$version\"][\"$platform\"].fileHashes.values[\"$required\"] // .versions[\"$version\"][\"$platform\"].fileHashes.values[\"$base_name\"] // empty" "$MANIFEST_PATH")"
  if [[ -n "$expected_file_hash" ]]; then
    verify_hash "$file_hash_algo" "$expected_file_hash" "$target"
  fi
done

echo "verification passed for $version/$platform"
