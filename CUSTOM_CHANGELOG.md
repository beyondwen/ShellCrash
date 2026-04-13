# Custom Changelog

## Unreleased

- Added local `hysteria2://` and `hy2://` single-node import path for sing-box.
- Added Hysteria2-specific language strings for local generation and error reporting.
- Extracted Hysteria2 URI parsing and single-node config generation into `scripts/libs/hy2_uri.sh` to reduce future merge conflicts.
- Added a minimal split-routing template for single-node Hysteria2: private/CN direct, fallback traffic via proxy.
