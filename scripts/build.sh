#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

need_cmd jq
need_cmd curl
need_cmd unzip

version="${1:-}"
[[ -n "$version" ]] || die "usage: ./scripts/build.sh <version>"

"$SCRIPT_DIR/validate.sh" >/dev/null

version_exists="$(json_get ".versions | has(\"$version\")")"
[[ "$version_exists" == "true" ]] || die "version not found in manifest: $version"

out_dir="$ROOT_DIR/build/$version"
rm -rf "$out_dir"
mkdir -p "$out_dir"

tmp_root="$(mktemp -d)"
cleanup() { rm -rf "$tmp_root"; }
trap cleanup EXIT

built_count=0

while read -r platform; do
  status="$(json_get ".versions[\"$version\"][\"$platform\"].status")"
  if [[ "$status" != "ready" ]]; then
    echo "skip $platform (status=$status)"
    continue
  fi

  "$SCRIPT_DIR/verify.sh" "$version" "$platform" >/dev/null

  binary_url="$(json_get ".versions[\"$version\"][\"$platform\"].source.binaryUrl")"
  stage_dir="$tmp_root/$platform"
  mkdir -p "$stage_dir/input" "$stage_dir/output"
  curl -fsSL "$binary_url" -o "$stage_dir/input/source.zip"
  unzip -q "$stage_dir/input/source.zip" -d "$stage_dir/input/extracted"

  jq -er ".versions[\"$version\"][\"$platform\"].requiredFiles[]" "$MANIFEST_PATH" | while read -r required; do
    [[ "$required" != /* ]] || die "requiredFiles must be relative paths: $required"
    target="$stage_dir/input/extracted/$required"
    [[ -f "$target" ]] || die "required file missing while building: $required"
    cp "$target" "$stage_dir/output/$(basename "$required")"
  done

  while read -r license_file; do
    cp "$ROOT_DIR/$license_file" "$stage_dir/output/$(basename "$license_file")"
  done < <(jq -er ".versions[\"$version\"][\"$platform\"].license.files[]" "$MANIFEST_PATH")

  cp "$ROOT_DIR/NOTICE.md" "$stage_dir/output/NOTICE.md"

  create_zip_from_dir "$stage_dir/output" "$out_dir/$platform.zip"

  built_count=$((built_count + 1))
  echo "built $out_dir/$platform.zip"
done < <(jq -er ".versions[\"$version\"] | keys[]" "$MANIFEST_PATH")

[[ "$built_count" -gt 0 ]] || die "no ready entries for version $version"

index_path="$out_dir/index.json"
tmp_index="$tmp_root/index.json"

jq -n --arg version "$version" '
  {
    version: $version,
    generatedAt: (now | todateiso8601),
    platforms: {}
  }
' >"$tmp_index"

while read -r zip_path; do
  platform="$(basename "$zip_path" .zip)"
  sha256="$(hash_file sha256 "$zip_path")"
  md5="$(hash_file md5 "$zip_path")"
  jq \
    --arg platform "$platform" \
    --arg file "$(basename "$zip_path")" \
    --arg sha256 "$sha256" \
    --arg md5 "$md5" \
    '.platforms[$platform] = { file: $file, sha256: $sha256, md5: $md5 }' \
    "$tmp_index" >"$tmp_index.next"
  mv "$tmp_index.next" "$tmp_index"
done < <(find "$out_dir" -maxdepth 1 -type f -name "*.zip" | sort)

mv "$tmp_index" "$index_path"
echo "wrote $index_path"
