#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

need_cmd jq

test -f "$MANIFEST_PATH" || die "manifest not found: $MANIFEST_PATH"

jq -e . "$MANIFEST_PATH" >/dev/null || die "manifest is not valid JSON"

count="$(json_get '.versions | length')"
[[ "$count" -gt 0 ]] || die "manifest must include at least one version"

ready_entries="$(json_get '[.versions[] | to_entries[] | select(.value.status == "ready")] | length')"

missing_required_count="$(json_get '
  [
    .versions
    | to_entries[]
    | .value
    | to_entries[]
    | select(.value.status == "ready")
    | select(
        (.value.platform | type != "string" or length == 0)
        or (.value.source.binaryUrl | type != "string" or length == 0)
        or (.value.source.upstreamUrl | type != "string" or length == 0)
        or (.value.source.version | type != "string" or length == 0)
        or (.value.archive.type | type != "string" or length == 0)
        or (.value.archive.hash.algorithm | type != "string" or length == 0)
        or (.value.archive.hash.value | type != "string" or length == 0)
        or (.value.requiredFiles | type != "array" or length == 0)
        or (.value.license.spdx | type != "array" or length == 0)
        or (.value.license.files | type != "array" or length == 0)
        or (.value.provenance | type != "string" or length == 0)
      )
  ] | length
')"
[[ "$missing_required_count" -eq 0 ]] || die "one or more ready entries are missing required fields"

mapfile -t license_paths < <(jq -r '
  .versions
  | to_entries[]
  | .value
  | to_entries[]
  | .value
  | select(.status == "ready")
  | .license.files[]
' "$MANIFEST_PATH")

for path in "${license_paths[@]}"; do
  [[ -n "$path" ]] || continue
  [[ -f "$ROOT_DIR/$path" ]] || die "missing referenced license file: $path"
done

echo "manifest validation passed (ready entries: $ready_entries)"
