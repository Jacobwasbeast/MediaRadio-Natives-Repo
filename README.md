# MediaRadio Natives Distribution

This repository builds release-ready native bundles for Lavaplayer-related binaries.

## Goal

Generate platform archives under `build/<version>/` from a pinned manifest with:

- official source URLs
- checksums
- license references
- provenance notes

No entry is packable until it is marked `ready`.

## Repository Layout

- `manifests/sources.json`: source-of-truth metadata and policy fields
- `licenses/`: referenced license files and notices
- `scripts/validate.sh`: manifest quality gate
- `scripts/verify.sh`: download and verify a single platform artifact
- `scripts/build.sh`: build all ready artifacts for a version
- `build/`: generated artifacts (not source-controlled unless you choose to)

## Quick Start

1. Fill `manifests/sources.json` for each platform entry.
2. Ensure `status` is `ready` only when source/license/checksum are complete.
3. Run:

```bash
./scripts/build.sh 2.2.6
```

4. Upload generated files from `build/2.2.6/` to GitHub Releases.

## Manifest Rules

Each `ready` platform entry must include:

- `platform`
- `source.binaryUrl`
- `source.upstreamUrl`
- `source.version`
- `archive.type`
- `archive.hash.algorithm`
- `archive.hash.value`
- `requiredFiles` (at least one archive-relative path, e.g. `natives/win-x86-64/connector.dll`)
- `license.spdx` (at least one SPDX id)
- `license.files` (at least one file path in this repo)
- `provenance`

`blocked` entries are allowed to have placeholders but will not build.
